import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/merchant/data/report_repository.dart';

/// One past-generated-report entry (§15) — deliberately not tied to the
/// `GeneratedReport`/`ReportType` model in lib/models/report.dart, since
/// that was drafted before the concrete report kinds below existed;
/// duplicating a handful of display fields here is simpler than forcing
/// three different report-kind enumerations (merchant/admin/model) to agree.
class ReportHistoryEntry {
  final String id;
  final String title;
  final String format;
  final String storageUrl;
  final DateTime createdAt;

  const ReportHistoryEntry({required this.id, required this.title, required this.format, required this.storageUrl, required this.createdAt});

  factory ReportHistoryEntry.fromMap(String id, Map<String, dynamic> map) => ReportHistoryEntry(
        id: id,
        title: map['title'] ?? '',
        format: map['format'] ?? '',
        storageUrl: map['storageUrl'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

/// Turns a [ReportResult] into a real downloadable file (§15). PDF goes
/// through `printing`, which uses the browser's native print/save-as-PDF
/// flow on web and a share sheet on mobile — the same code path works on
/// every platform. Excel is generated as real .xlsx bytes and handed to
/// the OS/browser share sheet. When [generatedByUserId] is supplied, the
/// same bytes are also uploaded to Cloud Storage and logged in the
/// `reports` collection so the report can be found again later.
class ReportExportService {
  Future<void> exportPdf(ReportResult result, {String? subtitle, String? generatedByUserId, String? storeId}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Salwana', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(result.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          if (result.rows.isEmpty)
            pw.Text('No data for this period.', style: const pw.TextStyle(color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headers: result.headers,
              data: result.rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          if (result.summaryLine != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(result.summaryLine!, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = '${result.title.replaceAll(' ', '_')}.pdf';

    if (generatedByUserId != null) {
      await _persist(bytes: bytes, fileName: fileName, format: 'pdf', title: result.title, generatedByUserId: generatedByUserId, storeId: storeId);
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> exportExcel(ReportResult result, {String? generatedByUserId, String? storeId}) async {
    final workbook = xls.Excel.createExcel();
    final sheetName = workbook.getDefaultSheet()!;
    final sheet = workbook[sheetName];

    sheet.appendRow(result.headers.map((h) => xls.TextCellValue(h)).toList());
    for (final row in result.rows) {
      sheet.appendRow(row.map((c) => xls.TextCellValue(c)).toList());
    }
    if (result.summaryLine != null) {
      sheet.appendRow([]);
      sheet.appendRow([xls.TextCellValue(result.summaryLine!)]);
    }

    final encoded = workbook.encode();
    if (encoded == null) return;
    final bytes = Uint8List.fromList(encoded);
    final fileName = '${result.title.replaceAll(' ', '_')}.xlsx';

    if (generatedByUserId != null) {
      await _persist(bytes: bytes, fileName: fileName, format: 'excel', title: result.title, generatedByUserId: generatedByUserId, storeId: storeId);
    }

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: result.title,
    );
  }

  Future<void> _persist({
    required Uint8List bytes,
    required String fileName,
    required String format,
    required String title,
    required String generatedByUserId,
    String? storeId,
  }) async {
    try {
      final path = 'reports/$generatedByUserId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('reports').add({
        'generatedByUserId': generatedByUserId,
        'storeId': storeId,
        'title': title,
        'format': format,
        'storageUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // History is a convenience — never block the actual download/share
      // if the upload fails (e.g. Storage not configured yet).
    }
  }

  Stream<List<ReportHistoryEntry>> watchHistory(String generatedByUserId) {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('generatedByUserId', isEqualTo: generatedByUserId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => ReportHistoryEntry.fromMap(d.id, d.data())).toList());
  }
}
