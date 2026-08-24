import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/reservation_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/reservation_repository.dart';

/// Orders tab (consumer). Reservations are fully wired (module 6); the
/// Orders sub-tab becomes real once order management (module 8) lands —
/// checkout already creates the order records, this just doesn't have a
/// dedicated timeline view for them yet.
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
            tabs: [Tab(text: 'Reservations'), Tab(text: 'Orders')],
          ),
        ),
        body: const TabBarView(
          children: [_ConsumerReservationsList(), _OrdersComingSoon()],
        ),
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

class _OrdersComingSoon extends StatelessWidget {
  const _OrdersComingSoon();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: 'Order tracking coming soon',
      message: 'Checkout already creates your orders — a dedicated tracking timeline arrives with order management (module 8).',
    );
  }
}
