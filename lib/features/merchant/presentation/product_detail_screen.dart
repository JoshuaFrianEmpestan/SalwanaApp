import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/product.dart';
import '../data/product_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, Product product, ProductStatus newStatus) async {
    final isDestructive = newStatus == ProductStatus.archived || newStatus == ProductStatus.deactivated;
    final confirmed = await showConfirmDialog(
      context,
      title: '${newStatus.label} Product',
      message: 'Are you sure you want to mark "${product.name}" as ${newStatus.label.toLowerCase()}?',
      confirmLabel: newStatus.label,
      destructive: isDestructive,
    );
    if (!confirmed) return;
    try {
      await ref.read(productRepositoryProvider).setStatus(product.id, newStatus);
      if (context.mounted) showAppSnackBar(context, 'Product marked as ${newStatus.label.toLowerCase()}.');
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, 'Could not update product status.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_detailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_detailProvider(productId))),
          data: (product) {
            if (product == null) {
              return const EmptyStateView(
                icon: Icons.error_outline_rounded,
                title: 'Product not found',
                message: 'This product may have been removed.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: product.imageUrls.isNotEmpty
                        ? CachedNetworkImage(imageUrl: product.imageUrls.first, fit: BoxFit.cover)
                        : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    StatusBadge(
                      label: product.status.label,
                      tone: product.status == ProductStatus.active ? BadgeTone.success : BadgeTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${product.category} • ${product.brand}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Text(AppFormatters.currency(product.sellingPrice),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('Cost: ${AppFormatters.currency(product.costPrice)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Text(product.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                _StatGrid(product: product),
                const SizedBox(height: 20),
                if (product.batchNumber?.isNotEmpty == true) _InfoRow(label: 'Batch Number', value: product.batchNumber!),
                if (product.expirationDate != null) _InfoRow(label: 'Expiration Date', value: AppFormatters.date(product.expirationDate!)),
                if (product.barcode?.isNotEmpty == true) _InfoRow(label: 'Barcode', value: product.barcode!),
                _InfoRow(label: 'Created', value: AppFormatters.date(product.createdAt)),
                _InfoRow(label: 'Last Updated', value: AppFormatters.date(product.updatedAt)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/merchant/products/${product.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Product'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/merchant/inventory/movements/${product.id}'),
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: const Text('Stock Movements'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 10),
                if (product.status == ProductStatus.active) ...[
                  OutlinedButton.icon(
                    onPressed: () => _changeStatus(context, ref, product, ProductStatus.archived),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Archive Product'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _changeStatus(context, ref, product, ProductStatus.deactivated),
                    icon: const Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.error),
                    label: const Text('Deactivate Product', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: AppColors.error)),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () => _changeStatus(context, ref, product, ProductStatus.active),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Reactivate Product'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final Product product;
  const _StatGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Current Stock', '${product.currentStock} ${product.unit}'),
      ('Reserved', '${product.reservedStock} ${product.unit}'),
      ('Available', '${product.availableStock} ${product.unit}'),
      ('Min. Level', '${product.minStockLevel} ${product.unit}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final s in stats)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                Text(s.$1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

final _detailProvider = StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});
