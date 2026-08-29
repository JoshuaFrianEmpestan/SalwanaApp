import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/report_export_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'confirm_dialog.dart';

final reportHistoryProvider = StreamProvider.family<List<ReportHistoryEntry>, String>((ref, uid) {
  return ReportExportService().watchHistory(uid);
});

/// Past reports a user generated (§15) — each opens the same file that
/// was downloaded/shared at generation time, re-fetched from Cloud
/// Storage rather than regenerated.
class ReportHistoryList extends ConsumerWidget {
  final String userId;
  const ReportHistoryList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(reportHistoryProvider(userId));

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No past reports yet — exported PDF/Excel reports will show up here.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.tryParse(e.storageUrl);
                    if (uri != null) {
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) showAppSnackBar(context, 'Could not open this report.', isError: true);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(e.format == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.table_chart_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Text(AppFormatters.date(e.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
