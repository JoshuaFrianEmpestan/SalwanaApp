import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/subscription.dart';
import '../data/subscription_repository.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _upgrading = false;

  Future<void> _upgrade() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Upgrade to Premium',
      message: 'This is a simulated purchase (₱499/month) — no real payment is made. Your Premium access will run for 30 days.',
      confirmLabel: 'Simulate Purchase',
    );
    if (!confirmed) return;
    setState(() => _upgrading = true);
    try {
      await ref.read(subscriptionRepositoryProvider).subscribeToPremium();
      if (mounted) showAppSnackBar(context, 'Premium activated!');
    } on SubscriptionException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not activate Premium.', isError: true);
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: plansAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(subscriptionPlansProvider)),
          data: (plans) {
            final free = plans.firstWhere((p) => p.tier == SubscriptionPlanTier.free, orElse: () => plans.first);
            final premium = plans.firstWhere((p) => p.tier == SubscriptionPlanTier.premium, orElse: () => plans.first);
            final subscription = subscriptionAsync.valueOrNull;
            final isPremiumActive = subscription?.isActive ?? false;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPremiumActive ? AppColors.primarySurface : AppColors.neutralBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(isPremiumActive ? Icons.workspace_premium_rounded : Icons.storefront_outlined,
                          color: isPremiumActive ? AppColors.primary : AppColors.textSecondary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPremiumActive ? 'Premium Plan' : 'Free Plan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            if (isPremiumActive && subscription != null)
                              Text('Active until ${AppFormatters.date(subscription.expiresAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                            else
                              const Text('Upgrade for unlimited products & advanced tools', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (subscription != null && subscription.tier == SubscriptionPlanTier.premium && !isPremiumActive) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Premium subscription has expired. Your data is safe — renew to regain premium features.',
                            style: TextStyle(fontSize: 12, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _PlanCard(plan: free, isCurrent: !isPremiumActive)),
                    const SizedBox(width: 12),
                    Expanded(child: _PlanCard(plan: premium, isCurrent: isPremiumActive, highlight: true)),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isPremiumActive) PrimaryButton(label: 'Upgrade to Premium', onPressed: _upgrade, loading: _upgrading),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Simulated billing for demo purposes — no real payment gateway is connected. Expiring Premium never deletes your store data; only premium-only actions are restricted.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool highlight;
  const _PlanCard({required this.plan, required this.isCurrent, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final features = <String>[
      plan.productLimit < 0 ? 'Unlimited products' : 'Up to ${plan.productLimit} products',
      if (plan.advancedAnalytics) 'Advanced analytics',
      if (plan.pdfExcelReports) 'PDF & Excel reports' else 'Manual reports',
      if (plan.lowStockAutomation) 'Low-stock automation',
      if (plan.supplierManagement) 'Supplier management',
      if (plan.barcodeFeatures) 'Barcode / QR features',
      plan.transactionHistoryDays < 0 ? 'Unlimited transaction history' : '${plan.transactionHistoryDays}-day transaction history',
      if (plan.prioritySupport) 'Priority support',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: isCurrent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Current', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(plan.monthlyPrice > 0 ? '${AppFormatters.currency(plan.monthlyPrice)}/mo' : 'Free', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 11))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
