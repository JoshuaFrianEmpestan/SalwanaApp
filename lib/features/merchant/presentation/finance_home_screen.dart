import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/finance_repository.dart';

enum _Period { today, week, month, custom }

class FinanceHomeScreen extends ConsumerStatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  ConsumerState<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends ConsumerState<FinanceHomeScreen> {
  _Period _period = _Period.today;
  DateTimeRange? _customRange;
  FinanceSummary? _summary;
  bool _loading = false;
  Object? _error;
  String? _lastMerchantId;

  (DateTime, DateTime) _rangeFor(_Period period) {
    final now = DateTime.now();
    switch (period) {
      case _Period.today:
        return (DateTime(now.year, now.month, now.day), now);
      case _Period.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(start.year, start.month, start.day), now);
      case _Period.month:
        return (DateTime(now.year, now.month, 1), now);
      case _Period.custom:
        if (_customRange == null) return (DateTime(now.year, now.month, now.day), now);
        return (_customRange!.start, _customRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
    }
  }

  Future<void> _load(String merchantId) async {
    final (start, end) = _rangeFor(_period);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ref.read(financeRepositoryProvider).computeSummary(merchantId, start, end);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickCustomRange(String merchantId) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = _Period.custom;
      });
      _load(merchantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());

    if (_lastMerchantId != user.id) {
      _lastMerchantId = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(user.id);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _load(user.id),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _PeriodChip(label: 'Today', selected: _period == _Period.today, onTap: () { setState(() => _period = _Period.today); _load(user.id); }),
                    const SizedBox(width: 8),
                    _PeriodChip(label: 'This Week', selected: _period == _Period.week, onTap: () { setState(() => _period = _Period.week); _load(user.id); }),
                    const SizedBox(width: 8),
                    _PeriodChip(label: 'This Month', selected: _period == _Period.month, onTap: () { setState(() => _period = _Period.month); _load(user.id); }),
                    const SizedBox(width: 8),
                    _PeriodChip(label: 'Custom Range', selected: _period == _Period.custom, onTap: () => _pickCustomRange(user.id)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Builder(builder: (context) {
                if (_loading && _summary == null) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingSpinner());
                }
              if (_error != null && _summary == null) {
                return ErrorStateView(onRetry: () => _load(user.id));
              }
              if (_summary == null) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingSpinner());
              }
              final s = _summary!;
              return Column(
                children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Gross Sales', value: s.grossSales, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Cost of Goods Sold', value: s.costOfGoodsSold, color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Gross Profit', value: s.grossProfit, color: AppColors.info)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Operating Expenses', value: s.operatingExpenses, color: AppColors.error)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatCard(label: 'Net Profit', value: s.netProfit, color: AppColors.primaryDark, large: true),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Outstanding Loan Balance', value: s.outstandingLoanBalance, color: AppColors.error, onTap: () => context.push('/merchant/finance/loans'))),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Consumer Receivables', value: s.consumerReceivables, color: AppColors.pending, onTap: () => context.push('/merchant/finance/credit'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatCard(label: 'Total Capital Invested', value: s.totalCapital, color: AppColors.success, onTap: () => context.push('/merchant/finance/capital')),
                    ],
                  );
              }),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'These figures are business-tracking estimates based on your recorded transactions and expenses — not professional accounting or lending advice.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ActionChip(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => context.push('/merchant/finance/expenses')),
                  _ActionChip(icon: Icons.savings_outlined, label: 'Capital', onTap: () => context.push('/merchant/finance/capital')),
                  _ActionChip(icon: Icons.account_balance_outlined, label: 'Loans', onTap: () => context.push('/merchant/finance/loans')),
                  _ActionChip(icon: Icons.credit_score_outlined, label: 'Store Credit', onTap: () => context.push('/merchant/finance/credit')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.color, this.large = false, this.onTap});

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
            Text(AppFormatters.currency(value), style: TextStyle(fontSize: large ? 22 : 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

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
