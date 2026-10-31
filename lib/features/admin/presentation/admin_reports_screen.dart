import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/report_export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/report_history_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../merchant/data/report_repository.dart';
import '../data/admin_repository.dart';

enum _AdminReportKind { transactions, users, reportedReviews }

extension on _AdminReportKind {
  String get label => switch (this) {
        _AdminReportKind.transactions => 'Platform Transactions',
        _AdminReportKind.users => 'User Accounts',
        _AdminReportKind.reportedReviews => 'Reported Reviews',
      };
}

/// Administrative reports (§15, §4 "generate PDF and Excel reports"),
/// scoped platform-wide rather than to one merchant — reuses the same
/// export pipeline as the merchant Reports screen (module 15).
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  _AdminReportKind _kind = _AdminReportKind.transactions;
  bool _exporting = false;

  ReportResult? _buildResult() {
    switch (_kind) {
      case _AdminReportKind.transactions:
        final orders = ref.watch(allOrdersProvider).valueOrNull;
        if (orders == null) return null;
        return ReportResult(
          title: 'Platform Transactions',
          headers: const ['Date', 'Store', 'Consumer', 'Status', 'Total'],
          rows: [for (final o in orders) [AppFormatters.date(o.createdAt), o.storeName, o.consumerName, o.status.label, AppFormatters.currency(o.total)]],
          summaryLine: '${orders.length} orders (most recent 200)',
        );
      case _AdminReportKind.users:
        final users = ref.watch(allUsersProvider).valueOrNull;
        if (users == null) return null;
        return ReportResult(
          title: 'User Accounts',
          headers: const ['Name', 'Email', 'Role', 'Status', 'Joined'],
          rows: [for (final u in users) [u.fullName, u.email, u.role.label, u.status.label, AppFormatters.date(u.createdAt)]],
          summaryLine: '${users.length} total users',
        );
      case _AdminReportKind.reportedReviews:
        final reviews = ref.watch(reportedReviewsProvider).valueOrNull;
        if (reviews == null) return null;
        return ReportResult(
          title: 'Reported Reviews',
          headers: const ['Date', 'Consumer', 'Rating', 'Reason', 'Hidden'],
          rows: [for (final r in reviews) [AppFormatters.date(r.createdAt), r.consumerName, '${r.rating}', r.reportReason ?? '', r.hidden ? 'Yes' : 'No']],
          summaryLine: '${reviews.length} reported reviews',
        );
    }
  }

  Future<void> _export(Future<void> Function() action) async {
    setState(() => _exporting = true);
    try {
      await action();
      if (mounted) showAppSnackBar(context, 'Export complete � check your downloads.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _buildResult();
    final admin = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in _AdminReportKind.values)
                  ChoiceChip(label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
              ],
            ),
            const SizedBox(height: 20),
            if (result == null)
              const LoadingSpinner()
            else ...[
              Text(result.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (result.summaryLine != null) ...[
                const SizedBox(height: 4),
                Text(result.summaryLine!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting || admin == null ? null : () => _export(() => ReportExportService().exportPdf(result, generatedByUserId: admin.id)),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting || admin == null ? null : () => _export(() => ReportExportService().exportExcel(result, generatedByUserId: admin.id)),
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Export Excel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (result.rows.isEmpty)
                const EmptyStateView(icon: Icons.description_outlined, title: 'No data', message: 'Nothing to report yet.')
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [for (final h in result.headers) DataColumn(label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))],
                    rows: [
                      for (final row in result.rows) DataRow(cells: [for (final cell in row) DataCell(Text(cell, style: const TextStyle(fontSize: 11)))]),
                    ],
                  ),
                ),
            ],
            if (admin != null) ...[
              const SizedBox(height: 24),
              const Text('Report History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ReportHistoryList(userId: admin.id),
            ],
          ],
        ),
      ),
    );
  }
}
