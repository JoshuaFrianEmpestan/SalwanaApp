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

class CapitalScreen extends ConsumerWidget {
  const CapitalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capitalAsync = ref.watch(merchantCapitalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Capital')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _AddCapitalSheet()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Capital'),
      ),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: capitalAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(merchantCapitalProvider)),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyStateView(
                icon: Icons.savings_outlined,
                title: 'No capital recorded',
                message: 'Record your initial and additional capital investments here.',
              );
            }
            final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Capital', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(AppFormatters.currency(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in entries)
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
                              Text(e.source, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text('${e.isInitial ? "Initial Capital" : "Additional Capital"} · ${AppFormatters.date(e.recordedAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(AppFormatters.currency(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
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
}

class _AddCapitalSheet extends ConsumerStatefulWidget {
  const _AddCapitalSheet();

  @override
  ConsumerState<_AddCapitalSheet> createState() => _AddCapitalSheetState();
}

class _AddCapitalSheetState extends ConsumerState<_AddCapitalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _source = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _isInitial = false;
  bool _saving = false;

  Future<void> _save(String merchantId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addCapital(
            merchantId: merchantId,
            storeId: merchantId,
            isInitial: _isInitial,
            amount: double.parse(_amount.text.trim()),
            source: _source.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save entry.', isError: true);
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
            const Text('Add Capital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ChoiceChip(label: const Text('Additional'), selected: !_isInitial, onSelected: (_) => setState(() => _isInitial = false))),
                const SizedBox(width: 8),
                Expanded(child: ChoiceChip(label: const Text('Initial'), selected: _isInitial, onSelected: (_) => setState(() => _isInitial = true))),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _source, label: 'Source', hint: 'e.g. Personal savings, Investor', validator: (v) => Validators.required(v, field: 'Source')),
            const SizedBox(height: 14),
            AppTextField(controller: _amount, label: 'Amount', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Amount')),
            const SizedBox(height: 14),
            AppTextField(controller: _notes, label: 'Notes (optional)'),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save', onPressed: user == null ? null : () => _save(user.id), loading: _saving),
          ],
        ),
      ),
    );
  }
}
