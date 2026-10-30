import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/product.dart';
import '../../merchant/data/product_repository.dart';
import '../../merchant/data/store_repository.dart';
import '../data/cart_repository.dart';
import '../data/followed_product_repository.dart';

class ConsumerProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ConsumerProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ConsumerProductDetailScreen> createState() => _ConsumerProductDetailScreenState();
}

class _ConsumerProductDetailScreenState extends ConsumerState<ConsumerProductDetailScreen> {
  int _quantity = 1;
  bool _adding = false;

  Future<void> _addToCart(Product product, String storeName) async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _adding = true);
    try {
      await ref.read(cartRepositoryProvider).addToCart(userId: user.id, product: product, storeName: storeName, quantity: _quantity);
      if (mounted) showAppSnackBar(context, 'Added to cart.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not add to cart. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_productProvider(widget.productId))),
          data: (product) {
            if (product == null) {
              return const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Product not found', message: 'This product may no longer be available.');
            }
            final storeAsync = ref.watch(_storeProvider(product.storeId));

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 11,
                          child: Hero(
                            tag: 'product-image-${product.id}',
                            child: product.imageUrls.isNotEmpty
                                ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.cover)
                                : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary)),
                          ),
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
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                if (!product.isOutOfStock)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            tooltip: 'Decrease quantity',
                          ),
                          Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          IconButton(
                            onPressed: _quantity < product.availableStock ? () => setState(() => _quantity++) : null,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            tooltip: 'Increase quantity',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/consumer/products/${product.id}/reserve?qty=$_quantity'),
                              child: const Text('Reserve'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: storeAsync.maybeWhen(
                              data: (store) => PrimaryButton(
                                label: 'Add to Cart',
                                loading: _adding,
                                onPressed: () => _addToCart(product, store?.name ?? ''),
                              ),
                              orElse: () => const PrimaryButton(label: 'Add to Cart', onPressed: null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                    child: SafeArea(
                      top: false,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final following = ref.watch(isFollowingProvider(product.id)).valueOrNull ?? false;
                          return PrimaryButton(
                            label: following ? 'Following — Notify Me When Back in Stock ✓' : 'Notify Me When Back in Stock',
                            outlined: following,
                            onPressed: () async {
                              final currentUser = ref.read(appUserProvider).valueOrNull;
                              if (currentUser == null) return;
                              final repo = ref.read(followedProductRepositoryProvider);
                              if (following) {
                                await repo.unfollow(currentUser.id, product.id);
                              } else {
                                final storeName = ref.read(_storeProvider(product.storeId)).valueOrNull?.name ?? '';
                                await repo.follow(consumerId: currentUser.id, product: product, storeName: storeName);
                                if (context.mounted) showAppSnackBar(context, "We'll notify you when this is back in stock.");
                              }
                            },
                          );
                        },
                      ),
                    ),
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
