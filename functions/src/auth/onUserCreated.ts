import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { notifyUser } from "../lib/notify";

/**
 * Fires when a new `users/{uid}` profile is written by the client during
 * registration. For merchants/suppliers this is purely a courtesy
 * "we received your application" notification — the actual verification
 * decision is made by an admin (module 16) and notified separately via
 * `accountVerification`.
 */
export const onUserCreated = onDocumentCreated("users/{uid}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  if (data.role === "merchant" || data.role === "supplier") {
    await notifyUser({
      userId: event.params.uid,
      type: "accountVerification",
      title: "Application received",
      message: `Thanks for registering with Salwana. Your ${data.role} application is now pending review.`,
    });
  }
});
