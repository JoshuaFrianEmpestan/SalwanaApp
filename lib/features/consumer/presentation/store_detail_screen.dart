import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/consumer_product_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../merchant/data/store_repository.dart';
import '../data/catalog_repository.dart';
import '../data/order_repository.dart';

class StoreDetailScreen extends ConsumerWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(_storeProvider(storeId));

    return Scaffold(
      body: SafeArea(
        child: storeAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_storeProvider(storeId))),
          data: (store) {
            if (store == null) {
              return const EmptyStateView(icon: Icons.storefront_outlined, title: 'Store not found', message: 'This store may no longer be available.');
            }
            final productsAsync = ref.watch(storeActiveProductsProvider(store.merchantId.isNotEmpty ? store.merchantId : storeId));

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 160,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: store.bannerUrl != null
                        ? CachedNetworkImage(imageUrl: store.bannerUrl!, fit: BoxFit.cover)
                        : Container(color: AppColors.primarySurface),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: store.logoUrl != null
                                    ? CachedNetworkImage(imageUrl: store.logoUrl!, fit: BoxFit.cover)
                                    : Container(color: AppColors.primarySurface, child: const Icon(Icons.storefront_rounded, color: AppColors.primary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(store.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('${store.category} • ${store.city}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      StatusBadge(label: store.isOpen ? 'Open' : 'Closed', tone: store.isOpen ? BadgeTone.success : BadgeTone.neutral),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                      const SizedBox(width: 2),
                                      Text(
                                        store.ratingCount > 0 ? '${store.averageRating.toStringAsFixed(1)} (${store.ratingCount} reviews)' : 'No reviews yet',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(store.description, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
                        const SizedBox(height: 14),
                        _ContactRow(icon: Icons.call_outlined, text: store.phone),
                        _ContactRow(icon: Icons.mail_outline_rounded, text: store.email),
                        _ContactRow(icon: Icons.location_on_outlined, text: store.addressLine),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/consumer/stores/$storeId/reviews'),
                          icon: const Icon(Icons.star_outline_rounded, size: 18),
                          label: Text(store.ratingCount > 0 ? 'See all ${store.ratingCount} reviews' : 'See reviews'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final orders = ref.read(consumerOrdersProvider).valueOrNull ?? const [];
                            final candidates = orders.where((o) => o.storeId == storeId && o.status == OrderStatus.completed && !o.reviewed).toList();
                            if (candidates.isEmpty) {
                              if (context.mounted) showAppSnackBar(context, 'Complete an order from this store before reviewing.', isError: true);
                              return;
                            }
                            if (context.mounted) context.push('/consumer/orders/${candidates.first.id}/review');
                          },
                          icon: const Icon(Icons.rate_review_outlined, size: 18),
                          label: const Text('Write a Review'),
                        ),
                        const SizedBox(height: 20),
                        const Text('Products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                productsAsync.when(
                  loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: LoadingSpinner())),
                  error: (e, _) => SliverToBoxAdapter(child: ErrorStateView(onRetry: () => ref.invalidate(storeActiveProductsProvider(storeId)))),
                  data: (products) {
                    if (products.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: EmptyStateView(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products yet',
                          message: 'This store has not listed any products.',
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ConsumerProductCard(
                            product: products[i],
                            onTap: () => context.push('/consumer/products/${products[i].id}'),
                          ),
                          childCount: products.length,
                        ),
                      ),
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

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

final _storeProvider = StreamProvider.family((ref, String storeId) {
  return ref.watch(storeRepositoryProvider).watchStoreById(storeId);
});
