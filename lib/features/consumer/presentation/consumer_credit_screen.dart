import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/credit_status_visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../merchant/data/finance_repository.dart';

/// A consumer's own store-credit balances — read only, and only their own
/// (§8, §21). Recording payments is a merchant-side action.
class ConsumerCreditScreen extends ConsumerWidget {
  const ConsumerCreditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(consumerOwnCreditProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Credit')),
      body: SafeArea(
        child: creditAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(consumerOwnCreditProvider)),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const EmptyStateView(
                icon: Icons.credit_score_outlined,
                title: 'No store credit',
                message: 'Credit arrangements a merchant records for you will appear here. This is tracking only — not a loan offer.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = accounts[i];
                return InkWell(
                  onTap: () => context.push('/consumer/credit/${a.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Store Credit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            StatusBadge(label: a.status.label, tone: creditStatusTone(a.status)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Original: ${AppFormatters.currency(a.originalAmount)} · Due ${AppFormatters.date(a.dueDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Remaining: ${AppFormatters.currency(a.remainingBalance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.pending)),
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
