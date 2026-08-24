import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

type Action = "approve" | "reject" | "preparing" | "readyForPickup" | "outForDelivery" | "completed" | "cancel";

interface UpdateReservationStatusRequest {
  reservationId: string;
  action: Action;
  reason?: string;
}

/** Which statuses release the held stock back to available (§4 step 11). */
const RELEASING_ACTIONS = new Set<Action>(["reject", "cancel"]);

/** Merchant-only actions vs consumer-only actions (§4, §21 ownership rules). */
const MERCHANT_ACTIONS = new Set<Action>(["approve", "reject", "preparing", "readyForPickup", "outForDelivery", "completed"]);
const CONSUMER_ACTIONS = new Set<Action>(["cancel"]);

const NEXT_STATUS: Record<Action, string> = {
  approve: "approved",
  reject: "rejected",
  preparing: "preparing",
  readyForPickup: "readyForPickup",
  outForDelivery: "outForDelivery",
  completed: "completed",
  cancel: "cancelled",
};

/** Valid current statuses for each action — enforced server-side so a
 * reservation can never skip states or be actioned twice (§4, §21). */
const ALLOWED_FROM: Record<Action, string[]> = {
  approve: ["pending"],
  reject: ["pending"],
  preparing: ["approved"],
  readyForPickup: ["preparing"],
  outForDelivery: ["preparing"],
  completed: ["readyForPickup", "outForDelivery"],
  cancel: ["pending", "approved", "preparing"],
};

export const updateReservationStatus = onCall<UpdateReservationStatusRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { reservationId, action, reason } = request.data ?? {};
  if (!reservationId || !action) badRequest("Missing reservationId or action.");
  if (!(action in NEXT_STATUS)) badRequest("Invalid action.");

  await db.runTransaction(async (tx) => {
    const reservationRef = db.collection("reservations").doc(reservationId);
    const reservationSnap = await tx.get(reservationRef);
    if (!reservationSnap.exists) badRequest("Reservation not found.");
    const reservation = reservationSnap.data()!;

    const isMerchant = MERCHANT_ACTIONS.has(action) && reservation.merchantId === uid;
    const isConsumer = CONSUMER_ACTIONS.has(action) && reservation.consumerId === uid;
    if (!isMerchant && !isConsumer) badRequest("You are not authorized to perform this action.");

    if (!ALLOWED_FROM[action].includes(reservation.status)) {
      failedPrecondition(`Cannot ${action} a reservation that is ${reservation.status}.`);
    }

    const newStatus = NEXT_STATUS[action];
    const productRef = db.collection("products").doc(reservation.productId);
    const productSnap = await tx.get(productRef);

    if ((RELEASING_ACTIONS.has(action) || action === "completed") && productSnap.exists) {
      const product = productSnap.data()!;
      const reserved = product.reservedStock ?? 0;
      const current = product.currentStock ?? 0;

      if (RELEASING_ACTIONS.has(action)) {
        const newReserved = Math.max(0, reserved - reservation.quantity);
        tx.update(productRef, { reservedStock: newReserved, updatedAt: FieldValue.serverTimestamp() });
        const movementRef = db.collection("inventory_movements").doc();
        tx.set(movementRef, {
          productId: reservation.productId,
          storeId: reservation.storeId,
          type: "reservationReleased",
          quantityBefore: reserved,
          quantityChanged: -reservation.quantity,
          quantityAfter: newReserved,
          reason: action === "reject" ? `Reservation rejected: ${reason ?? "no reason given"}` : "Reservation cancelled",
          relatedOrderId: null,
          relatedReservationId: reservationId,
          relatedDeliveryId: null,
          performedByUserId: uid,
          performedByName: reservation.consumerName ?? reservation.storeName ?? "",
          createdAt: FieldValue.serverTimestamp(),
        });
      } else if (action === "completed") {
        const newReserved = Math.max(0, reserved - reservation.quantity);
        const newCurrent = Math.max(0, current - reservation.quantity);
        tx.update(productRef, {
          reservedStock: newReserved,
          currentStock: newCurrent,
          updatedAt: FieldValue.serverTimestamp(),
        });
        const movementRef = db.collection("inventory_movements").doc();
        tx.set(movementRef, {
          productId: reservation.productId,
          storeId: reservation.storeId,
          type: "sale",
          quantityBefore: current,
          quantityChanged: -reservation.quantity,
          quantityAfter: newCurrent,
          reason: "Reservation completed — claimed/delivered",
          relatedOrderId: null,
          relatedReservationId: reservationId,
          relatedDeliveryId: null,
          performedByUserId: uid,
          performedByName: reservation.consumerName ?? "",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }

    tx.update(reservationRef, {
      status: newStatus,
      rejectionReason: action === "reject" ? (reason ?? null) : reservation.rejectionReason ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const reservationSnap = await db.collection("reservations").doc(reservationId).get();
  const reservation = reservationSnap.data();
  if (reservation) {
    const notifyConsumerTypes: Partial<Record<Action, string>> = {
      approve: "reservationApproved",
      reject: "reservationRejected",
    };
    const notifType = notifyConsumerTypes[action];
    if (notifType) {
      await notifyUser({
        userId: reservation.consumerId,
        type: notifType as "reservationApproved" | "reservationRejected",
        title: action === "approve" ? "Reservation approved" : "Reservation rejected",
        message:
          action === "approve"
            ? `Your reservation for ${reservation.productName} at ${reservation.storeName} was approved.`
            : `Your reservation for ${reservation.productName} was rejected${reason ? `: ${reason}` : "."}`,
        relatedRecordId: reservationId,
        relatedRecordType: "reservation",
      });
    }
  }

  return { status: NEXT_STATUS[action as Action] };
});
