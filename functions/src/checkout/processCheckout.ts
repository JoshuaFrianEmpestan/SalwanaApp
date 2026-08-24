import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";
import { writeReceipt, writeTransaction } from "../lib/receipts";
import { getAppSettings } from "../lib/settings";

interface CheckoutItemInput {
  productId: string;
  quantity: number;
}

interface CheckoutGroupInput {
  storeId: string;
  fulfillmentType: "pickup" | "delivery";
  deliveryAddressId?: string;
  deliveryAddressText?: string;
  notes?: string;
  paymentMethod: "gcash" | "maya" | "cashOnDelivery" | "simulated";
  items: CheckoutItemInput[];
}

interface CheckoutRequest {
  idempotencyKey: string;
  groups: CheckoutGroupInput[];
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * Server-authoritative checkout (§5, §6, §20, §21). The client sends only
 * product ids and quantities — every price, the stock check, and the
 * total are recomputed here from live Firestore data so a tampered client
 * can never manipulate what it pays or reserve stock that doesn't exist.
 *
 * One order is created per merchant group (§5 "grouped during checkout").
 * Cash-on-delivery orders deduct stock immediately (`confirmed`, a Sale
 * movement); online-payment orders only *hold* stock (`pendingPayment`, a
 * Reservation movement) — module 7 (Payments) is what converts that hold
 * into a sale once payment actually succeeds, or releases it on failure.
 *
 * Idempotent via `idempotencyKey`: a retried call with the same key (e.g.
 * a double-tap or client retry after a flaky network response) returns the
 * original result instead of creating duplicate orders (§6, §20).
 */
export const processCheckout = onCall<CheckoutRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { idempotencyKey, groups } = request.data ?? {};

  if (!idempotencyKey || typeof idempotencyKey !== "string") badRequest("Missing idempotencyKey.");
  if (!Array.isArray(groups) || groups.length === 0) badRequest("Cart is empty.");
  for (const g of groups) {
    if (!g.storeId || !Array.isArray(g.items) || g.items.length === 0) badRequest("Invalid checkout group.");
    if (g.fulfillmentType === "delivery" && !g.deliveryAddressText) badRequest("Delivery address is required.");
  }

  const attemptRef = db.collection("checkout_attempts").doc(idempotencyKey);
  const existing = await attemptRef.get();
  if (existing.exists) {
    return existing.data() as { checkoutGroupId: string; orderIds: string[] };
  }

  const consumerSnap = await db.collection("users").doc(uid).get();
  if (!consumerSnap.exists) badRequest("Consumer profile not found.");
  const consumer = consumerSnap.data()!;
  if (consumer.role !== "consumer") badRequest("Only consumer accounts can check out.");
  if (consumer.status !== "active") badRequest("Your account is not active.");

  const settings = await getAppSettings();
  const checkoutGroupId = idempotencyKey;
  const orderIds: string[] = [];

