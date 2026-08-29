import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_stats_repository.dart';

final _adminStatsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(adminStatsRepositoryProvider).computeStats();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [NotificationBell(route: '/admin/notifications'), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_adminStatsProvider)),
          data: (s) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_adminStatsProvider),
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => GridView.count(
                    crossAxisCount: Breakpoints.gridColumns(constraints.maxWidth),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _StatCard(label: 'Total Users', value: '${s.totalUsers}', color: AppColors.primary, onTap: () => context.go('/admin/users')),
                      _StatCard(
                        label: 'Pending Verifications',
                        value: '${s.pendingVerifications}',
                        color: s.pendingVerifications > 0 ? AppColors.warning : AppColors.success,
                        onTap: () => context.go('/admin/users'),
                      ),
                      _StatCard(label: 'Active Merchants', value: '${s.activeMerchants}', color: AppColors.info),
                      _StatCard(label: 'Active Suppliers', value: '${s.activeSuppliers}', color: AppColors.info),
                      _StatCard(label: 'Total Orders', value: '${s.totalOrders}', color: AppColors.success, onTap: () => context.go('/admin/transactions')),
                      _StatCard(
                        label: 'Reported Reviews',
                        value: '${s.reportedReviews}',
                        color: s.reportedReviews > 0 ? AppColors.error : AppColors.success,
                        onTap: () => context.push('/admin/reports-moderation'),
                      ),
                    ],
                  )),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppFormatters.currency(s.transactionVolume), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                        const SizedBox(height: 4),
                        const Text('Total platform transaction volume (all confirmed sales)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (s.pendingVerifications > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.pendingVerifications} account${s.pendingVerifications == 1 ? '' : 's'} awaiting verification.',
                              style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(onPressed: () => context.go('/admin/users'), child: const Text('Review')),
                        ],
                      ),
                    ),
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
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.color, this.onTap});

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
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
