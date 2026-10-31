import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/file_download.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/payment_repository.dart';
import '../../../models/digital_receipt.dart';

class DigitalReceiptScreen extends ConsumerStatefulWidget {
  final String orderId;
  const DigitalReceiptScreen({super.key, required this.orderId});

  @override
  ConsumerState<DigitalReceiptScreen> createState() => _DigitalReceiptScreenState();
}

class _DigitalReceiptScreenState extends ConsumerState<DigitalReceiptScreen> {
  bool _exporting = false;

  Future<Uint8List> _buildPdf(DigitalReceipt receipt) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Salwana', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Digital Receipt', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(receipt.receiptNumber, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Text('Store: ${receipt.storeName}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Consumer: ${receipt.consumerName}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Date: ${receipt.issuedAt}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Payment: ${receipt.paymentMethod.label} (${receipt.paymentStatus.label})', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Order Status: ${receipt.orderStatus.label}', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Qty', 'Price'],
          data: receipt.items.map((i) => [i.productName, '${i.quantity}', i.subtotal.toStringAsFixed(2)]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Subtotal: ${receipt.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
        if (receipt.deliveryFee > 0) pw.Text('Delivery Fee: ${receipt.deliveryFee.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
        if (receipt.discount > 0) pw.Text('Discount: -${receipt.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
        if (receipt.platformFee > 0) pw.Text('Platform Fee: ${receipt.platformFee.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Total: ${receipt.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Transaction Ref: ${receipt.transactionReference}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    ));
    return doc.save();
  }

  Future<void> _print(DigitalReceipt receipt) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _buildPdf(receipt);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Print failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _download(DigitalReceipt receipt) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _buildPdf(receipt);
      final fileName = 'receipt_${receipt.orderId}.pdf';
      if (kIsWeb) {
        downloadBytes(bytes, fileName, 'application/pdf');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
      if (mounted) showAppSnackBar(context, 'Receipt downloaded.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptAsync = ref.watch(receiptProvider(widget.orderId));
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Receipt')),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
          data: (order) {
            if (order == null) {
              return const EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'Order not found',
                message: 'This order may no longer be available.',
              );
            }
            final savedReceipt = receiptAsync.valueOrNull;
            DigitalReceipt? r = savedReceipt;
            if (r == null) {
                r = DigitalReceipt(
                  id: widget.orderId,
                  receiptNumber: 'SLW-${DateTime.now().year}-${widget.orderId.substring(0, 8).toUpperCase()}',
                  orderId: widget.orderId,
                  storeName: order.storeName,
                  storePhone: '',
                  storeEmail: '',
                  consumerName: order.consumerName,
                  items: order.items,
                  subtotal: order.subtotal,
                  deliveryFee: order.deliveryFee,
                  discount: order.discount,
                  platformFee: order.platformFee,
                  total: order.total,
                  paymentMethod: order.paymentMethod,
                  paymentStatus: order.paymentMethod == PaymentMethod.cashOnDelivery
                       ? PaymentStatus.successful
                       : (order.status == OrderStatus.confirmed || order.status == OrderStatus.paid || order.status == OrderStatus.completed
                           ? PaymentStatus.successful
                           : PaymentStatus.pending),
                  orderStatus: order.status,
                  transactionReference: widget.orderId,
                  issuedAt: order.createdAt,
                );
            }
            final receipt = r!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 32),
                            const SizedBox(height: 8),
                            const Text('Salwana', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                            const SizedBox(height: 4),
                            Text(receipt.receiptNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      _Row('Store', receipt.storeName),
                      _Row('Contact', receipt.storePhone.isNotEmpty ? receipt.storePhone : receipt.storeEmail),
                      _Row('Consumer', receipt.consumerName),
                      _Row('Date', AppFormatters.dateTime(receipt.issuedAt)),
                      const Divider(),
                      const SizedBox(height: 4),
                      for (final item in receipt.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${item.quantity}x ${item.productName}', style: const TextStyle(fontSize: 13)),
                              ),
                              Text(AppFormatters.currency(item.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      const Divider(),
                      _Row('Subtotal', AppFormatters.currency(receipt.subtotal)),
                      if (receipt.deliveryFee > 0) _Row('Delivery Fee', AppFormatters.currency(receipt.deliveryFee)),
                      if (receipt.discount > 0) _Row('Discount', '-${AppFormatters.currency(receipt.discount)}'),
                      if (receipt.platformFee > 0) _Row('Platform Fee', AppFormatters.currency(receipt.platformFee)),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(AppFormatters.currency(receipt.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Payment', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const Spacer(),
                          Text(receipt.paymentMethod.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          StatusBadge(label: receipt.paymentStatus.label, tone: BadgeTone.success),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Order Status', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const Spacer(),
                          StatusBadge(label: receipt.orderStatus.label, tone: BadgeTone.info),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Transaction Ref: ${receipt.transactionReference}', style: const TextStyle(fontSize: 10, color: AppColors.textDisabled)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : () {
                          final r = receipt;
                          _print(r);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _exporting ? null : () {
                          final r = receipt;
                          _download(r);
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
