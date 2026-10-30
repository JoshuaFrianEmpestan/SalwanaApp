import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface VerifyAccountRequest {
  targetUserId: string;
  targetType: "merchant" | "supplier";
  decision: "approve" | "reject";
  reason?: string;
}

/**
 * Admin approves/rejects a merchant or supplier registration (§2 step 7,
 * §4, §21). Updates both the user doc and the store/supplier profile doc
 * together so they never disagree, and always writes an audit log entry —
 * this is exactly the kind of administrative correction §4 requires to be
 * recorded, not left to the calling client to remember.
 */
export const verifyAccount = onCall<VerifyAccountRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { targetUserId, targetType, decision, reason } = request.data ?? {};
  if (!targetUserId || !targetType || !decision) badRequest("Missing required fields.");
  if (decision === "reject" && (!reason || !reason.trim())) badRequest("A reason is required to reject an account.");

  const adminSnap = await db.collection("users").doc(uid).get();
  if (adminSnap.data()?.role !== "admin") badRequest("Only administrators can verify accounts.");
  const admin = adminSnap.data()!;

  const targetRef = db.collection("users").doc(targetUserId);
  const profileCollection = targetType === "merchant" ? "stores" : "suppliers";
  const profileRef = db.collection(profileCollection).doc(targetUserId);

  const newStatus = decision === "approve" ? "active" : "rejected";

  await db.runTransaction(async (tx) => {
    const targetSnap = await tx.get(targetRef);
    const profileSnap = await tx.get(profileRef);
    if (!targetSnap.exists) badRequest("Account not found.");
    if (targetSnap.data()?.role !== targetType) badRequest("Account role mismatch.");

    tx.update(targetRef, {
      status: newStatus,
      statusReason: decision === "reject" ? reason!.trim() : null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (profileSnap.exists) {
      tx.update(profileRef, {
        verificationStatus: newStatus,
        verificationNote: decision === "reject" ? reason!.trim() : null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      // Ensure a profile document exists so verification state is persisted
      // even for accounts that never completed onboarding.
      if (targetType === "merchant") {
        tx.set(profileRef, {
          merchantId: targetUserId,
          name: "My Store",
          description: "",
          category: "General",
          phone: "",
          email: "",
          addressLine: "",
          city: "",
          verificationStatus: newStatus,
          verificationNote: decision === "reject" ? reason!.trim() : null,
          barcodeEnabled: false,
          reservationExpirationMinutes: 120,
          averageRating: 0,
          ratingCount: 0,
          planTier: "free",
          isOpen: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(profileRef, {
          userId: targetUserId,
          companyName: "My Company",
          contactName: "",
          phone: "",
          email: "",
          address: "",
          suppliedCategories: [],
          verificationStatus: newStatus,
          verificationNote: decision === "reject" ? reason!.trim() : null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });

  await writeAuditLog({
    actorUserId: uid,
    actorName: admin.fullName ?? "Admin",
    actorRole: "admin",
    action: decision === "approve" ? "verify_account_approved" : "verify_account_rejected",
    targetType,
    targetId: targetUserId,
    reason: reason?.trim() ?? "Approved — met verification requirements.",
  });

  await notifyUser({
    userId: targetUserId,
    type: "accountVerification",
    title: decision === "approve" ? "Account verified" : "Verification rejected",
    message:
      decision === "approve"
        ? "Your account has been verified. You now have full access."
        : `Your account verification was rejected: ${reason}`,
    relatedRecordId: targetUserId,
    relatedRecordType: "user",
  });

  return { status: newStatus };
});
