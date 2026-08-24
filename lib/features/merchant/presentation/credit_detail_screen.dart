import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/credit_status_visuals.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/finance_repository.dart';

class CreditDetailScreen extends ConsumerWidget {
  final String accountId;
  const CreditDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(creditAccountDetailProvider(accountId));
    final paymentsAsync = ref.watch(creditPaymentsProvider(accountId));
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Store Credit')),
      body: SafeArea(
        child: accountAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(creditAccountDetailProvider(accountId))),
          data: (account) {
            if (account == null || appUser == null) {
              return const EmptyStateView(icon: Icons.credit_score_outlined, title: 'Not found', message: '');
            }
            final isMerchant = appUser.role == UserRole.merchant && appUser.id == account.merchantId;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(account.consumerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    StatusBadge(label: account.status.label, tone: creditStatusTone(account.status)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      _row('Original Amount', AppFormatters.currency(account.originalAmount)),
                      _row('Amount Paid', AppFormatters.currency(account.amountPaid)),
                      _row('Due Date', AppFormatters.date(account.dueDate)),
                      if (account.paymentSchedule?.isNotEmpty == true) _row('Schedule', account.paymentSchedule!),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(AppFormatters.currency(account.remainingBalance), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.pending)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (account.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(account.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 16),
                if (isMerchant && account.status != CreditStatus.fullyPaid && account.status != CreditStatus.cancelled)
                  PrimaryButton(label: 'Record Payment', onPressed: () => _showPaymentSheet(context, ref, appUser.id)),
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

  void _showPaymentSheet(BuildContext context, WidgetRef ref, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordCreditPaymentSheet(accountId: accountId, userId: userId),
    );
  }
}

class _RecordCreditPaymentSheet extends ConsumerStatefulWidget {
  final String accountId;
  final String userId;
  const _RecordCreditPaymentSheet({required this.accountId, required this.userId});

  @override
  ConsumerState<_RecordCreditPaymentSheet> createState() => _RecordCreditPaymentSheetState();
}

class _RecordCreditPaymentSheetState extends ConsumerState<_RecordCreditPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).recordCreditPayment(widget.accountId, double.parse(_amount.text.trim()), widget.userId);
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
