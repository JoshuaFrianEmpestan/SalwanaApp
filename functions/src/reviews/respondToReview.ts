import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface RespondRequest {
  reviewId: string;
  response: string;
}

/** Merchant response to a store review (§10) — merchant may only respond
 * to reviews on their own store. */
export const respondToReview = onCall<RespondRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { reviewId, response } = request.data ?? {};
  if (!reviewId) badRequest("Missing reviewId.");
  if (!response || !response.trim()) badRequest("Response is required.");

  const reviewRef = db.collection("store_reviews").doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) badRequest("Review not found.");
  const review = reviewSnap.data()!;

  const storeSnap = await db.collection("stores").doc(review.storeId).get();
  if (!storeSnap.exists || storeSnap.data()?.merchantId !== uid) {
    badRequest("You are not authorized to respond to this review.");
  }

  await reviewRef.update({
    merchantResponse: response.trim(),
    merchantResponseAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await notifyUser({
    userId: review.consumerId,
    type: "general",
    title: "Merchant responded to your review",
    message: `${storeSnap.data()?.name ?? "A store"} responded to your review.`,
    relatedRecordId: reviewId,
    relatedRecordType: "store_review",
  });

  return { status: "responded" };
});
