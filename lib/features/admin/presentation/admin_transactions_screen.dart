import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';

/// Platform-wide order monitoring (§4 "monitor... orders... transactions").
/// Read-only for admin — OrderDetailScreen shows no action buttons when
/// the viewer is neither the order's consumer nor its merchant.
class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: SafeArea(
        child: ordersAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(allOrdersProvider)),
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyStateView(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Orders placed across the platform will appear here.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => OrderListTile(
                order: orders[i],
                showConsumerName: true,
                onTap: () => context.push('/admin/order-details/${orders[i].id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
