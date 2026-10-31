import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_network_image.dart';

/// Grid card for consumer-facing product browsing (§1, §5). Shows exactly
/// what a buyer needs to decide: photo, name, store, price, availability —
/// no merchant-only figures like cost price or reserved stock.
class ConsumerProductCard extends StatelessWidget {
  final Product product;
  final String? storeName;
  final VoidCallback onTap;

  const ConsumerProductCard({super.key, required this.product, this.storeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.isOutOfStock;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-image-${product.id}',
                    child: product.imageUrls.isNotEmpty
                        ? AppNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.cover)
                        : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 32)),
                  ),
                  if (outOfStock)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const Text('OUT OF STOCK',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  if (storeName != null) ...[
                    const SizedBox(height: 2),
                    Text(storeName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  Text(AppFormatters.currency(product.sellingPrice),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
