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

    // Pre-read supplier products (for details) and the merchant's existing
    // inventory (to match by name) � done inside the transaction so the
    // stock updates stay atomic.
    const supplierProductRefs = receivedItems.map((i: ReceivedItemInput) => db.collection("supplier_products").doc(i.productId));
    const supplierProductSnaps = await Promise.all(supplierProductRefs.map((r) => tx.get(r)));

    const merchantProductsSnap = await tx.get(db.collection("products").where("merchantId", "==", uid));
    const merchantProductsByName = new Map<string, FirebaseFirestore.DocumentSnapshot>();
    merchantProductsSnap.docs.forEach((d) => {
      const name = (d.data().name ?? "").toString().trim().toLowerCase();
      if (name && !merchantProductsByName.has(name)) merchantProductsByName.set(name, d);
    });

    const updatedItems = [...items];
    let allFulfilled = true;
    let anyReceived = false;

    for (const received of receivedItems) {
      if (received.receivedQuantity <= 0) { allFulfilled = false; continue; }
      const supplierSnap = supplierProductSnaps[receivedItems.indexOf(received)];
      const supplierProduct = supplierSnap && supplierSnap.exists ? supplierSnap.data()! : null;
      const productName = supplierProduct?.name ?? items.find((i) => i.productId === received.productId)?.productName ?? 'Product';

      const matchKey = productName.trim().toLowerCase();
      const existingDoc = merchantProductsByName.get(matchKey);

      let productRef: FirebaseFirestore.DocumentReference;
      let current = 0;
      let storeId = restockRequest.storeId;
      let unit = supplierProduct?.unit || 'pc';
      let category = supplierProduct?.category || 'General';
      let costPrice = supplierProduct?.unitCost ?? 0;

      if (existingDoc) {
        productRef = existingDoc.ref;
        const existingData = existingDoc.data()!;
        current = existingData.currentStock ?? 0;
        storeId = existingData.storeId || storeId;
        unit = existingData.unit || unit;
        category = existingData.category || category;
        costPrice = existingData.costPrice ?? costPrice;
      } else {
        productRef = db.collection("products").doc();
      }

      const newCurrent = current + received.receivedQuantity;
      if (existingDoc) {
        tx.update(productRef, { currentStock: newCurrent, updatedAt: FieldValue.serverTimestamp() });
      } else {
        tx.set(productRef, {
          storeId,
          merchantId: uid,
          name: productName,
          description: supplierProduct?.description || '',
          category,
          brand: restockRequest.supplierName || '',
          imageUrls: supplierProduct?.imageUrls || [],
          supplierId: restockRequest.supplierId,
          costPrice,
          sellingPrice: costPrice,
          currentStock: newCurrent,
          reservedStock: 0,
          minStockLevel: 5,
          unit,
          batchNumber: null,
          expirationDate: null,
          barcode: null,
          status: 'active',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      const movementRef = db.collection("inventory_movements").doc();
      tx.set(movementRef, {
        productId: productRef.id,
        storeId,
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
    }

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
