import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/consumer_product_card.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/reservation_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/store_card.dart';
import '../data/catalog_repository.dart';
import '../data/order_repository.dart';
import '../data/reservation_repository.dart';

class ConsumerHomeScreen extends ConsumerStatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  ConsumerState<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends ConsumerState<ConsumerHomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(activeStoresProvider);
    ref.invalidate(catalogFeedProvider);
    await Future.wait([
      ref.read(activeStoresProvider.future),
      ref.read(catalogFeedProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final storesAsync = ref.watch(activeStoresProvider);
    final productsAsync = ref.watch(catalogFeedProvider);
    final ordersAsync = ref.watch(consumerOrdersProvider);
    final reservationsAsync = ref.watch(consumerReservationsProvider);

    final activeOrders = (ordersAsync.valueOrNull ?? const []).where((o) => o.status.isActive).toList();
    final activeReservations = (reservationsAsync.valueOrNull ?? const []).where((r) => !r.status.isTerminal).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Hi, ${user?.fullName.split(' ').first ?? 'there'} 👋',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  const NotificationBell(route: '/consumer/notifications'),
                ],
              ),
              const SizedBox(height: 2),
              const Text('What are you looking for today?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => context.push('/consumer/search'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                      SizedBox(width: 10),
                      Text('Search products, brands, categories', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (activeOrders.isNotEmpty || activeReservations.isNotEmpty) ...[
                if (activeOrders.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      TextButton(onPressed: () => context.go('/consumer/orders'), child: const Text('See all')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final o in activeOrders.take(3)) ...[
                    OrderListTile(order: o, onTap: () => context.push('/consumer/order-details/${o.id}')),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                ],
                if (activeReservations.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Reservations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      TextButton(onPressed: () => context.go('/consumer/orders'), child: const Text('See all')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final r in activeReservations.take(3)) ...[
                    ReservationListTile(reservation: r, onTap: () => context.push('/consumer/reservations/${r.id}')),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 14),
              ],
              storesAsync.when(
                loading: () => const _SectionSkeleton(),
                error: (e, _) => const SizedBox.shrink(),
                data: (stores) {
                  final categories = {for (final s in stores) s.category}.toList()..sort();
                  if (categories.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => ActionChip(
                            label: Text(categories[i]),
                            onPressed: () => context.push('/consumer/search?category=${Uri.encodeComponent(categories[i])}'),
                            backgroundColor: AppColors.primarySurface,
                            labelStyle: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Featured Stores', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () => context.go('/consumer/stores'), child: const Text('See all')),
                ],
              ),
              storesAsync.when(
                loading: () => const _SectionSkeleton(),
                error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(activeStoresProvider)),
                data: (stores) {
                  if (stores.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.storefront_outlined,
                      title: 'No stores yet',
                      message: 'Verified merchant stores will appear here once they join Salwana.',
                    );
                  }
                  final featured = stores.take(5).toList();
                  return Column(
                    children: [
                      for (final store in featured) ...[
                        StoreCard(store: store, onTap: () => context.push('/consumer/stores/${store.id}')),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text('Recently Added Products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              productsAsync.when(
                loading: () => const _SectionSkeleton(),
                error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(catalogFeedProvider)),
                data: (products) {
                  if (products.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message: 'Products added by merchants will show up here.',
                    );
                  }
                  final recent = products.take(10).toList();
                  return LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recent.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Breakpoints.gridColumns(constraints.maxWidth),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, i) => ConsumerProductCard(
                        product: recent[i],
                        onTap: () => context.push('/consumer/products/${recent[i].id}'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: LoadingSpinner(),
    );
  }
}
