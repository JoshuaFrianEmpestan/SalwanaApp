import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/restock_status_visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/restock_request.dart';
import '../data/restock_repository.dart';

/// Shared by both the merchant and supplier nav, same role-aware pattern
/// as reservation/order detail (§9, §21).
class RestockRequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RestockRequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RestockRequestDetailScreen> createState() => _RestockRequestDetailScreenState();
}

class _RestockRequestDetailScreenState extends ConsumerState<RestockRequestDetailScreen> {
  bool _acting = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) showAppSnackBar(context, 'Request updated.');
    } on RestockException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not update this request.', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject(String id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _act(() => ref.read(restockRepositoryProvider).reject(id, reason));
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(restockRequestDetailProvider(widget.requestId));
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final repo = ref.read(restockRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Restocking Request')),
      body: SafeArea(
        child: requestAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(restockRequestDetailProvider(widget.requestId))),
          data: (r) {
            if (r == null || appUser == null) {
              return const EmptyStateView(icon: Icons.assignment_outlined, title: 'Request not found', message: '');
            }
            final isMerchant = appUser.role == UserRole.merchant && appUser.id == r.merchantId;
            final isSupplier = appUser.role == UserRole.supplier && appUser.id == r.supplierId;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(isMerchant ? r.supplierName : r.storeName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    StatusBadge(label: r.status.label, tone: restockStatusTone(r.status)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in r.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} — requested ${item.requestedQuantity}${item.receivedQuantity != null ? ', received ${item.receivedQuantity}' : ''}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(AppFormatters.currency(item.estimatedUnitCost * item.requestedQuantity), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Total', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(AppFormatters.currency(r.estimatedTotal), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (r.estimatedDeliveryDate != null) _Row('Est. Delivery', AppFormatters.date(r.estimatedDeliveryDate!)),
                if (r.notes?.isNotEmpty == true) _Row('Notes', r.notes!),
                if (r.rejectionReason?.isNotEmpty == true) _Row('Rejection Reason', r.rejectionReason!),
                _Row('Requested', AppFormatters.dateTime(r.createdAt)),
                const SizedBox(height: 20),
                if (isSupplier) ..._supplierActions(r, repo),
                if (isMerchant) ..._merchantActions(r),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _supplierActions(RestockRequest r, RestockRepository repo) {
    switch (r.status) {
      case RestockStatus.requested:
        return [
          PrimaryButton(label: 'Accept', onPressed: () => _act(() => repo.accept(r.id)), loading: _acting),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Reject', outlined: true, onPressed: () => _reject(r.id)),
        ];
      case RestockStatus.accepted:
        return [PrimaryButton(label: 'Start Processing', onPressed: () => _act(() => repo.markProcessing(r.id)), loading: _acting)];
      case RestockStatus.processing:
        return [PrimaryButton(label: 'Mark as Dispatched', onPressed: () => _act(() => repo.dispatch(r.id)), loading: _acting)];
      default:
        return [];
    }
  }

  List<Widget> _merchantActions(RestockRequest r) {
    if (r.status == RestockStatus.dispatched) {
      return [PrimaryButton(label: 'Confirm Delivery', onPressed: () => context.push('/merchant/restock-requests/${r.id}/confirm-delivery'))];
    }
    if ({RestockStatus.requested, RestockStatus.accepted}.contains(r.status)) {
      return [
        PrimaryButton(
          label: 'Cancel Request',
          outlined: true,
          onPressed: () async {
            final confirmed = await showConfirmDialog(context, title: 'Cancel Request', message: 'Cancel this restocking request?', confirmLabel: 'Cancel Request', destructive: true);
            if (confirmed) await _act(() => ref.read(restockRepositoryProvider).cancel(r.id));
          },
          loading: _acting,
        ),
      ];
    }
    return [];
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
