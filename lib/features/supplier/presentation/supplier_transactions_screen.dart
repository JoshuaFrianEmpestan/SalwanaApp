import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/restock_request_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../merchant/data/restock_repository.dart';

/// A supplier's "supply transaction history" (§13 supplier dashboard) —
/// every restocking request that reached Received or Partially Received,
/// i.e. was actually fulfilled and paid for.
class SupplierTransactionsScreen extends ConsumerWidget {
  const SupplierTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierRestockRequestsProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Transactions')),
      body: SafeArea(
        child: requestsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(supplierRestockRequestsProvider)),
          data: (requests) {
            final fulfilled = requests.where((r) => r.status.name == 'received' || r.status.name == 'partiallyReceived').toList();
            if (fulfilled.isEmpty) {
              return const EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'No completed deliveries yet',
                message: 'Fulfilled restocking requests will show up here as your supply transaction history.',
              );
            }
            final total = fulfilled.fold<double>(0, (sum, r) => sum + r.estimatedTotal);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Estimated Value', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(AppFormatters.currency(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in fulfilled) ...[
                  RestockRequestTile(request: r, onTap: () => context.push('/supplier/requests/${r.id}')),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
