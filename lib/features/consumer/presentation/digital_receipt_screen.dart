import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/payment_repository.dart';

class DigitalReceiptScreen extends ConsumerWidget {
  final String orderId;
  const DigitalReceiptScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Receipt')),
      body: SafeArea(
        child: receiptAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(receiptProvider(orderId))),
          data: (receipt) {
            if (receipt == null) {
              return const EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'Receipt not available yet',
                message: 'A receipt is generated once payment is confirmed.',
              );
            }
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
                OutlinedButton(onPressed: () => context.go('/consumer/home'), child: const Text('Done')),
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
