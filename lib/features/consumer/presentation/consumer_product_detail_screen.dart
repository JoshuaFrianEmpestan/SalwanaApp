import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../merchant/data/product_repository.dart';
import '../../merchant/data/store_repository.dart';

class ConsumerProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ConsumerProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_productProvider(productId))),
          data: (product) {
            if (product == null) {
              return const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Product not found', message: 'This product may no longer be available.');
            }
            final storeAsync = ref.watch(_storeProvider(product.storeId));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 11,
                    child: product.imageUrls.isNotEmpty
                        ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.cover)
                        : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    if (product.isOutOfStock)
                      const StatusBadge(label: 'Out of Stock', tone: BadgeTone.error)
                    else if (product.isLowStock)
                      const StatusBadge(label: 'Low Stock', tone: BadgeTone.warning)
                    else
                      const StatusBadge(label: 'In Stock', tone: BadgeTone.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${product.category} • ${product.brand}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Text(AppFormatters.currency(product.sellingPrice),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('${product.availableStock} ${product.unit} available', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Text(product.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                const Text('Sold by', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                storeAsync.when(
                  loading: () => const LoadingSpinner(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (store) {
                    if (store == null) return const SizedBox.shrink();
                    return InkWell(
                      onTap: () => context.push('/consumer/stores/${store.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: store.logoUrl != null
                                    ? CachedNetworkImage(imageUrl: store.logoUrl!, fit: BoxFit.cover)
                                    : Container(color: AppColors.primarySurface, child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(store.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(store.city, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text('Reviews', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                storeAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (store) {
                    if (store == null || store.ratingCount == 0) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(10)),
                        child: const Text('No reviews yet for this store.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      );
                    }
                    return Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                        const SizedBox(width: 6),
                        Text('${store.averageRating.toStringAsFixed(1)} · ${store.ratingCount} reviews',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final _productProvider = StreamProvider.family((ref, String productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});

final _storeProvider = StreamProvider.family((ref, String storeId) {
  return ref.watch(storeRepositoryProvider).watchStoreById(storeId);
});
