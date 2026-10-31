import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/reservation_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/order_repository.dart';
import '../data/reservation_repository.dart';
import '../../../models/order.dart' as model;

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
          return _ConsumerOrdersBody(orders: orders);
        },
      ),
    );
  }
}

class _ConsumerOrdersBody extends StatefulWidget {
  final List<model.Order> orders;
  const _ConsumerOrdersBody({required this.orders});

  @override
  State<_ConsumerOrdersBody> createState() => _ConsumerOrdersBodyState();
}

class _ConsumerOrdersBodyState extends State<_ConsumerOrdersBody> {
  String _selected = 'all';

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final counts = <String, int>{};
    counts['all'] = orders.length;
    for (final o in orders) {
      counts[o.status.name] = (counts[o.status.name] ?? 0) + 1;
    }
    final filtered = _selected == 'all'
        ? orders
        : orders.where((o) => o.status.name == _selected).toList();

    final tabs = <Map<String, String>>[
      {'key': 'all', 'label': 'All'},
      {'key': 'pendingPayment', 'label': 'Pending'},
      {'key': 'confirmed', 'label': 'Confirmed'},
      {'key': 'preparing', 'label': 'Preparing'},
      {'key': 'readyForPickup', 'label': 'Ready for Pickup'},
      {'key': 'outForDelivery', 'label': 'Out for Delivery'},
      {'key': 'completed', 'label': 'Completed'},
      {'key': 'cancelled', 'label': 'Cancelled'},
      {'key': 'paymentFailed', 'label': 'Payment Failed'},
      {'key': 'refunded', 'label': 'Refunded'},
    ];
    final visibleTabs = tabs.where((t) => t['key'] == 'all' || (counts[t['key']] ?? 0) > 0).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visibleTabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = visibleTabs[i];
              final key = t['key']!;
              final selected = _selected == key;
              final count = counts[key] ?? 0;
              return ChoiceChip(
                label: Text('${t['label']} ($count)'),
                selected: selected,
                onSelected: (_) => setState(() => _selected = key),
                selectedColor: AppColors.primarySurface,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateView(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No ${_selected == 'all' ? '' : visibleTabs.firstWhere((t) => t['key'] == _selected)['label']!.toLowerCase() + ' '}orders',
                  message: 'Orders with this status will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => OrderListTile(
                    order: filtered[i],
                    onTap: () => context.push('/consumer/order-details/${filtered[i].id}'),
                  ),
                ),
        ),
      ],
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
