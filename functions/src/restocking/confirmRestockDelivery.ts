import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface ReceivedItemInput {
  productId: string;
  receivedQuantity: number;
}

interface ConfirmDeliveryRequest {
  restockRequestId: string;
  receivedItems: ReceivedItemInput[];
}

/**
 * The only path that increases inventory from a restocking request (§3,
 * §9, §21 — "a supplier delivery cannot update inventory until the
 * merchant confirms receipt"). Writes a Stock In / Supplier Delivery
 * movement per product for the *actual* quantity received, which may be
 * less than requested (partial delivery).
 */
export const confirmRestockDelivery = onCall<ConfirmDeliveryRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { restockRequestId, receivedItems } = request.data ?? {};
  if (!restockRequestId) badRequest("Missing restockRequestId.");
  if (!Array.isArray(receivedItems) || receivedItems.length === 0) badRequest("No received items provided.");
  for (const item of receivedItems) {
    if (!item.productId || !Number.isInteger(item.receivedQuantity) || item.receivedQuantity < 0) {
      badRequest("Invalid received item.");
    }
  }

  await db.runTransaction(async (tx) => {
    const requestRef = db.collection("restock_requests").doc(restockRequestId);
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) badRequest("Restocking request not found.");
    const restockRequest = requestSnap.data()!;

    if (restockRequest.merchantId !== uid) badRequest("You are not authorized to confirm this delivery.");
    if (!["dispatched", "partiallyReceived"].includes(restockRequest.status)) {
      failedPrecondition(`Cannot confirm delivery for a request that is ${restockRequest.status}.`);
    }

    const items = (restockRequest.items ?? []) as { productId: string; productName: string; requestedQuantity: number; receivedQuantity: number | null; estimatedUnitCost: number }[];
    const productRefs = receivedItems.map((i: ReceivedItemInput) => db.collection("products").doc(i.productId));
    const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));

    const updatedItems = [...items];
    let allFulfilled = true;
    let anyReceived = false;

    receivedItems.forEach((received: ReceivedItemInput, idx: number) => {
      const snap = productSnaps[idx];
      if (!snap.exists || received.receivedQuantity <= 0) {
        if (received.receivedQuantity <= 0) allFulfilled = false;
        return;
      }
      const product = snap.data()!;
      const current = product.currentStock ?? 0;
      const newCurrent = current + received.receivedQuantity;
      tx.update(productRefs[idx], { currentStock: newCurrent, updatedAt: FieldValue.serverTimestamp() });

      const movementRef = db.collection("inventory_movements").doc();
      tx.set(movementRef, {
        productId: received.productId,
        storeId: product.storeId,
        type: "supplierDelivery",
        quantityBefore: current,
        quantityChanged: received.receivedQuantity,
        quantityAfter: newCurrent,
        reason: `Supplier delivery confirmed (${restockRequest.supplierName})`,
        relatedOrderId: null,
        relatedReservationId: null,
        relatedDeliveryId: restockRequestId,
        performedByUserId: uid,
        performedByName: restockRequest.storeName ?? "",
        createdAt: FieldValue.serverTimestamp(),
      });

      anyReceived = true;
      const itemIdx = updatedItems.findIndex((i) => i.productId === received.productId);
      if (itemIdx >= 0) {
        const requested = updatedItems[itemIdx].requestedQuantity;
        updatedItems[itemIdx] = { ...updatedItems[itemIdx], receivedQuantity: received.receivedQuantity };
        if (received.receivedQuantity < requested) allFulfilled = false;
      }
    });

    if (!anyReceived) badRequest("At least one item must have a received quantity greater than zero.");

    const newStatus = allFulfilled ? "received" : "partiallyReceived";
    tx.update(requestRef, { items: updatedItems, status: newStatus, updatedAt: FieldValue.serverTimestamp() });
  });

  const requestSnap = await db.collection("restock_requests").doc(restockRequestId).get();
  const restockRequest = requestSnap.data();

  // Update the matching supplier_deliveries doc outside the transaction
  // (simple query + write; not required to be atomic with the stock update).
  const deliveryQuery = await db.collection("supplier_deliveries").where("restockRequestId", "==", restockRequestId).limit(1).get();
  if (!deliveryQuery.empty) {
    await deliveryQuery.docs[0].ref.update({
      status: restockRequest?.status ?? "received",
      deliveredAt: FieldValue.serverTimestamp(),
      confirmedAt: FieldValue.serverTimestamp(),
      confirmedByUserId: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  if (restockRequest) {
    await notifyUser({
      userId: restockRequest.supplierId,
      type: "supplierResponse",
      title: "Delivery confirmed",
      message: `${restockRequest.storeName} confirmed receipt of your delivery.`,
      relatedRecordId: restockRequestId,
      relatedRecordType: "restock_request",
    });
  }

  return { status: "confirmed" };
});
