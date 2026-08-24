import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/reservation_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/order_repository.dart';
import '../data/reservation_repository.dart';

/// Orders tab (consumer) — Reservations (module 6) and Orders (module 8)
/// side by side, since a consumer manages both the same way day to day.
class ConsumerOrdersTabScreen extends StatelessWidget {
  const ConsumerOrdersTabScreen({super.key});

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
          children: [_ConsumerOrdersList(), _ConsumerReservationsList()],
        ),
      ),
    );
  }
}

class _ConsumerOrdersList extends ConsumerWidget {
  const _ConsumerOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(consumerOrdersProvider);
    return SafeArea(
      child: ordersAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(consumerOrdersProvider)),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Orders you place at checkout will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => OrderListTile(
              order: orders[i],
              onTap: () => context.push('/consumer/order-details/${orders[i].id}'),
            ),
          );
        },
      ),
    );
  }
}

class _ConsumerReservationsList extends ConsumerWidget {
  const _ConsumerReservationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(consumerReservationsProvider);
    return SafeArea(
      child: reservationsAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(consumerReservationsProvider)),
        data: (reservations) {
          if (reservations.isEmpty) {
            return const EmptyStateView(
              icon: Icons.event_available_outlined,
              title: 'No reservations yet',
              message: 'Reserve a product from any store to see it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => ReservationListTile(
              reservation: reservations[i],
              onTap: () => context.push('/consumer/reservations/${reservations[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
