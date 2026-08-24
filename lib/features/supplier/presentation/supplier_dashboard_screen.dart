import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/restock_request_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../merchant/data/restock_repository.dart';

class SupplierDashboardScreen extends ConsumerWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierRestockRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: requestsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(supplierRestockRequestsProvider)),
          data: (requests) {
            final newCount = requests.where((r) => r.status.name == 'requested').length;
            final accepted = requests.where((r) => r.status.name == 'accepted').length;
            final processing = requests.where((r) => r.status.name == 'processing').length;
            final dispatched = requests.where((r) => r.status.name == 'dispatched').length;
            final completed = requests.where((r) => r.status.name == 'received').length;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(supplierRestockRequestsProvider),
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _StatCard(label: 'New Requests', value: newCount, color: AppColors.pending, onTap: () => context.go('/supplier/requests')),
                      _StatCard(label: 'Accepted', value: accepted, color: AppColors.info, onTap: () => context.go('/supplier/requests')),
                      _StatCard(label: 'Processing', value: processing, color: AppColors.info, onTap: () => context.go('/supplier/requests')),
                      _StatCard(label: 'Dispatched', value: dispatched, color: AppColors.success, onTap: () => context.go('/supplier/requests')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('$completed deliveries completed all-time', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  const Text('Recent Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (requests.isEmpty)
                    const EmptyStateView(
                      icon: Icons.assignment_outlined,
                      title: 'No requests yet',
                      message: 'Restocking requests from merchants will appear here.',
                    )
                  else
                    for (final r in requests.take(5)) ...[
                      RestockRequestTile(request: r, onTap: () => context.push('/supplier/requests/${r.id}')),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
