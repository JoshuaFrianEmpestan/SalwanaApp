import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/product.dart';
import '../data/product_repository.dart';
import '../data/store_repository.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _generating = false;
  bool _printing = false;

  Future<void> _generateBarcode(Product product) async {
    setState(() => _generating = true);
    try {
      await ref.read(productRepositoryProvider).updateProductDetails(product.id, {'barcode': 'SLW-${product.id}'});
      if (mounted) showAppSnackBar(context, 'Barcode generated.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not generate barcode.', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _printCode(Product product) async {
    setState(() => _printing = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Salwana', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: product.barcode!, width: 160, height: 160),
                pw.SizedBox(height: 8),
                pw.Text(product.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(product.barcode!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
        ),
      );
      await Printing.sharePdf(bytes: await doc.save(), filename: '${product.name.replaceAll(' ', '_')}_code.pdf');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not generate the printable code.', isError: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

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
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_detailProvider(widget.productId));
    final store = ref.watch(myStoreProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_detailProvider(widget.productId))),
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
                        ? CachedNetworkImage(fadeInDuration: Duration.zero, placeholder: (ctx, url) => Container(color: AppColors.neutralBg), errorWidget: (ctx, url, err) => Container(color: AppColors.neutralBg, child: const Icon(Icons.broken_image_outlined)), imageUrl: product.imageUrls.first, fit: BoxFit.cover)
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
                _InfoRow(label: 'Created', value: AppFormatters.date(product.createdAt)),
                _InfoRow(label: 'Last Updated', value: AppFormatters.date(product.updatedAt)),
                if (store?.barcodeEnabled ?? false) ...[
                  const SizedBox(height: 20),
                  const Text('Barcode / QR Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: (product.barcode?.isNotEmpty ?? false)
                        ? Column(
                            children: [
                              QrImageView(data: product.barcode!, size: 140, backgroundColor: Colors.white),
                              const SizedBox(height: 10),
                              Text(product.barcode!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _printing ? null : () => _printCode(product),
                                      icon: const Icon(Icons.print_outlined, size: 16),
                                      label: Text(_printing ? 'Preparing...' : 'Print / Download'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _generating ? null : () => _generateBarcode(product),
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Regenerate'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              const Text('No code assigned yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 10),
                              PrimaryButton(label: 'Generate Barcode', onPressed: () => _generateBarcode(product), loading: _generating),
                            ],
                          ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/merchant/products/${product.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Product'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/merchant/products/${product.id}/adjust-stock'),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Adjust Stock'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
      crossAxisCount: Breakpoints.gridColumns(constraints.maxWidth),
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
      ),
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
