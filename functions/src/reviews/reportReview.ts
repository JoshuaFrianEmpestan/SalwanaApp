import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";

interface ReportReviewRequest {
  reviewId: string;
  reason: string;
}

/** Flags a review for admin moderation (§10, §16) — does not hide it
 * automatically; only an admin decision does that (module 16). */
export const reportReview = onCall<ReportReviewRequest>(async (request) => {
  requireAuth(request.auth?.uid);
  const { reviewId, reason } = request.data ?? {};
  if (!reviewId) badRequest("Missing reviewId.");
  if (!reason || !reason.trim()) badRequest("A reason is required to report a review.");

  const reviewRef = db.collection("store_reviews").doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) badRequest("Review not found.");

  await reviewRef.update({
    reported: true,
    reportReason: reason.trim(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { status: "reported" };
});
