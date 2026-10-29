import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/reservation_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../consumer/data/order_repository.dart';
import '../../consumer/data/reservation_repository.dart';

/// Orders tab (merchant) — Orders (module 8, fulfillment actions) and
/// Reservations (module 6) side by side.
class MerchantOrdersTabScreen extends StatelessWidget {
  const MerchantOrdersTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Orders'), Tab(text: 'Reservations')],
          ),
        ),
        body: const TabBarView(
          children: [_MerchantOrdersList(), _MerchantReservationsList()],
        ),
      ),
    );
  }
}

class _MerchantOrdersList extends ConsumerWidget {
  const _MerchantOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(merchantOrdersProvider);
    return SafeArea(
      child: ordersAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(message: e.toString(), onRetry: () => ref.invalidate(merchantOrdersProvider)),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Consumer orders for your store will appear here.',
            );
          }
          final actionable = orders.where((o) => o.status.isActive && o.status.name != 'pendingPayment').length;
          return Column(
            children: [
              if (actionable > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
                  child: Text('$actionable order${actionable == 1 ? '' : 's'} to fulfill', style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => OrderListTile(
                    order: orders[i],
                    showConsumerName: true,
                    onTap: () => context.push('/merchant/order-details/${orders[i].id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MerchantReservationsList extends ConsumerWidget {
  const _MerchantReservationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(merchantReservationsProvider);
    return SafeArea(
      child: reservationsAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(message: e.toString(), onRetry: () => ref.invalidate(merchantReservationsProvider)),
        data: (reservations) {
          if (reservations.isEmpty) {
            return const EmptyStateView(
              icon: Icons.event_available_outlined,
              title: 'No reservations yet',
              message: 'Reservation requests from consumers will appear here.',
            );
          }
          final pending = reservations.where((r) => r.status.name == 'pending').length;
          return Column(
            children: [
              if (pending > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(10)),
                  child: Text('$pending reservation${pending == 1 ? '' : 's'} awaiting your response',
                      style: const TextStyle(fontSize: 12, color: AppColors.pending, fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reservations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => ReservationListTile(
                    reservation: reservations[i],
                    showConsumerName: true,
                    onTap: () => context.push('/merchant/reservations/${reservations[i].id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
