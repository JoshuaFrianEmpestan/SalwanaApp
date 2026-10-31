import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/order_status_visuals.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/order.dart' as model;
import '../data/order_repository.dart';
import '../data/payment_repository.dart';

/// Shared by both the consumer and merchant nav, same pattern as
/// ReservationDetailScreen — visible actions come from role + ownership,
/// never from which nav the screen was opened from (§8, §21).
class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _acting = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) showAppSnackBar(context, 'Order updated.');
    } on OrderActionException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not update this order.', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel(String orderId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel Order',
      message: 'Are you sure you want to cancel this order? Any deducted stock will be returned.',
      confirmLabel: 'Cancel Order',
      destructive: true,
    );
    if (confirmed) await _act(() => ref.read(orderRepositoryProvider).cancel(orderId, null));
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final repo = ref.read(orderRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
          data: (order) {
            if (order == null || appUser == null) {
              return const EmptyStateView(icon: Icons.receipt_long_outlined, title: 'Order not found', message: '');
            }

            final isMerchant = appUser.role == UserRole.merchant && appUser.id == order.merchantId;
            final isConsumer = appUser.role == UserRole.consumer && appUser.id == order.consumerId;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(order.storeName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    StatusBadge(label: order.status.label, tone: orderStatusTone(order.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(showConsumer(isMerchant, order), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item.quantity}x ${item.productName}', style: const TextStyle(fontSize: 13))),
                              Text(AppFormatters.currency(item.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      const Divider(),
                      _totalsRow('Subtotal', order.subtotal),
                      if (order.deliveryFee > 0) _totalsRow('Delivery Fee', order.deliveryFee),
                      if (order.platformFee > 0) _totalsRow('Platform Fee', order.platformFee),
                      if (order.discount > 0) _totalsRow('Discount', -order.discount),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(AppFormatters.currency(order.total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Row('Payment Method', order.paymentMethod.label),
                _Row('Fulfillment', order.fulfillmentType.label),
                if (order.deliveryAddressText != null) _Row('Delivery Address', order.deliveryAddressText!),
                if (order.notes?.isNotEmpty == true) _Row('Notes', order.notes!),
                if (order.cancellationReason?.isNotEmpty == true) _Row('Cancellation Reason', order.cancellationReason!),
                _Row('Placed', AppFormatters.dateTime(order.createdAt)),
                const SizedBox(height: 20),
                if (order.status == OrderStatus.pendingPayment || order.status == OrderStatus.paymentFailed)
                  if (isConsumer)
                    PrimaryButton(label: 'Pay Now', onPressed: () => context.push('/consumer/orders/${order.id}/pay')),
                if (order.status.index > OrderStatus.pendingPayment.index && order.status != OrderStatus.paymentFailed && order.status != OrderStatus.cancelled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => context.push(isMerchant ? '/merchant/orders/${order.id}/receipt' : '/consumer/orders/${order.id}/receipt'), child: const Text('View Receipt')),
                ],
                if (isConsumer && order.status == OrderStatus.completed) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/consumer/orders/${order.id}/review'),
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: Text(order.reviewed ? 'Edit Your Review' : 'Write a Review'),
                  ),
                ],
                const SizedBox(height: 10),
                if (isMerchant) ..._merchantActions(order, repo),
                if (isConsumer) ..._consumerActions(order),
              ],
            );
          },
        ),
      ),
    );
  }

  String showConsumer(bool isMerchant, model.Order order) => isMerchant ? 'Ordered by ${order.consumerName}' : order.storeName;

  Widget _totalsRow(String label, double amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(AppFormatters.currency(amount), style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  List<Widget> _merchantActions(model.Order order, OrderRepository repo) {
    final widgets = <Widget>[];
    switch (order.status) {
      case OrderStatus.confirmed:
        widgets.add(PrimaryButton(label: 'Mark as Preparing', onPressed: () => _act(() => repo.markPreparing(order.id)), loading: _acting));
        break;
      case OrderStatus.preparing:
        widgets.add(PrimaryButton(
          label: order.fulfillmentType == FulfillmentType.pickup ? 'Mark Ready for Pickup' : 'Mark Out for Delivery',
          onPressed: () => _act(() => order.fulfillmentType == FulfillmentType.pickup ? repo.markReadyForPickup(order.id) : repo.markOutForDelivery(order.id)),
          loading: _acting,
        ));
        break;
      case OrderStatus.readyForPickup:
      case OrderStatus.outForDelivery:
        widgets.add(PrimaryButton(label: 'Mark as Completed', onPressed: () => _act(() => repo.markCompleted(order.id)), loading: _acting));
        break;
      case OrderStatus.completed:
        widgets.add(PrimaryButton(
          label: 'Issue Refund',
          outlined: true,
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Issue Refund',
              message: 'Are you sure you want to refund this order? The order total of ${AppFormatters.currency(order.total)} will be recorded as refunded and the order will be marked as refunded.',
              confirmLabel: 'Issue Refund',
              destructive: true,
            );
            if (confirmed) await _act(() => repo.refund(order.id));
          },
          loading: _acting,
        ));
        break;
      default:
        break;
    }
    if ({OrderStatus.pendingPayment, OrderStatus.confirmed, OrderStatus.preparing}.contains(order.status)) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(PrimaryButton(label: 'Cancel Order', outlined: true, onPressed: () => _cancel(order.id), loading: _acting));
    }
    return widgets;
  }

  List<Widget> _consumerActions(model.Order order) {
    if (!{OrderStatus.pendingPayment, OrderStatus.confirmed}.contains(order.status)) return [];
    return [PrimaryButton(label: 'Cancel Order', outlined: true, onPressed: () => _cancel(order.id), loading: _acting)];
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
