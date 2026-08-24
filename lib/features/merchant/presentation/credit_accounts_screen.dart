import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/credit_status_visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/consumer_credit.dart';
import '../data/finance_repository.dart';

class CreditAccountsScreen extends ConsumerWidget {
  const CreditAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(merchantCreditProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Credit')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/merchant/finance/credit/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Credit'),
      ),
      body: SafeArea(
        child: creditAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(merchantCreditProvider)),
          data: (accounts) {
            if (accounts.isEmpty) {
              return EmptyStateView(
                icon: Icons.credit_score_outlined,
                title: 'No store credit recorded',
                message: 'Record merchant-approved credit arrangements for consumers here. This is tracking only — Salwana is not a lender.',
                actionLabel: 'New Credit',
                onAction: () => context.push('/merchant/finance/credit/new'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CreditTile(account: accounts[i], onTap: () => context.push('/merchant/finance/credit/${accounts[i].id}')),
            );
          },
        ),
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  final ConsumerCreditAccount account;
  final VoidCallback onTap;
  const _CreditTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(account.consumerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                StatusBadge(label: account.status.label, tone: creditStatusTone(account.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Original: ${AppFormatters.currency(account.originalAmount)} · Due ${AppFormatters.date(account.dueDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Remaining: ${AppFormatters.currency(account.remainingBalance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.pending)),
          ],
        ),
      ),
    );
  }
}
