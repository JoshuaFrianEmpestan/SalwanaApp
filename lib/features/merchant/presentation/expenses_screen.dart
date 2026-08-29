import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
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

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(merchantExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Expense'),
      ),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: expensesAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(merchantExpensesProvider)),
          data: (expenses) {
            if (expenses.isEmpty) {
              return EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses recorded',
                message: 'Track rent, utilities, salaries, and other operating costs here.',
                actionLabel: 'Record Expense',
                onAction: () => _showAddExpenseSheet(context, ref),
              );
            }
            final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Recorded', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(AppFormatters.currency(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.error)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in expenses)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text('${e.category.label} · ${AppFormatters.date(e.incurredAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(AppFormatters.currency(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddExpenseSheet(),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.other;
  DateTime _incurredAt = DateTime.now();
  bool _saving = false;

  Future<void> _save(String merchantId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addExpense(
            merchantId: merchantId,
            storeId: merchantId,
            category: _category,
            description: _description.text.trim(),
            amount: double.parse(_amount.text.trim()),
            incurredAt: _incurredAt,
            recordedByUserId: merchantId,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save expense.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _description, label: 'Description', validator: (v) => Validators.required(v, field: 'Description')),
            const SizedBox(height: 14),
            AppTextField(controller: _amount, label: 'Amount', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Amount')),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _incurredAt, firstDate: DateTime.now().subtract(const Duration(days: 730)), lastDate: DateTime.now());
                if (picked != null) setState(() => _incurredAt = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date Incurred'),
                child: Text(AppFormatters.date(_incurredAt)),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save Expense', onPressed: user == null ? null : () => _save(user.id), loading: _saving),
          ],
        ),
      ),
    );
  }
}
