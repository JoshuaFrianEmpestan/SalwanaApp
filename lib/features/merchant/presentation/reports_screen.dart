import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/report_export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/report_repository.dart';
import '../data/subscription_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportKind _kind = ReportKind.sales;
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  Future<ReportResult>? _resultFuture;
  bool _exporting = false;

  bool get _needsRange => !{ReportKind.inventory, ReportKind.loans, ReportKind.consumerCredit}.contains(_kind);

  void _generate(String merchantId) {
    setState(() {
      _resultFuture = ref.read(reportRepositoryProvider).generate(_kind, merchantId, _range.start, _range.end.add(const Duration(hours: 23, minutes: 59)));
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 730)), lastDate: DateTime.now(), initialDateRange: _range);
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export(Future<void> Function() action) async {
    setState(() => _exporting = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Export failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final plan = ref.watch(effectivePlanProvider);
    final canExportFiles = plan?.pdfExcelReports ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: user == null
            ? const LoadingSpinner()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Report Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in ReportKind.values)
                        ChoiceChip(
                          label: Text(k.label),
                          selected: _kind == k,
                          onSelected: (_) => setState(() {
                            _kind = k;
                            _resultFuture = null;
                          }),
                        ),
                    ],
                  ),
                  if (_needsRange) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickRange,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date Range'),
                        child: Text('${AppFormatters.date(_range.start)} – ${AppFormatters.date(_range.end)}'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Generate Report', onPressed: () => _generate(user.id)),
                  if (!canExportFiles) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_outlined, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('PDF/Excel export is a Premium feature. Free plan gets on-screen manual reports.', style: TextStyle(fontSize: 11, color: AppColors.warning))),
                          TextButton(onPressed: () => context.push('/merchant/subscription'), child: const Text('Upgrade')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_resultFuture != null)
                    FutureBuilder<ReportResult>(
                      future: _resultFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingSpinner();
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final result = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            if (result.summaryLine != null) ...[
                              const SizedBox(height: 4),
                              Text(result.summaryLine!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 12),
                            if (canExportFiles)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _exporting ? null : () => _export(() => ReportExportService().exportPdf(result)),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                      label: const Text('Export PDF'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _exporting ? null : () => _export(() => ReportExportService().exportExcel(result)),
                                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                                      label: const Text('Export Excel'),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            if (result.rows.isEmpty)
                              const EmptyStateView(icon: Icons.description_outlined, title: 'No data', message: 'Nothing to report for this selection.')
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [for (final h in result.headers) DataColumn(label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))],
                                  rows: [
                                    for (final row in result.rows)
                                      DataRow(cells: [for (final cell in row) DataCell(Text(cell, style: const TextStyle(fontSize: 11)))]),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
