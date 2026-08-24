/**
 * Salwana Cloud Functions entry point. Functions are added module by
 * module alongside the corresponding Flutter feature (inventory,
 * checkout/payments, reservations, restocking, subscriptions, admin
 * moderation, ...) rather than scaffolded speculatively ahead of time.
 *
 * Deploy with `npm run deploy` from this directory, or `firebase deploy
 * --only functions` from the project root.
 */
import { onCall } from "firebase-functions/v2/https";

// Lightweight callable used to verify the Functions deployment is wired up
// correctly (project, region, IAM) before real business-logic functions
// are added on top of it.
export const healthCheck = onCall(() => {
  return { status: "ok", service: "salwana-functions", time: new Date().toISOString() };
});

export * from "./auth/onUserCreated";
export * from "./inventory/onProductStockChanged";
export * from "./checkout/processCheckout";
export * from "./reservations/createReservation";
export * from "./reservations/updateReservationStatus";
export * from "./reservations/expireReservations";
