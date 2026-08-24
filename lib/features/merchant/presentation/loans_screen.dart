import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/finance_repository.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(merchantLoansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/merchant/finance/loans/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Loan'),
      ),
      body: SafeArea(
        child: loansAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(merchantLoansProvider)),
          data: (loans) {
            if (loans.isEmpty) {
              return EmptyStateView(
                icon: Icons.account_balance_outlined,
                title: 'No loans recorded',
                message: 'Track loan principal, payments, and remaining balance here.',
                actionLabel: 'Add Loan',
                onAction: () => context.push('/merchant/finance/loans/new'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: loans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final l = loans[i];
                return InkWell(
                  onTap: () => context.push('/merchant/finance/loans/${l.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(l.lender, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            StatusBadge(
                              label: l.isCancelled ? 'Cancelled' : (l.isFullyPaid ? 'Fully Paid' : (l.isOverdue ? 'Overdue' : 'Active')),
                              tone: l.isCancelled ? BadgeTone.neutral : (l.isFullyPaid ? BadgeTone.success : (l.isOverdue ? BadgeTone.error : BadgeTone.info)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Principal: ${AppFormatters.currency(l.principal)} · Due ${AppFormatters.date(l.dueDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Remaining: ${AppFormatters.currency(l.remainingBalance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
