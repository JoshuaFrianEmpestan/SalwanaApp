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
import '../../../models/cart_item.dart';
import '../data/cart_repository.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartItemsProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: SafeArea(
        child: cartAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(cartItemsProvider)),
          data: (items) {
            if (items.isEmpty) {
              return EmptyStateView(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Browse stores and add products to get started.',
                actionLabel: 'Browse Stores',
                onAction: () => context.go('/consumer/stores'),
              );
            }

            final byStore = <String, List<CartItem>>{};
            for (final item in items) {
              byStore.putIfAbsent(item.storeId, () => []).add(item);
            }
            final total = items.fold<double>(0, (sum, i) => sum + i.subtotal);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      for (final entry in byStore.entries) ...[
                        Text(entry.value.first.storeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final item in entry.value) ...[
                          _CartItemTile(item: item, userId: user?.id ?? ''),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                            Text(AppFormatters.currency(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Delivery fees, discounts, and platform fees are calculated at checkout.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Proceed to Checkout',
                          onPressed: () => context.push('/consumer/checkout'),
                        ),
                      ],
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

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final String userId;
  const _CartItemTile({required this.item, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.productImageUrl != null
                  ? CachedNetworkImage(fadeInDuration: Duration.zero, placeholder: (ctx, url) => Container(color: AppColors.neutralBg), errorWidget: (ctx, url, err) => Container(color: AppColors.neutralBg, child: const Icon(Icons.broken_image_outlined)), imageUrl: item.productImageUrl!, fit: BoxFit.cover)
                  : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(AppFormatters.currency(item.unitPrice), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                tooltip: 'Decrease quantity',
                onPressed: () => ref.read(cartRepositoryProvider).updateQuantity(userId, item.productId, item.quantity - 1),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Text(
                  '${item.quantity}',
                  key: ValueKey(item.quantity),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                tooltip: 'Increase quantity',
                onPressed: () => ref.read(cartRepositoryProvider).updateQuantity(userId, item.productId, item.quantity + 1),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
            tooltip: 'Remove item',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Remove Item',
                message: 'Remove ${item.productName} from your cart?',
                confirmLabel: 'Remove',
                destructive: true,
              );
              if (confirmed) await ref.read(cartRepositoryProvider).removeItem(userId, item.productId);
            },
          ),
        ],
      ),
    );
  }
}
