import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/subscription.dart';
import '../../merchant/data/subscription_repository.dart';

/// Admin-configurable plan limits (§14: "the exact limitations must be
/// manageable by the administrator").
class AdminSubscriptionPlansScreen extends ConsumerWidget {
  const AdminSubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Plans')),
      body: SafeArea(
        child: plansAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(subscriptionPlansProvider)),
          data: (plans) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final plan in plans) ...[
                  _PlanEditor(plan: plan),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanEditor extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;
  const _PlanEditor({required this.plan});

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  late final TextEditingController _productLimit = TextEditingController(text: '${widget.plan.productLimit}');
  late final TextEditingController _monthlyPrice = TextEditingController(text: '${widget.plan.monthlyPrice}');
  late final TextEditingController _historyDays = TextEditingController(text: '${widget.plan.transactionHistoryDays}');
  late bool _advancedAnalytics = widget.plan.advancedAnalytics;
  late bool _pdfExcelReports = widget.plan.pdfExcelReports;
  late bool _lowStockAutomation = widget.plan.lowStockAutomation;
  late bool _supplierManagement = widget.plan.supplierManagement;
  late bool _barcodeFeatures = widget.plan.barcodeFeatures;
  late bool _prioritySupport = widget.plan.prioritySupport;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(subscriptionRepositoryProvider).updatePlan(widget.plan.id, {
        'productLimit': int.tryParse(_productLimit.text.trim()) ?? widget.plan.productLimit,
        'monthlyPrice': double.tryParse(_monthlyPrice.text.trim()) ?? widget.plan.monthlyPrice,
        'transactionHistoryDays': int.tryParse(_historyDays.text.trim()) ?? widget.plan.transactionHistoryDays,
        'advancedAnalytics': _advancedAnalytics,
        'pdfExcelReports': _pdfExcelReports,
        'lowStockAutomation': _lowStockAutomation,
        'supplierManagement': _supplierManagement,
        'barcodeFeatures': _barcodeFeatures,
        'prioritySupport': _prioritySupport,
      });
      if (mounted) showAppSnackBar(context, '${widget.plan.name} plan updated.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save changes.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.plan.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _productLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Product Limit (-1 = unlimited)', isDense: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _monthlyPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly Price', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _historyDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Transaction History (days, -1 = unlimited)', isDense: true),
          ),
          const SizedBox(height: 6),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Advanced Analytics', style: TextStyle(fontSize: 13)), value: _advancedAnalytics, onChanged: (v) => setState(() => _advancedAnalytics = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('PDF & Excel Reports', style: TextStyle(fontSize: 13)), value: _pdfExcelReports, onChanged: (v) => setState(() => _pdfExcelReports = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Low-Stock Automation', style: TextStyle(fontSize: 13)), value: _lowStockAutomation, onChanged: (v) => setState(() => _lowStockAutomation = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Supplier Management', style: TextStyle(fontSize: 13)), value: _supplierManagement, onChanged: (v) => setState(() => _supplierManagement = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Barcode / QR Features', style: TextStyle(fontSize: 13)), value: _barcodeFeatures, onChanged: (v) => setState(() => _barcodeFeatures = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Priority Support', style: TextStyle(fontSize: 13)), value: _prioritySupport, onChanged: (v) => setState(() => _prioritySupport = v)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
