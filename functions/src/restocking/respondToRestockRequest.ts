import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

type Action = "accept" | "reject" | "processing" | "dispatch" | "cancel";

interface RespondRequest {
  restockRequestId: string;
  action: Action;
  reason?: string;
  estimatedDeliveryIso?: string;
}

const NEXT_STATUS: Record<Action, string> = {
  accept: "accepted",
  reject: "rejected",
  processing: "processing",
  dispatch: "dispatched",
  cancel: "cancelled",
};

const SUPPLIER_ACTIONS = new Set<Action>(["accept", "reject", "processing", "dispatch"]);
const MERCHANT_ACTIONS = new Set<Action>(["cancel"]);

const ALLOWED_FROM: Record<Action, string[]> = {
  accept: ["requested"],
  reject: ["requested"],
  processing: ["accepted"],
  dispatch: ["processing"],
  cancel: ["requested", "accepted"],
};

/**
 * Supplier-side restock request actions (§9). Deliberately does NOT touch
 * inventory — a supplier can never increase a merchant's stock directly
 * (§21 core business rule); dispatch only creates a `supplier_deliveries`
 * tracking doc that the merchant later confirms via confirmRestockDelivery.
 */
export const respondToRestockRequest = onCall<RespondRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { restockRequestId, action, reason, estimatedDeliveryIso } = request.data ?? {};
  if (!restockRequestId || !action) badRequest("Missing restockRequestId or action.");
  if (!(action in NEXT_STATUS)) badRequest("Invalid action.");

  let deliveryId: string | null = null;

  await db.runTransaction(async (tx) => {
    const requestRef = db.collection("restock_requests").doc(restockRequestId);
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) badRequest("Restocking request not found.");
    const restockRequest = requestSnap.data()!;

    const isSupplier = SUPPLIER_ACTIONS.has(action) && restockRequest.supplierId === uid;
    const isMerchant = MERCHANT_ACTIONS.has(action) && restockRequest.merchantId === uid;
    if (!isSupplier && !isMerchant) badRequest("You are not authorized to perform this action.");

    if (!ALLOWED_FROM[action].includes(restockRequest.status)) {
      failedPrecondition(`Cannot ${action} a request that is ${restockRequest.status}.`);
    }

    tx.update(requestRef, {
      status: NEXT_STATUS[action],
      rejectionReason: action === "reject" ? (reason ?? null) : restockRequest.rejectionReason ?? null,
      estimatedDeliveryDate: estimatedDeliveryIso ? new Date(estimatedDeliveryIso) : restockRequest.estimatedDeliveryDate ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (action === "dispatch") {
      const deliveryRef = db.collection("supplier_deliveries").doc();
      deliveryId = deliveryRef.id;
      tx.set(deliveryRef, {
        restockRequestId,
        merchantId: restockRequest.merchantId,
        storeId: restockRequest.storeId,
        supplierId: restockRequest.supplierId,
        status: "dispatched",
        dispatchedAt: FieldValue.serverTimestamp(),
        deliveredAt: null,
        confirmedAt: null,
        confirmedByUserId: null,
        trackingNotes: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  const requestSnap = await db.collection("restock_requests").doc(restockRequestId).get();
  const restockRequest = requestSnap.data();
  if (restockRequest) {
    const notifyTargetId = uid === restockRequest.supplierId ? restockRequest.merchantId : restockRequest.supplierId;
    const type = action === "reject" ? "supplierResponse" : action === "dispatch" ? "supplierResponse" : "restockRequest";
    await notifyUser({
      userId: notifyTargetId,
      type,
      title: "Restocking request update",
      message: `Your restocking request to ${uid === restockRequest.supplierId ? restockRequest.supplierName : restockRequest.storeName} is now ${NEXT_STATUS[action as Action]}.`,
      relatedRecordId: restockRequestId,
      relatedRecordType: "restock_request",
    });
  }

  return { status: NEXT_STATUS[action as Action], deliveryId };
});
