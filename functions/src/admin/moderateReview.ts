import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { badRequest, requireAuth } from "../lib/errors";

interface ModerateReviewRequest {
  reviewId: string;
  hidden: boolean;
  reason: string;
}

/** Admin hides/unhides a reported review (§10, §4, §21) — the review and
 * its rating stay counted in the store average either way; hiding only
 * affects visibility, matching how the rest of moderation here never
 * deletes underlying records. */
export const moderateReview = onCall<ModerateReviewRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { reviewId, hidden, reason } = request.data ?? {};
  if (!reviewId || typeof hidden !== "boolean") badRequest("Missing required fields.");
  if (!reason || !reason.trim()) badRequest("A reason is required.");

  const adminSnap = await db.collection("users").doc(uid).get();
  if (adminSnap.data()?.role !== "admin") badRequest("Only administrators can moderate reviews.");
  const admin = adminSnap.data()!;

  const reviewRef = db.collection("store_reviews").doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) badRequest("Review not found.");

  await reviewRef.update({ hidden, updatedAt: FieldValue.serverTimestamp() });

  await writeAuditLog({
    actorUserId: uid,
    actorName: admin.fullName ?? "Admin",
    actorRole: "admin",
    action: hidden ? "review_hidden" : "review_unhidden",
    targetType: "store_review",
    targetId: reviewId,
    reason: reason.trim(),
  });

  return { hidden };
});
