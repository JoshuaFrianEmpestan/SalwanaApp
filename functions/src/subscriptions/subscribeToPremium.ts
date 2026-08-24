import { onCall } from "firebase-functions/v2/https";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { badRequest, requireAuth } from "../lib/errors";
import { notifyUser } from "../lib/notify";

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Simulated Premium subscription purchase (§14) — no real payment
 * gateway is involved, matching how GCash/Maya are simulated elsewhere
 * (§6). Always exactly 30 days from now; calling this again while already
 * Premium simply extends the existing subscription rather than stacking.
 */
export const subscribeToPremium = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);

  const merchantSnap = await db.collection("users").doc(uid).get();
  if (!merchantSnap.exists || merchantSnap.data()?.role !== "merchant") {
    badRequest("Only merchant accounts can subscribe.");
  }

  const subscriptionRef = db.collection("subscriptions").doc(uid);
  const now = Date.now();
  const existing = await subscriptionRef.get();
  const currentExpiry = existing.exists ? (existing.data()?.expiresAt as Timestamp | undefined)?.toMillis() : undefined;
  const base = currentExpiry && currentExpiry > now ? currentExpiry : now;
  const expiresAt = Timestamp.fromMillis(base + THIRTY_DAYS_MS);

  await subscriptionRef.set(
    {
      merchantId: uid,
      storeId: uid,
      planId: "premium",
      tier: "premium",
      startedAt: existing.exists ? existing.data()?.startedAt ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      expiresAt,
      autoRenew: false,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: existing.exists ? existing.data()?.createdAt ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await notifyUser({
    userId: uid,
    type: "general",
    title: "Premium activated",
    message: "Your Salwana Premium subscription is now active.",
    relatedRecordId: uid,
    relatedRecordType: "subscription",
  });

  return { expiresAtIso: expiresAt.toDate().toISOString() };
});
