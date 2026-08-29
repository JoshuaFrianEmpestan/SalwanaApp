import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
import '../../consumer/data/order_repository.dart';
import '../data/finance_repository.dart';

class CreditFormScreen extends ConsumerStatefulWidget {
  const CreditFormScreen({super.key});

  @override
  ConsumerState<CreditFormScreen> createState() => _CreditFormScreenState();
}

class _CreditFormScreenState extends ConsumerState<CreditFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _paymentSchedule = TextEditingController();
  final _notes = TextEditingController();
  String? _consumerId;
  String? _consumerName;
  String? _relatedOrderId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  Future<void> _save(String merchantId) async {
    if (_consumerId == null) {
      showAppSnackBar(context, 'Select a consumer.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addCreditAccount(
            merchantId: merchantId,
            storeId: merchantId,
            consumerId: _consumerId!,
            consumerName: _consumerName!,
            relatedOrderId: _relatedOrderId,
            originalAmount: double.parse(_amount.text.trim()),
            dueDate: _dueDate,
            paymentSchedule: _paymentSchedule.text.trim().isEmpty ? null : _paymentSchedule.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) {
        showAppSnackBar(context, 'Credit account created.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save credit account.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final ordersAsync = ref.watch(merchantOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Store Credit')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'This is record-tracking for a merchant-approved credit arrangement — not a loan offer.',
                    style: TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Consumer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ordersAsync.when(
                  loading: () => const LoadingSpinner(),
                  error: (e, _) => const Text('Could not load consumers.'),
                  data: (orders) {
                    final seen = <String>{};
                    final consumers = <(String, String)>[];
                    for (final o in orders) {
                      if (seen.add(o.consumerId)) consumers.add((o.consumerId, o.consumerName));
                    }
                    if (consumers.isEmpty) {
                      return const Text('No past consumers yet — a consumer must have ordered from your store first.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _consumerId,
                      items: [
                        for (final c in consumers) DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                      ],
                      onChanged: (v) => setState(() {
                        _consumerId = v;
                        _consumerName = consumers.firstWhere((c) => c.$1 == v).$2;
                      }),
                      decoration: const InputDecoration(labelText: 'Select consumer'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(controller: _amount, label: 'Original Amount', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Amount')),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Due Date'), child: Text(AppFormatters.date(_dueDate))),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _paymentSchedule, label: 'Payment Schedule (optional)', hint: 'e.g. Weekly, ₱500/month'),
                const SizedBox(height: 14),
                AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save', onPressed: user == null ? null : () => _save(user.id), loading: _saving),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
