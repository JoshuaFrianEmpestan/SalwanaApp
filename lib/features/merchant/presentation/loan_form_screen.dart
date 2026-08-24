import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/finance_repository.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  const LoanFormScreen({super.key});

  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lender = TextEditingController();
  final _principal = TextEditingController();
  final _interestRate = TextEditingController(text: '0');
  final _notes = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 90));
  bool _saving = false;

  Future<void> _save(String merchantId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addLoan(
            merchantId: merchantId,
            storeId: merchantId,
            lender: _lender.text.trim(),
            principal: double.parse(_principal.text.trim()),
            interestRate: double.tryParse(_interestRate.text.trim()) ?? 0,
            dueDate: _dueDate,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) {
        showAppSnackBar(context, 'Loan recorded.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save loan.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Loan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(controller: _lender, label: 'Lender', validator: (v) => Validators.required(v, field: 'Lender')),
                const SizedBox(height: 14),
                AppTextField(controller: _principal, label: 'Loan Principal', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Principal')),
                const SizedBox(height: 14),
                AppTextField(controller: _interestRate, label: 'Interest Rate (%, flat over term)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.nonNegativeNumber(v, field: 'Interest rate')),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due Date'),
                    child: Text(AppFormatters.date(_dueDate)),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save Loan', onPressed: user == null ? null : () => _save(user.id), loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
