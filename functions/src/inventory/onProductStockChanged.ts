import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { notifyUser } from "../lib/notify";

/**
 * Fires automatically low-stock alerts (§3, §13 merchant dashboard) the
 * moment available stock crosses at-or-below the product's minimum level,
 * no matter which module changed the stock (manual adjustment here,
 * checkout/reservation/supplier-delivery in later modules — they all just
 * update the same `products` document). Only fires on the crossing edge,
 * not on every write while already low, so merchants aren't spammed.
 */
export const onProductStockChanged = onDocumentUpdated("products/{productId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const minLevel = after.minStockLevel ?? 0;
  const availableBefore = (before.currentStock ?? 0) - (before.reservedStock ?? 0);
  const availableAfter = (after.currentStock ?? 0) - (after.reservedStock ?? 0);

  const crossedIntoLowStock = availableBefore > minLevel && availableAfter <= minLevel;
  if (!crossedIntoLowStock || after.status !== "active") return;

  await notifyUser({
    userId: after.merchantId,
    type: "lowStock",
    title: "Low stock alert",
    message: `${after.name} is running low — only ${availableAfter} ${after.unit ?? "pc"} available (minimum is ${minLevel}).`,
    relatedRecordId: event.params.productId,
    relatedRecordType: "product",
  });
});
