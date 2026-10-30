import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface SubmitReviewRequest {
  orderId: string;
  rating: number;
  feedback: string;
}

/**
 * Store reviews (§10). Only a consumer with a completed order for that
 * store may review it — enforced here by re-reading the order, not
 * trusted from the client. The review doc id is the order id, which is
 * what makes "one review per completed order" structurally impossible to
 * violate (a second submit for the same order just overwrites via edit,
 * handled separately with its own edit-window check).
 */
export const submitStoreReview = onCall<SubmitReviewRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { orderId, rating, feedback } = request.data ?? {};
  if (!orderId) badRequest("Missing orderId.");
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) badRequest("Rating must be a whole number from 1 to 5.");
  if (!feedback || !feedback.trim()) badRequest("Feedback is required.");

  const consumerSnap = await db.collection("users").doc(uid).get();
  const consumer = consumerSnap.data();

  const reviewRef = db.collection("store_reviews").doc(orderId);

  await db.runTransaction(async (tx) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) badRequest("Order not found.");
    const order = orderSnap.data()!;

    if (order.consumerId !== uid) badRequest("You can only review your own orders.");
    if (order.status !== "completed") failedPrecondition("You can only review a store after your order is completed.");

    const existingSnap = await tx.get(reviewRef);
    if (existingSnap.exists) failedPrecondition("You have already reviewed this order. Edit your existing review instead.");

    const storeRef = db.collection("stores").doc(order.storeId);
    const storeSnap = await tx.get(storeRef);
    if (storeSnap.exists) {
      const store = storeSnap.data()!;
      const oldCount = store.ratingCount ?? 0;
      const oldAvg = store.averageRating ?? 0;
      const newCount = oldCount + 1;
      const newAvg = (oldAvg * oldCount + rating) / newCount;
      tx.update(storeRef, { averageRating: newAvg, ratingCount: newCount });
    }

    tx.set(reviewRef, {
      storeId: order.storeId,
      consumerId: uid,
      consumerName: consumer?.fullName ?? order.consumerName ?? "",
      orderId,
      rating,
      feedback: feedback.trim(),
      merchantResponse: null,
      merchantResponseAt: null,
      reported: false,
      reportReason: null,
      hidden: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.update(orderRef, { reviewed: true, updatedAt: FieldValue.serverTimestamp() });
  });

  const orderSnap = await db.collection("orders").doc(orderId).get();
  const order = orderSnap.data();
  if (order) {
    await notifyUser({
      userId: order.merchantId,
      type: "reviewReceived",
      title: "New store review",
      message: `${consumer?.fullName ?? "A consumer"} left a ${rating}-star review for ${order.storeName}.`,
      relatedRecordId: orderId,
      relatedRecordType: "store_review",
    });
  }

  return { reviewId: orderId };
});
