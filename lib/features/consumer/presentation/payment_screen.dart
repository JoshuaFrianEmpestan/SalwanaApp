import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/payment_repository.dart';

/// Simulated payment screen (§6). Salwana never integrates a real payment
/// gateway here — this deliberately mirrors a sandbox/test-mode flow where
/// you choose the outcome, and is clearly labeled as such so it's never
/// mistaken for a real charge.
class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _processing = false;

  Future<void> _pay(bool success) async {
    setState(() => _processing = true);
    try {
      await ref.read(paymentRepositoryProvider).pay(orderId: widget.orderId, simulateSuccess: success);
      if (mounted) {
        if (success) {
          context.pushReplacement('/consumer/orders/${widget.orderId}/receipt');
        } else {
          showAppSnackBar(context, 'Payment failed. You can try again.', isError: true);
        }
      }
    } on PaymentException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
          data: (order) {
            if (order == null) {
              return const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Order not found', message: '');
            }
            if (order.status != OrderStatus.pendingPayment && order.status != OrderStatus.paymentFailed) {
              return EmptyStateView(
                icon: Icons.check_circle_outline_rounded,
                title: 'Nothing to pay',
                message: 'This order is already ${order.status.label.toLowerCase()}.',
                actionLabel: 'View Receipt',
                onAction: () => context.pushReplacement('/consumer/orders/${widget.orderId}/receipt'),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(Icons.science_outlined, size: 16, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(child: Text('Sandbox / simulated payment — no real money moves.', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(order.storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('via ${order.paymentMethod.label}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ...order.items.map((i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text('${i.quantity}x ${i.productName}', style: const TextStyle(fontSize: 13))),
                            Text(AppFormatters.currency(i.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(AppFormatters.currency(order.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ],
                  ),
                  const Spacer(),
                  PrimaryButton(label: 'Simulate Successful Payment', onPressed: _processing ? null : () => _pay(true), loading: _processing),
                  const SizedBox(height: 10),
                  PrimaryButton(label: 'Simulate Failed Payment', outlined: true, onPressed: _processing ? null : () => _pay(false), loading: _processing),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
