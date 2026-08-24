import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

type Action = "preparing" | "readyForPickup" | "outForDelivery" | "completed" | "cancel" | "refund";

interface UpdateOrderStatusRequest {
  orderId: string;
  action: Action;
  reason?: string;
}

const NEXT_STATUS: Record<Action, string> = {
  preparing: "preparing",
  readyForPickup: "readyForPickup",
  outForDelivery: "outForDelivery",
  completed: "completed",
  cancel: "cancelled",
  refund: "refunded",
};

/** Merchant drives fulfillment forward; either party can cancel early;
 * refund is merchant-only and only after completion (§8, §21). */
const MERCHANT_ACTIONS = new Set<Action>(["preparing", "readyForPickup", "outForDelivery", "completed", "cancel", "refund"]);
const CONSUMER_ACTIONS = new Set<Action>(["cancel"]);

const ALLOWED_FROM: Record<Action, string[]> = {
  preparing: ["confirmed"],
  readyForPickup: ["preparing"],
  outForDelivery: ["preparing"],
  completed: ["readyForPickup", "outForDelivery"],
  cancel: ["pendingPayment", "confirmed", "preparing"],
  refund: ["completed"],
};

/** Orders whose stock was already deducted as a Sale (vs. still just
 * held/reserved) — cancelling these must add the stock back rather than
 * simply releasing a reservation (§3, §21). */
const STOCK_ALREADY_SOLD_STATUSES = new Set(["confirmed", "preparing"]);

export const updateOrderStatus = onCall<UpdateOrderStatusRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { orderId, action, reason } = request.data ?? {};
  if (!orderId || !action) badRequest("Missing orderId or action.");
  if (!(action in NEXT_STATUS)) badRequest("Invalid action.");

  await db.runTransaction(async (tx) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) badRequest("Order not found.");
    const order = orderSnap.data()!;

    const isMerchant = MERCHANT_ACTIONS.has(action) && order.merchantId === uid;
    const isConsumer = CONSUMER_ACTIONS.has(action) && order.consumerId === uid;
    if (!isMerchant && !isConsumer) badRequest("You are not authorized to perform this action.");

    if (action === "readyForPickup" && order.fulfillmentType !== "pickup") badRequest("This order is for delivery, not pickup.");
    if (action === "outForDelivery" && order.fulfillmentType !== "delivery") badRequest("This order is for pickup, not delivery.");

    if (!ALLOWED_FROM[action].includes(order.status)) {
      failedPrecondition(`Cannot ${action} an order that is ${order.status}.`);
    }

    if (action === "cancel" && STOCK_ALREADY_SOLD_STATUSES.has(order.status)) {
      const items = (order.items ?? []) as { productId: string; quantity: number }[];
      for (const item of items) {
        const productRef = db.collection("products").doc(item.productId);
        const productSnap = await tx.get(productRef);
        if (!productSnap.exists) continue;
        const product = productSnap.data()!;
        const current = product.currentStock ?? 0;
        const newCurrent = current + item.quantity;
        tx.update(productRef, { currentStock: newCurrent, updatedAt: FieldValue.serverTimestamp() });

        const movementRef = db.collection("inventory_movements").doc();
        tx.set(movementRef, {
          productId: item.productId,
          storeId: order.storeId,
          type: "returned",
          quantityBefore: current,
          quantityChanged: item.quantity,
          quantityAfter: newCurrent,
          reason: "Order cancelled — stock returned",
          relatedOrderId: orderId,
          relatedReservationId: null,
          relatedDeliveryId: null,
          performedByUserId: uid,
          performedByName: order.consumerName ?? "",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    } else if (action === "cancel" && order.status === "pendingPayment") {
      const items = (order.items ?? []) as { productId: string; quantity: number }[];
      for (const item of items) {
        const productRef = db.collection("products").doc(item.productId);
        const productSnap = await tx.get(productRef);
        if (!productSnap.exists) continue;
        const product = productSnap.data()!;
        const reserved = product.reservedStock ?? 0;
        const newReserved = Math.max(0, reserved - item.quantity);
        tx.update(productRef, { reservedStock: newReserved, updatedAt: FieldValue.serverTimestamp() });

        const movementRef = db.collection("inventory_movements").doc();
        tx.set(movementRef, {
          productId: item.productId,
          storeId: order.storeId,
          type: "reservationReleased",
          quantityBefore: reserved,
          quantityChanged: -item.quantity,
          quantityAfter: newReserved,
          reason: "Order cancelled — held stock released",
          relatedOrderId: orderId,
          relatedReservationId: null,
          relatedDeliveryId: null,
          performedByUserId: uid,
          performedByName: order.consumerName ?? "",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }

    const newStatus = NEXT_STATUS[action];
    tx.update(orderRef, {
      status: newStatus,
      cancellationReason: action === "cancel" ? (reason ?? null) : order.cancellationReason ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (action === "refund") {
      const paymentRef = db.collection("payments").doc(orderId);
      tx.update(paymentRef, { status: "refunded", updatedAt: FieldValue.serverTimestamp() });
    }
  });

  const orderSnap = await db.collection("orders").doc(orderId).get();
  const order = orderSnap.data();
  if (order) {
    // Notify whichever side didn't perform the action — works for every
    // action since only the order's own merchant/consumer can act on it.
    const notifyTargetId = uid === order.merchantId ? order.consumerId : order.merchantId;
    await notifyUser({
      userId: notifyTargetId,
      type: "orderStatusUpdate",
      title: "Order update",
      message: `Your order from ${order.storeName} is now ${NEXT_STATUS[action as Action]}.`,
      relatedRecordId: orderId,
      relatedRecordType: "order",
    });
  }

  return { status: NEXT_STATUS[action as Action] };
});
