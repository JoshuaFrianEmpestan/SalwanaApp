import '../core/utils/firestore_helpers.dart';

enum ReportType { sales, inventory, stockMovement, expense, profit, loan, consumerCredit, supplierRestock, transaction, administrative }

extension ReportTypeX on ReportType {
  static ReportType fromName(String name) =>
      ReportType.values.firstWhere((e) => e.name == name, orElse: () => ReportType.sales);
}

enum ReportFormat { pdf, excel }

/// `reports` collection — a record of a generated report and where its
/// exported file lives in Cloud Storage, so past reports can be re-downloaded.
class GeneratedReport {
  final String id;
  final String generatedByUserId;
  final String? storeId;
  final ReportType type;
  final ReportFormat format;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String storageUrl;
  final DateTime createdAt;

  const GeneratedReport({
    required this.id,
    required this.generatedByUserId,
    this.storeId,
    required this.type,
    required this.format,
    required this.rangeStart,
    required this.rangeEnd,
    required this.storageUrl,
    required this.createdAt,
  });

  factory GeneratedReport.fromMap(String id, Map<String, dynamic> map) => GeneratedReport(
        id: id,
        generatedByUserId: map['generatedByUserId'] ?? '',
        storeId: map['storeId'],
        type: ReportTypeX.fromName(map['type'] ?? 'sales'),
        format: (map['format'] ?? 'pdf') == 'excel' ? ReportFormat.excel : ReportFormat.pdf,
        rangeStart: tsToDateOrNow(map['rangeStart']),
        rangeEnd: tsToDateOrNow(map['rangeEnd']),
        storageUrl: map['storageUrl'] ?? '',
        createdAt: tsToDateOrNow(map['createdAt']),
      );
}
