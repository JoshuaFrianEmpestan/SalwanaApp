import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../lib/admin";
import { notifyUser } from "../lib/notify";

const NON_TERMINAL = new Set(["pending", "approved", "preparing", "readyForPickup", "outForDelivery"]);
const REMINDER_WINDOW_MINUTES = 30;

/**
 * Runs every 15 minutes (§4): expires reservations past their `expiresAt`
 * — releasing held stock back to available, same as a merchant rejection —
 * and sends a one-time reminder to reservations expiring within the next
 * 30 minutes. Scoped to a single bounded query (expiresAt <= now + 30m) so
 * it never needs a composite index and stays cheap to run on a schedule.
 */
export const expireReservations = onSchedule("every 15 minutes", async () => {
  const now = Date.now();
  const horizon = Timestamp.fromMillis(now + REMINDER_WINDOW_MINUTES * 60 * 1000);

  const snap = await db.collection("reservations").where("expiresAt", "<=", horizon).get();

  for (const doc of snap.docs) {
    const reservation = doc.data();
    if (!NON_TERMINAL.has(reservation.status)) continue;

    const expiresAtMs = (reservation.expiresAt as Timestamp).toMillis();

    if (expiresAtMs <= now) {
      await db.runTransaction(async (tx) => {
        const reservationRef = doc.ref;
        const freshSnap = await tx.get(reservationRef);
        const fresh = freshSnap.data();
        if (!fresh || !NON_TERMINAL.has(fresh.status)) return;

        const productRef = db.collection("products").doc(fresh.productId);
        const productSnap = await tx.get(productRef);
        if (productSnap.exists) {
          const product = productSnap.data()!;
          const reserved = product.reservedStock ?? 0;
          const newReserved = Math.max(0, reserved - fresh.quantity);
          tx.update(productRef, { reservedStock: newReserved, updatedAt: FieldValue.serverTimestamp() });

          const movementRef = db.collection("inventory_movements").doc();
          tx.set(movementRef, {
            productId: fresh.productId,
            storeId: fresh.storeId,
            type: "reservationReleased",
            quantityBefore: reserved,
            quantityChanged: -fresh.quantity,
            quantityAfter: newReserved,
            reason: "Reservation expired",
            relatedOrderId: null,
            relatedReservationId: doc.id,
            relatedDeliveryId: null,
            performedByUserId: "system",
            performedByName: "Salwana (automatic)",
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        tx.update(reservationRef, { status: "expired", updatedAt: FieldValue.serverTimestamp() });
      });

      await notifyUser({
        userId: reservation.consumerId,
        type: "reservationExpiring",
        title: "Reservation expired",
        message: `Your reservation for ${reservation.productName} at ${reservation.storeName} has expired.`,
        relatedRecordId: doc.id,
        relatedRecordType: "reservation",
      });
    } else if (!reservation.reminderSent) {
      await doc.ref.update({ reminderSent: true });
      await notifyUser({
        userId: reservation.consumerId,
        type: "reservationExpiring",
        title: "Reservation expiring soon",
        message: `Your reservation for ${reservation.productName} at ${reservation.storeName} expires soon — claim it before it's released.`,
        relatedRecordId: doc.id,
        relatedRecordType: "reservation",
      });
    }
  }
});
