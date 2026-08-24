import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";
import { writeReceipt, writeTransaction } from "../lib/receipts";

interface ProcessPaymentRequest {
  orderId: string;
  /** This app never integrates a real payment gateway (§6) — the client
   * explicitly picks the sandbox outcome, mirroring how a real gateway's
   * test mode works, so both the success and failure paths are testable. */
  simulateOutcome: "success" | "fail";
}

const RETRYABLE_STATUSES = new Set(["pendingPayment", "paymentFailed"]);

function randomRef(): string {
  return `SIM-${Math.random().toString(36).slice(2, 10).toUpperCase()}`;
}

/**
 * Processes (simulates) payment for a non-COD order created by
 * processCheckout (§6, §7). Converts held/reserved stock into an actual
 * sale on success, or releases it on failure — retryable, so a failed
 * payment can be attempted again without re-running checkout.
 */
export const processPayment = onCall<ProcessPaymentRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { orderId, simulateOutcome } = request.data ?? {};
  if (!orderId) badRequest("Missing orderId.");
  if (simulateOutcome !== "success" && simulateOutcome !== "fail") badRequest("Invalid simulateOutcome.");

  await db.runTransaction(async (tx) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) badRequest("Order not found.");
    const order = orderSnap.data()!;

    if (order.consumerId !== uid) badRequest("You are not authorized to pay for this order.");
    if (order.paymentMethod === "cashOnDelivery") badRequest("Cash on delivery orders do not require online payment.");
    if (!RETRYABLE_STATUSES.has(order.status)) badRequest(`This order is already ${order.status}.`);

    const wasHeld = order.status === "pendingPayment";
    const items = (order.items ?? []) as { productId: string; quantity: number }[];
    const productRefs = items.map((i) => db.collection("products").doc(i.productId));
    const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));

    const storeRef = db.collection("stores").doc(order.storeId);
    const storeSnap = await tx.get(storeRef);
    const store = storeSnap.exists ? storeSnap.data()! : { name: order.storeName, phone: "", email: "" };

    const paymentRef = db.collection("payments").doc(orderId);

    if (simulateOutcome === "success") {
      productSnaps.forEach((snap, idx) => {
        const qty = items[idx].quantity;
        if (!snap.exists) return;
        const product = snap.data()!;
        const current = product.currentStock ?? 0;
        const reserved = product.reservedStock ?? 0;

        if (wasHeld) {
          const newReserved = Math.max(0, reserved - qty);
          const newCurrent = Math.max(0, current - qty);
          tx.update(productRefs[idx], { currentStock: newCurrent, reservedStock: newReserved, updatedAt: FieldValue.serverTimestamp() });
          const movementRef = db.collection("inventory_movements").doc();
          tx.set(movementRef, {
            productId: snap.id,
            storeId: product.storeId,
            type: "sale",
            quantityBefore: current,
            quantityChanged: -qty,
            quantityAfter: newCurrent,
            reason: "Payment successful",
            relatedOrderId: orderId,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: order.consumerName ?? "",
            createdAt: FieldValue.serverTimestamp(),
          });
        } else {
          const available = current - reserved;
          if (qty > available) badRequest(`${product.name} no longer has enough stock (only ${available} left).`);
          const newCurrent = current - qty;
          tx.update(productRefs[idx], { currentStock: newCurrent, updatedAt: FieldValue.serverTimestamp() });
          const movementRef = db.collection("inventory_movements").doc();
          tx.set(movementRef, {
            productId: snap.id,
            storeId: product.storeId,
            type: "sale",
            quantityBefore: current,
            quantityChanged: -qty,
            quantityAfter: newCurrent,
            reason: "Payment successful (retry after earlier failure)",
            relatedOrderId: orderId,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: order.consumerName ?? "",
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      });

      tx.update(orderRef, { status: "confirmed", updatedAt: FieldValue.serverTimestamp() });
      tx.update(paymentRef, {
        status: "successful",
        providerReference: randomRef(),
        failureReason: null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      writeReceipt(tx, { orderId, order, store, orderStatus: "confirmed", paymentStatus: "successful" });
      writeTransaction(tx, { orderId, order });
    } else {
      if (wasHeld) {
        productSnaps.forEach((snap, idx) => {
          const qty = items[idx].quantity;
          if (!snap.exists) return;
          const product = snap.data()!;
          const reserved = product.reservedStock ?? 0;
          const newReserved = Math.max(0, reserved - qty);
          tx.update(productRefs[idx], { reservedStock: newReserved, updatedAt: FieldValue.serverTimestamp() });
          const movementRef = db.collection("inventory_movements").doc();
          tx.set(movementRef, {
            productId: snap.id,
            storeId: product.storeId,
            type: "reservationReleased",
            quantityBefore: reserved,
            quantityChanged: -qty,
            quantityAfter: newReserved,
            reason: "Payment failed — stock released",
            relatedOrderId: orderId,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: order.consumerName ?? "",
            createdAt: FieldValue.serverTimestamp(),
          });
        });
      }

      tx.update(orderRef, { status: "paymentFailed", updatedAt: FieldValue.serverTimestamp() });
      tx.update(paymentRef, {
        status: "failed",
        failureReason: "Simulated payment failure (test mode).",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  const orderSnap = await db.collection("orders").doc(orderId).get();
  const order = orderSnap.data();
  if (order) {
    const success = simulateOutcome === "success";
    await notifyUser({
      userId: order.consumerId,
      type: success ? "paymentSuccessful" : "paymentFailed",
      title: success ? "Payment successful" : "Payment failed",
      message: success
        ? `Your payment of ₱${order.total} for ${order.storeName} was successful.`
        : `Your payment for ${order.storeName} could not be processed. Please try again.`,
      relatedRecordId: orderId,
      relatedRecordType: "order",
    });
    if (success) {
      await notifyUser({
        userId: order.merchantId,
        type: "paymentSuccessful",
        title: "Payment received",
        message: `Payment of ₱${order.total} received for order from ${order.consumerName}.`,
        relatedRecordId: orderId,
        relatedRecordType: "order",
      });
    }
  }

  return { status: simulateOutcome === "success" ? "confirmed" : "paymentFailed" };
});
