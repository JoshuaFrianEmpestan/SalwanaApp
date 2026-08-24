import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'status_badge.dart';

/// Product row used in the merchant inventory list. Shows the numbers a
/// merchant actually needs at a glance: available vs reserved vs current,
/// and a low-stock warning the moment available <= minStockLevel (§3).
class ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductListTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: product.imageUrls.isNotEmpty
                    ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.neutralBg,
                        child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${product.category} • ${product.brand.isEmpty ? "—" : product.brand}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(AppFormatters.currency(product.sellingPrice),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (product.status != ProductStatus.active)
                  StatusBadge(label: product.status.label, tone: BadgeTone.neutral)
                else if (product.isOutOfStock)
                  const StatusBadge(label: 'Out of Stock', tone: BadgeTone.error)
                else if (product.isLowStock)
                  const StatusBadge(label: 'Low Stock', tone: BadgeTone.warning)
                else
                  const StatusBadge(label: 'In Stock', tone: BadgeTone.success),
                const SizedBox(height: 6),
                Text('${product.availableStock} ${product.unit} avail.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (product.reservedStock > 0)
                  Text('${product.reservedStock} reserved',
                      style: const TextStyle(fontSize: 11, color: AppColors.pending)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
