import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/payment_repository.dart';

/// Shown right after checkout completes. Each order created (one per
/// merchant, §5) shows here with its own action: pay now for online
/// methods, or a receipt link for cash-on-delivery orders that were
/// confirmed immediately.
class CheckoutResultScreen extends ConsumerWidget {
  final List<String> orderIds;
  const CheckoutResultScreen({super.key, required this.orderIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(orderIds.length == 1 ? 'Order Placed' : '${orderIds.length} Orders Placed'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(child: Text('Your order was placed. Complete payment below to finish any orders that need it.', style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final orderId in orderIds) ...[
              _OrderResultCard(orderId: orderId),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/consumer/home'),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderResultCard extends ConsumerWidget {
  final String orderId;
  const _OrderResultCard({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return orderAsync.when(
      loading: () => const LoadingListView(itemCount: 1, itemHeight: 90),
      error: (e, _) => const SizedBox.shrink(),
      data: (order) {
        if (order == null) return const SizedBox.shrink();
        final needsPayment = order.status == OrderStatus.pendingPayment || order.status == OrderStatus.paymentFailed;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.storeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                  StatusBadge(label: order.status.label, tone: needsPayment ? BadgeTone.warning : BadgeTone.success),
                ],
              ),
              const SizedBox(height: 4),
              Text('${order.items.length} item(s) · ${AppFormatters.currency(order.total)} · ${order.paymentMethod.label}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              if (needsPayment)
                FilledButton(
                  onPressed: () => context.push('/consumer/orders/$orderId/pay'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  child: const Text('Pay Now'),
                )
              else
                OutlinedButton(
                  onPressed: () => context.push('/consumer/orders/$orderId/receipt'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  child: const Text('View Receipt'),
                ),
            ],
          ),
        );
      },
    );
  }
}