  for (const group of groups) {
    const orderId = await db.runTransaction(async (tx) => {
      const storeRef = db.collection("stores").doc(group.storeId);
      const storeSnap = await tx.get(storeRef);
      if (!storeSnap.exists) badRequest(`Store ${group.storeId} not found.`);
      const store = storeSnap.data()!;
      if (store.verificationStatus !== "active") badRequest(`${store.name} is not currently available.`);
      if (!store.isOpen) badRequest(`${store.name} is currently closed.`);

      const productRefs = group.items.map((i) => db.collection("products").doc(i.productId));
      const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));

      let subtotal = 0;
      const orderItems: Record<string, unknown>[] = [];
      const stockUpdates: { ref: FirebaseFirestore.DocumentReference; before: number; after: number; reservedBefore: number; reservedAfter: number }[] = [];

      productSnaps.forEach((snap, idx) => {
        const requested = group.items[idx].quantity;
        if (!Number.isInteger(requested) || requested <= 0) badRequest("Invalid quantity.");
        if (!snap.exists) badRequest("A product in your cart is no longer available.");
        const product = snap.data()!;
        if (product.storeId !== group.storeId) badRequest("Product does not belong to this store.");
        if (product.status !== "active") badRequest(`${product.name} is no longer available.`);

        const current = product.currentStock ?? 0;
        const reserved = product.reservedStock ?? 0;
        const available = current - reserved;
        if (requested > available) {
          badRequest(`Only ${available} ${product.unit ?? "pc"} of ${product.name} left in stock.`);
        }

        const unitPrice = product.sellingPrice ?? 0;
        subtotal += unitPrice * requested;
        orderItems.push({
          productId: snap.id,
          productName: product.name,
          productImageUrl: (product.imageUrls ?? [])[0] ?? null,
          unitPrice,
          quantity: requested,
          unit: product.unit ?? "pc",
          subtotal: round2(unitPrice * requested),
        });

        const isCod = group.paymentMethod === "cashOnDelivery";
        stockUpdates.push({
          ref: productRefs[idx],
          before: current,
          after: isCod ? current - requested : current,
          reservedBefore: reserved,
          reservedAfter: isCod ? reserved : reserved + requested,
        });
      });

      const deliveryFee = group.fulfillmentType === "delivery" ? settings.defaultDeliveryFee : 0;
      const platformFee = round2(subtotal * (settings.platformFeePercent / 100));
      const total = round2(subtotal + deliveryFee + platformFee);

      const orderRef = db.collection("orders").doc();
      const isCod = group.paymentMethod === "cashOnDelivery";

      stockUpdates.forEach((u, idx) => {
        tx.update(u.ref, {
          currentStock: u.after,
          reservedStock: u.reservedAfter,
          updatedAt: FieldValue.serverTimestamp(),
        });
        const movementRef = db.collection("inventory_movements").doc();
        tx.set(movementRef, {
          productId: productRefs[idx].id,
          storeId: group.storeId,
          type: isCod ? "sale" : "reservation",
          quantityBefore: isCod ? u.before : u.reservedBefore,
          quantityChanged: isCod ? -group.items[idx].quantity : group.items[idx].quantity,
          quantityAfter: isCod ? u.after : u.reservedAfter,
          reason: isCod ? "Cash on delivery order confirmed" : "Stock held for pending-payment order",
          relatedOrderId: orderRef.id,
          relatedReservationId: null,
          relatedDeliveryId: null,
          performedByUserId: uid,
          performedByName: consumer.fullName ?? "Consumer",
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      const orderData = {
        checkoutGroupId,
        consumerId: uid,
        consumerName: consumer.fullName ?? "",
        storeId: group.storeId,
        storeName: store.name,
        merchantId: store.merchantId,
        items: orderItems,
        subtotal: round2(subtotal),
        deliveryFee,
        discount: 0,
        platformFee,
        total,
        paymentMethod: group.paymentMethod,
        status: isCod ? "confirmed" : "pendingPayment",
        fulfillmentType: group.fulfillmentType,
        deliveryAddressId: group.deliveryAddressId ?? null,
        deliveryAddressText: group.deliveryAddressText ?? null,
        notes: group.notes ?? null,
        cancellationReason: null,
        reviewed: false,
      };
      tx.set(orderRef, { ...orderData, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });

      // One payment record per order (§6, §15) — COD is considered settled
      // the moment the order is placed; online methods stay `pending` until
      // processPayment (module 7) runs.
      const paymentRef = db.collection("payments").doc(orderRef.id);
      tx.set(paymentRef, {
        orderId: orderRef.id,
        checkoutGroupId,
        consumerId: uid,
        merchantId: store.merchantId,
        method: group.paymentMethod,
        status: isCod ? "successful" : "pending",
        amount: total,
        idempotencyKey: `${idempotencyKey}:${orderRef.id}`,
        providerReference: isCod ? null : null,
        failureReason: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (isCod) {
        writeReceipt(tx, { orderId: orderRef.id, order: orderData, store, orderStatus: "confirmed", paymentStatus: "successful" });
        writeTransaction(tx, { orderId: orderRef.id, order: orderData });
      }

      return orderRef.id;
    });

    orderIds.push(orderId);
  }

  // Best-effort cart cleanup — not critical enough to block the response.
  try {
    const cartItemsRef = db.collection("carts").doc(uid).collection("items");
    const batch = db.batch();
    for (const group of groups) {
      for (const item of group.items) {
        batch.delete(cartItemsRef.doc(item.productId));
      }
    }
    await batch.commit();
  } catch (err) {
    console.warn("Cart cleanup failed after checkout:", err);
  }

  const result = { checkoutGroupId, orderIds };
  await attemptRef.set({ ...result, uid, createdAt: FieldValue.serverTimestamp() });

  await Promise.all(
    orderIds.map(async (orderId) => {
      const orderSnap = await db.collection("orders").doc(orderId).get();
      const order = orderSnap.data();
      if (!order) return;
      await notifyUser({
        userId: order.merchantId,
        type: "newOrder",
        title: "New order received",
        message: `${order.consumerName} placed an order for ${order.total ? `₱${order.total}` : "your store"}.`,
        relatedRecordId: orderId,
        relatedRecordType: "order",
      });
    }),
  );

  return result;
});
