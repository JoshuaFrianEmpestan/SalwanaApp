import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

interface SetAccountStatusRequest {
  targetUserId: string;
  status: "active" | "suspended" | "deactivated";
  reason: string;
}

/** Admin suspends/reactivates/deactivates any account, always with a
 * recorded reason (§4, §21). Never touches the underlying store/product/
 * order data — suspension restricts access, it never deletes records. */
export const setAccountStatus = onCall<SetAccountStatusRequest>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { targetUserId, status, reason } = request.data ?? {};
  if (!targetUserId || !status) badRequest("Missing required fields.");
  if (!reason || !reason.trim()) badRequest("A reason is required for this action.");
  if (targetUserId === uid) badRequest("You cannot change your own account status.");

  const adminSnap = await db.collection("users").doc(uid).get();
  if (adminSnap.data()?.role !== "admin") badRequest("Only administrators can change account status.");
  const admin = adminSnap.data()!;

  const targetRef = db.collection("users").doc(targetUserId);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) badRequest("Account not found.");

  const profileCollection = targetSnap.data()?.role === "supplier" ? "suppliers" : "stores";
  const profileRef = db.collection(profileCollection).doc(targetUserId);
  const profileSnap = await profileRef.get();

  await targetRef.update({
    status,
    statusReason: reason.trim(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (profileSnap.exists) {
    await profileRef.update({
      verificationStatus: status === "active" ? "active" : status,
      verificationNote: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  await writeAuditLog({
    actorUserId: uid,
    actorName: admin.fullName ?? "Admin",
    actorRole: "admin",
    action: `account_status_${status}`,
    targetType: "user",
    targetId: targetUserId,
    reason: reason.trim(),
  });

  await notifyUser({
    userId: targetUserId,
    type: "securityAlert",
    title: "Account status changed",
    message: `Your account is now ${status}. Reason: ${reason.trim()}`,
    relatedRecordId: targetUserId,
    relatedRecordType: "user",
  });

  return { status };
});
