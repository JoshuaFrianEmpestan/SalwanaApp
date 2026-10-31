import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reservation_status_visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/reservation.dart';
import '../data/reservation_repository.dart';
import '../../../core/widgets/app_network_image.dart';

/// Shared by both the consumer and merchant nav — which actions are shown
/// is derived purely from the signed-in user's role and ownership of the
/// reservation (§4, §21).
class ReservationDetailScreen extends ConsumerStatefulWidget {
  final String reservationId;
  const ReservationDetailScreen({super.key, required this.reservationId});

  @override
  ConsumerState<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends ConsumerState<ReservationDetailScreen> {
  bool _acting = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) showAppSnackBar(context, 'Reservation updated.');
    } on ReservationException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not update this reservation.', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Reservation'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _act(() => ref.read(reservationRepositoryProvider).reject(widget.reservationId, reason));
  }

  @override
  Widget build(BuildContext context) {
    final reservationAsync = ref.watch(reservationDetailProvider(widget.reservationId));
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final repo = ref.read(reservationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Details')),
      body: SafeArea(
        child: reservationAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(reservationDetailProvider(widget.reservationId))),
          data: (reservation) {
            if (reservation == null || appUser == null) {
              return const EmptyStateView(icon: Icons.event_busy_outlined, title: 'Reservation not found', message: '');
            }

            final isMerchant = appUser.role == UserRole.merchant && appUser.id == reservation.merchantId;
            final isConsumer = appUser.role == UserRole.consumer && appUser.id == reservation.consumerId;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: reservation.productImageUrl != null
                            ? AppNetworkImage(imageUrl: reservation.productImageUrl!, fit: BoxFit.cover)
                            : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reservation.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(reservation.storeName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          StatusBadge(label: reservation.status.label, tone: reservationStatusTone(reservation.status)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Row('Consumer', reservation.consumerName),
                _Row('Quantity', '${reservation.quantity}'),
                _Row('Unit Price', AppFormatters.currency(reservation.unitPrice)),
                _Row('Total', AppFormatters.currency(reservation.total)),
                _Row('Fulfillment', reservation.fulfillmentType.label),
                if (reservation.deliveryAddressText != null) _Row('Delivery Address', reservation.deliveryAddressText!),
                _Row('Scheduled For', AppFormatters.dateTime(reservation.scheduledFor)),
                _Row('Expires At', AppFormatters.dateTime(reservation.expiresAt)),
                if (reservation.notes?.isNotEmpty == true) _Row('Notes', reservation.notes!),
                if (reservation.rejectionReason?.isNotEmpty == true) _Row('Rejection Reason', reservation.rejectionReason!),
                const SizedBox(height: 24),
                if (isMerchant) ..._merchantActions(reservation, repo),
                if (isConsumer) ..._consumerActions(reservation, repo),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _merchantActions(Reservation r, ReservationRepository repo) {
    switch (r.status) {
      case ReservationStatus.pending:
        return [
          PrimaryButton(label: 'Approve', onPressed: () => _act(() => repo.approve(r.id)), loading: _acting),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Reject', outlined: true, onPressed: _reject),
        ];
      case ReservationStatus.approved:
        return [PrimaryButton(label: 'Mark as Preparing', onPressed: () => _act(() => repo.markPreparing(r.id)), loading: _acting)];
      case ReservationStatus.preparing:
        return [
          PrimaryButton(
            label: r.fulfillmentType == FulfillmentType.pickup ? 'Mark Ready for Pickup' : 'Mark Out for Delivery',
            onPressed: () => _act(() => r.fulfillmentType == FulfillmentType.pickup ? repo.markReadyForPickup(r.id) : repo.markOutForDelivery(r.id)),
            loading: _acting,
          ),
        ];
      case ReservationStatus.readyForPickup:
      case ReservationStatus.outForDelivery:
        return [PrimaryButton(label: 'Mark as Completed', onPressed: () => _act(() => repo.markCompleted(r.id)), loading: _acting)];
      default:
        return [];
    }
  }

  List<Widget> _consumerActions(Reservation r, ReservationRepository repo) {
    if (!{ReservationStatus.pending, ReservationStatus.approved, ReservationStatus.preparing}.contains(r.status)) return [];
    return [
      PrimaryButton(
        label: 'Cancel Reservation',
        outlined: true,
        onPressed: () async {
          final confirmed = await showConfirmDialog(context, title: 'Cancel Reservation', message: 'Are you sure you want to cancel this reservation?', confirmLabel: 'Cancel Reservation', destructive: true);
          if (confirmed) await _act(() => repo.cancel(r.id));
        },
        loading: _acting,
      ),
    ];
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
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
