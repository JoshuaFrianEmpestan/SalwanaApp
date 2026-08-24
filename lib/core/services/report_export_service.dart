import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/merchant/data/report_repository.dart';

/// Turns a [ReportResult] into a real downloadable file (§15). PDF goes
/// through `printing`, which uses the browser's native print/save-as-PDF
/// flow on web and a share sheet on mobile — the same code path works on
/// every platform. Excel is generated as real .xlsx bytes and handed to
/// the OS/browser share sheet.
class ReportExportService {
  Future<void> exportPdf(ReportResult result, {String? subtitle}) async {
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

    final fileName = '${result.title.replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
  }

  Future<void> exportExcel(ReportResult result) async {
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

    final bytes = workbook.encode();
    if (bytes == null) return;

    final fileName = '${result.title.replaceAll(' ', '_')}.xlsx';
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: result.title,
    );
  }
}
