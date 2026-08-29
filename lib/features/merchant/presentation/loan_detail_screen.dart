import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
import '../data/finance_repository.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(loanDetailProvider(loanId));
    final paymentsAsync = ref.watch(loanPaymentsProvider(loanId));
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Details')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: loanAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(loanDetailProvider(loanId))),
          data: (loan) {
            if (loan == null) return const EmptyStateView(icon: Icons.account_balance_outlined, title: 'Loan not found', message: '');
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(loan.lender, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      _row('Principal', AppFormatters.currency(loan.principal)),
                      _row('Interest (${loan.interestRate}%)', AppFormatters.currency(loan.interestAmount)),
                      _row('Total Owed', AppFormatters.currency(loan.totalOwed)),
                      _row('Total Paid', AppFormatters.currency(loan.totalPaid)),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(AppFormatters.currency(loan.remainingBalance), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!loan.isFullyPaid && !loan.isCancelled)
                  PrimaryButton(label: 'Record Payment', onPressed: () => _showPaymentSheet(context, ref, user?.id)),
                const SizedBox(height: 20),
                const Text('Payment History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                paymentsAsync.when(
                  loading: () => const LoadingSpinner(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (payments) {
                    if (payments.isEmpty) return const Text('No payments recorded yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                    return Column(
                      children: [
                        for (final p in payments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(AppFormatters.dateTime(p.paidAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                Text(AppFormatters.currency(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _showPaymentSheet(BuildContext context, WidgetRef ref, String? userId) {
    if (userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordPaymentSheet(loanId: loanId, userId: userId),
    );
  }
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final String loanId;
  final String userId;
  const _RecordPaymentSheet({required this.loanId, required this.userId});

  @override
  ConsumerState<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).recordLoanPayment(widget.loanId, double.parse(_amount.text.trim()), widget.userId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not record payment.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppTextField(controller: _amount, label: 'Amount', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Amount')),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save Payment', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
