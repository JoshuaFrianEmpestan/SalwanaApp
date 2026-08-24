import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/order_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/order.dart' as model;
import '../../consumer/data/order_repository.dart';
import '../../consumer/data/reservation_repository.dart';
import '../data/finance_repository.dart';
import '../data/product_repository.dart';

class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends ConsumerState<MerchantDashboardScreen> {
  Future<FinanceSummary>? _summaryFuture;
  Future<List<(DateTime, double)>>? _chartFuture;
  String? _lastMerchantId;

  void _load(String merchantId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    setState(() {
      _summaryFuture = ref.read(financeRepositoryProvider).computeSummary(merchantId, todayStart, now);
      _chartFuture = ref.read(financeRepositoryProvider).salesChartData(merchantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());
    if (_lastMerchantId != user.id) {
      _lastMerchantId = user.id;
      _load(user.id);
    }

    final productsAsync = ref.watch(storeProductsProvider(user.id));
    final ordersAsync = ref.watch(merchantOrdersProvider);
    final reservationsAsync = ref.watch(merchantReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [NotificationBell(route: '/merchant/notifications'), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _load(user.id),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<FinanceSummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingSpinner());
                  final s = snapshot.data!;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Sales Today', value: AppFormatters.currency(s.grossSales), color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Net Profit Today', value: AppFormatters.currency(s.netProfit), color: AppColors.info)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Outstanding Loans',
                              value: AppFormatters.currency(s.outstandingLoanBalance),
                              color: AppColors.error,
                              onTap: () => context.push('/merchant/finance/loans'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              label: 'Receivables',
                              value: AppFormatters.currency(s.consumerReceivables),
                              color: AppColors.pending,
                              onTap: () => context.push('/merchant/finance/credit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              productsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (products) {
                  final lowStock = products.where((p) => p.status == ProductStatus.active && p.isLowStock).length;
                  final inventoryValue = products.fold<double>(0, (sum, p) => sum + p.currentStock * p.costPrice);
                  final pendingReservations = reservationsAsync.valueOrNull?.where((r) => r.status.name == 'pending').length ?? 0;
                  final totalOrders = ordersAsync.valueOrNull?.length ?? 0;

                  return Row(
                    children: [
                      Expanded(child: _MiniStat(label: 'Total Orders', value: '$totalOrders', onTap: () => context.go('/merchant/orders'))),
                      Expanded(child: _MiniStat(label: 'Pending Reservations', value: '$pendingReservations', onTap: () => context.go('/merchant/orders'))),
                      Expanded(child: _MiniStat(label: 'Low Stock', value: '$lowStock', warn: lowStock > 0, onTap: () => context.go('/merchant/inventory'))),
                      Expanded(child: _MiniStat(label: 'Inventory Value', value: AppFormatters.currency(inventoryValue), onTap: () => context.go('/merchant/inventory'))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('Sales — Last 7 Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: FutureBuilder<List<(DateTime, double)>>(
                  future: _chartFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LoadingSpinner();
                    final data = snapshot.data!;
                    final maxVal = data.map((e) => e.$2).fold<double>(0, (a, b) => b > a ? b : a);
                    return BarChart(
                      BarChartData(
                        maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_weekdayLabel(data[idx].$1), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < data.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(toY: data[i].$2, color: AppColors.primary, width: 18, borderRadius: BorderRadius.circular(4)),
                            ]),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ordersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (orders) => _BestSellers(orders: orders),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () => context.go('/merchant/orders'), child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              ordersAsync.when(
                loading: () => const LoadingSpinner(),
                error: (e, _) => const SizedBox.shrink(),
                data: (orders) {
                  if (orders.isEmpty) {
                    return const EmptyStateView(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Orders from consumers will appear here.');
                  }
                  return Column(
                    children: [
                      for (final o in orders.take(5)) ...[
                        OrderListTile(order: o, showConsumerName: true, onTap: () => context.push('/merchant/order-details/${o.id}')),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickAction(icon: Icons.add_box_outlined, label: 'Add Product', onTap: () => context.push('/merchant/products/new')),
                  _QuickAction(icon: Icons.tune_rounded, label: 'Stock In', onTap: () => context.go('/merchant/inventory')),
                  _QuickAction(icon: Icons.receipt_long_outlined, label: 'Record Expense', onTap: () => context.push('/merchant/finance/expenses')),
                  _QuickAction(icon: Icons.local_shipping_outlined, label: 'Restock Request', onTap: () => context.push('/merchant/suppliers')),
                  _QuickAction(icon: Icons.list_alt_rounded, label: 'View Orders', onTap: () => context.go('/merchant/orders')),
                  _QuickAction(icon: Icons.bar_chart_rounded, label: 'Generate Report', onTap: () => context.push('/merchant/reports')),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
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
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  final VoidCallback onTap;
  const _MiniStat({required this.label, required this.value, this.warn = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: warn ? AppColors.error : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BestSellers extends StatelessWidget {
  final List<model.Order> orders;
  const _BestSellers({required this.orders});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final o in orders) {
      if (o.status == OrderStatus.cancelled || o.status == OrderStatus.paymentFailed) continue;
      for (final item in o.items) {
        counts[item.productName] = (counts[item.productName] ?? 0) + item.quantity;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.take(3).toList();
    final least = sorted.reversed.take(3).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _RankList(title: 'Best Selling', entries: best)),
        const SizedBox(width: 12),
        Expanded(child: _RankList(title: 'Least Selling', entries: least)),
      ],
    );
  }
}

class _RankList extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> entries;
  const _RankList({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
