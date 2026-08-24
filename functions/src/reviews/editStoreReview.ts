import { onCall } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, failedPrecondition, requireAuth } from "../lib/errors";

const EDIT_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

interface EditReviewRequest {
  reviewId: string;
  rating: number;
  feedback: string;
}

export const editStoreReview = onCall<EditReviewRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { reviewId, rating, feedback } = request.data ?? {};
  if (!reviewId) badRequest("Missing reviewId.");
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) badRequest("Rating must be a whole number from 1 to 5.");
  if (!feedback || !feedback.trim()) badRequest("Feedback is required.");

  await db.runTransaction(async (tx) => {
    const reviewRef = db.collection("store_reviews").doc(reviewId);
    const reviewSnap = await tx.get(reviewRef);
    if (!reviewSnap.exists) badRequest("Review not found.");
    const review = reviewSnap.data()!;

    if (review.consumerId !== uid) badRequest("You can only edit your own review.");
    const createdAtMs = (review.createdAt as Timestamp).toMillis();
    if (Date.now() - createdAtMs > EDIT_WINDOW_MS) {
      failedPrecondition("The edit window for this review has passed.");
    }

    const storeRef = db.collection("stores").doc(review.storeId);
    const storeSnap = await tx.get(storeRef);
    if (storeSnap.exists && rating !== review.rating) {
      const store = storeSnap.data()!;
      const count = store.ratingCount ?? 1;
      const oldAvg = store.averageRating ?? 0;
      const newAvg = (oldAvg * count - review.rating + rating) / count;
      tx.update(storeRef, { averageRating: newAvg });
    }

    tx.update(reviewRef, { rating, feedback: feedback.trim(), updatedAt: FieldValue.serverTimestamp() });
  });

  return { status: "updated" };
});
