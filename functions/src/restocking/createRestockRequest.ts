import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface RequestItemInput {
  productId: string;
  requestedQuantity: number;
  estimatedUnitCost: number;
}

interface CreateRestockRequestRequest {
  supplierId: string;
  items: RequestItemInput[];
  notes?: string;
}

/** Merchant creates a restocking request against their own products,
 * addressed to a chosen supplier (§9). Product names/store are re-read
 * live so the request always reflects real product data. */
export const createRestockRequest = onCall<CreateRestockRequestRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { supplierId, items, notes } = request.data ?? {};
  if (!supplierId) badRequest("Missing supplierId.");
  if (!Array.isArray(items) || items.length === 0) badRequest("Add at least one product to request.");
  for (const item of items) {
    if (!item.productId || !Number.isInteger(item.requestedQuantity) || item.requestedQuantity <= 0) {
      badRequest("Invalid request item.");
    }
  }

  const merchantSnap = await db.collection("users").doc(uid).get();
  if (!merchantSnap.exists || merchantSnap.data()?.role !== "merchant") badRequest("Only merchants can create restocking requests.");

  const storeSnap = await db.collection("stores").doc(uid).get();
  if (!storeSnap.exists) badRequest("Store not found.");
  const store = storeSnap.data()!;

  const supplierSnap = await db.collection("suppliers").doc(supplierId).get();
  if (!supplierSnap.exists) badRequest("Supplier not found.");
  const supplier = supplierSnap.data()!;
  if (supplier.verificationStatus !== "active") badRequest(`${supplier.companyName} is not currently available.`);

  const productRefs = items.map((i: RequestItemInput) => db.collection("products").doc(i.productId));
  const productSnaps = await Promise.all(productRefs.map((r) => r.get()));

  const requestItems = productSnaps.map((snap, idx) => {
    if (!snap.exists) badRequest("A selected product no longer exists.");
    const product = snap.data()!;
    if (product.merchantId !== uid) badRequest("You can only request restocking for your own products.");
    return {
      productId: snap.id,
      productName: product.name,
      requestedQuantity: items[idx].requestedQuantity,
      receivedQuantity: null,
      estimatedUnitCost: items[idx].estimatedUnitCost ?? 0,
    };
  });

  const requestRef = db.collection("restock_requests").doc();
  await requestRef.set({
    merchantId: uid,
    storeId: uid,
    storeName: store.name,
    supplierId,
    supplierName: supplier.companyName,
    items: requestItems,
    status: "requested",
    rejectionReason: null,
    estimatedDeliveryDate: null,
    notes: notes ?? null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await notifyUser({
    userId: supplierId,
    type: "restockRequest",
    title: "New restocking request",
    message: `${store.name} sent a restocking request with ${requestItems.length} product(s).`,
    relatedRecordId: requestRef.id,
    relatedRecordType: "restock_request",
  });

  return { restockRequestId: requestRef.id };
});
