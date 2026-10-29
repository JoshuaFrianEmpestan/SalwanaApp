import { onCall } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface CreateReservationRequest {
  productId: string;
  quantity: number;
  fulfillmentType: "pickup" | "delivery";
  scheduledForIso: string;
  deliveryAddressText?: string;
  notes?: string;
}

/**
 * Product reservation flow (§4). Mirrors processCheckout's server-side
 * validation: stock and price are re-read live, never trusted from the
 * client. On success the requested quantity moves from available into
 * reserved stock (a Reservation movement) and the merchant is notified to
 * approve or reject it.
 */
export const createReservation = onCall<CreateReservationRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { productId, quantity, fulfillmentType, scheduledForIso, deliveryAddressText, notes } = request.data ?? {};

  if (!productId) badRequest("Missing productId.");
  if (!Number.isInteger(quantity) || quantity <= 0) badRequest("Quantity must be a positive whole number.");
  if (fulfillmentType !== "pickup" && fulfillmentType !== "delivery") badRequest("Invalid fulfillment type.");
  if (fulfillmentType === "delivery" && !deliveryAddressText) badRequest("Delivery address is required.");
  const scheduledFor = new Date(scheduledForIso);
  if (isNaN(scheduledFor.getTime()) || scheduledFor.getTime() < Date.now()) {
    badRequest("Reservation date/time must be in the future.");
  }

  const consumerSnap = await db.collection("users").doc(uid).get();
  if (!consumerSnap.exists) badRequest("Consumer profile not found.");
  const consumer = consumerSnap.data()!;
  if (consumer.role !== "consumer") badRequest("Only consumer accounts can make reservations.");
  if (consumer.status !== "active") badRequest("Your account is not active.");

  const reservationId = await db.runTransaction(async (tx) => {
    const productRef = db.collection("products").doc(productId);
    const productSnap = await tx.get(productRef);
    if (!productSnap.exists) badRequest("Product not found.");
    const product = productSnap.data()!;
    if (product.status !== "active") badRequest(`${product.name} is not available for reservation.`);

    const storeId = product.storeId ?? product.merchantId;
    if (!storeId) badRequest("Store not found.");
    const storeRef = db.collection("stores").doc(storeId);
    const storeSnap = await tx.get(storeRef);
    if (!storeSnap.exists) badRequest("Store not found.");
    const store = storeSnap.data()!;
    if (store.verificationStatus !== "active") badRequest(`${store.name} is not currently available.`);
    if (!store.isOpen) badRequest(`${store.name} is currently closed.`);

    const current = product.currentStock ?? 0;
    const reserved = product.reservedStock ?? 0;
    const available = current - reserved;
    if (quantity > available) {
      badRequest(`Only ${available} ${product.unit ?? "pc"} of ${product.name} available to reserve.`);
    }

    const expirationMinutes = store.reservationExpirationMinutes ?? 120;
    const expiresAt = Timestamp.fromMillis(Date.now() + expirationMinutes * 60 * 1000);

    const reservationRef = db.collection("reservations").doc();
    tx.update(productRef, { reservedStock: reserved + quantity, updatedAt: FieldValue.serverTimestamp() });

    const movementRef = db.collection("inventory_movements").doc();
    tx.set(movementRef, {
      productId,
      storeId: storeId,
      type: "reservation",
      quantityBefore: reserved,
      quantityChanged: quantity,
      quantityAfter: reserved + quantity,
      reason: "Product reserved by consumer",
      relatedOrderId: null,
      relatedReservationId: reservationRef.id,
      relatedDeliveryId: null,
      performedByUserId: uid,
      performedByName: consumer.fullName ?? "Consumer",
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(reservationRef, {
      consumerId: uid,
      consumerName: consumer.fullName ?? "",
      storeId: storeId,
      storeName: store.name,
      merchantId: store.merchantId ?? product.merchantId ?? storeId,
      productId,
      productName: product.name,
      productImageUrl: (product.imageUrls ?? [])[0] ?? product.imageUrl ?? null,
      quantity,
      unitPrice: product.sellingPrice ?? product.price ?? 0,
      fulfillmentType,
      scheduledFor: Timestamp.fromDate(scheduledFor),
      status: "pending",
      rejectionReason: null,
      expiresAt,
      reminderSent: false,
      deliveryAddressText: deliveryAddressText ?? null,
      notes: notes ?? null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return reservationRef.id;
  });

  const productSnap2 = await db.collection("products").doc(productId).get();
  const product2 = productSnap2.data();
  if (product2) {
    const merchantId2 = product2.merchantId ?? product2.storeId;
    await notifyUser({
      userId: merchantId2,
      type: "reservationRequest",
      title: "New reservation request",
      message: `${consumer.fullName ?? "A consumer"} wants to reserve ${quantity} ${product2.unit ?? "pc"} of ${product2.name}.`,
      relatedRecordId: reservationId,
      relatedRecordType: "reservation",
    });
  }

  return { reservationId };
});
