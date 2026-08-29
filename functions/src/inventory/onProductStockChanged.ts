import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../lib/admin";
import { notifyUser } from "../lib/notify";

/**
 * Fires automatic low-stock alerts (§3, §13 merchant dashboard) and
 * Back-in-Stock alerts to followers (§4, §9, §13), the moment available
 * stock crosses the relevant threshold — no matter which module changed
 * the stock (manual adjustment here, checkout/reservation/supplier-
 * delivery elsewhere; they all just update the same `products` document).
 * Only fires on the crossing edge, not on every write while already
 * low/in-stock, so nobody gets spammed.
 */
export const onProductStockChanged = onDocumentUpdated("products/{productId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const productId = event.params.productId;
  const minLevel = after.minStockLevel ?? 0;
  const availableBefore = (before.currentStock ?? 0) - (before.reservedStock ?? 0);
  const availableAfter = (after.currentStock ?? 0) - (after.reservedStock ?? 0);

  const crossedIntoLowStock = availableBefore > minLevel && availableAfter <= minLevel;
  if (crossedIntoLowStock && after.status === "active") {
    await notifyUser({
      userId: after.merchantId,
      type: "lowStock",
      title: "Low stock alert",
      message: `${after.name} is running low — only ${availableAfter} ${after.unit ?? "pc"} available (minimum is ${minLevel}).`,
      relatedRecordId: productId,
      relatedRecordType: "product",
    });
  }

  const backInStock = availableBefore <= 0 && availableAfter > 0;
  if (backInStock && after.status === "active") {
    const followersSnap = await db.collection("followed_products").where("productId", "==", productId).get();
    await Promise.all(
      followersSnap.docs.map(async (doc) => {
        const storeName = doc.data().storeName ?? "the store";
        await notifyUser({
          userId: doc.data().consumerId,
          type: "backInStock",
          title: "Back in stock!",
          message: `${after.name} is available again at ${storeName}.`,
          relatedRecordId: productId,
          relatedRecordType: "product",
        });
        // One-time alert — remove the follow so it doesn't fire again on
        // every subsequent restock. The consumer can re-follow any time.
        await doc.ref.delete();
      }),
    );
  }
});
