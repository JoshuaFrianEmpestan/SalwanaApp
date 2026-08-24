import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/utils/formatters.dart';
import 'finance_repository.dart';

enum ReportKind { sales, inventory, stockMovement, expenses, profitSummary, loans, consumerCredit, transactions }

extension ReportKindX on ReportKind {
  String get label => switch (this) {
        ReportKind.sales => 'Sales Report',
        ReportKind.inventory => 'Inventory Report',
        ReportKind.stockMovement => 'Stock Movement Report',
        ReportKind.expenses => 'Expense Report',
        ReportKind.profitSummary => 'Profit Summary',
        ReportKind.loans => 'Loan Report',
        ReportKind.consumerCredit => 'Consumer Credit Report',
        ReportKind.transactions => 'Transaction Report',
      };
}

class ReportResult {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String? summaryLine;

  const ReportResult({required this.title, required this.headers, required this.rows, this.summaryLine});
}

/// Generates report data on demand from live Firestore data (§15) — every
/// report type reuses the same collections the rest of the app already
/// writes to, so there is nothing here that could show stale or fake
/// numbers. Rows are plain strings so the same result can feed an
/// on-screen table, a PDF table, or an Excel sheet without duplicating
/// formatting logic per export format.
class ReportRepository {
  final FirebaseFirestore _db;
  ReportRepository(this._db);

  Future<ReportResult> generate(ReportKind kind, String merchantId, DateTime start, DateTime end) {
    return switch (kind) {
      ReportKind.sales => _salesReport(merchantId, start, end),
      ReportKind.inventory => _inventoryReport(merchantId),
      ReportKind.stockMovement => _stockMovementReport(merchantId, start, end),
      ReportKind.expenses => _expenseReport(merchantId, start, end),
      ReportKind.profitSummary => _profitSummaryReport(merchantId, start, end),
      ReportKind.loans => _loanReport(merchantId),
      ReportKind.consumerCredit => _consumerCreditReport(merchantId),
      ReportKind.transactions => _transactionReport(merchantId, start, end),
    };
  }

  Future<ReportResult> _salesReport(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    double total = 0;
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = d['status'] as String? ?? '';
      if (status == 'cancelled' || status == 'paymentFailed' || status == 'pendingPayment') continue;
      final amount = asDouble(d['total']);
      total += amount;
      rows.add([
        AppFormatters.date(tsToDateOrNow(d['createdAt'])),
        d['consumerName'] ?? '',
        status,
        d['paymentMethod'] ?? '',
        AppFormatters.currency(amount),
      ]);
    }
    return ReportResult(
      title: 'Sales Report',
      headers: const ['Date', 'Consumer', 'Status', 'Payment', 'Total'],
      rows: rows,
      summaryLine: 'Total Sales: ${AppFormatters.currency(total)} (${rows.length} orders)',
    );
  }

  Future<ReportResult> _inventoryReport(String merchantId) async {
    final snap = await _db.collection('products').where('merchantId', isEqualTo: merchantId).get();
    double value = 0;
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final current = asInt(d['currentStock']);
      final reserved = asInt(d['reservedStock']);
      final cost = asDouble(d['costPrice']);
      value += current * cost;
      rows.add([
        d['name'] ?? '',
        d['category'] ?? '',
        '$current',
        '${current - reserved}',
        AppFormatters.currency(cost),
        AppFormatters.currency(asDouble(d['sellingPrice'])),
      ]);
    }
    return ReportResult(
      title: 'Inventory Report',
      headers: const ['Product', 'Category', 'Current Stock', 'Available', 'Cost Price', 'Selling Price'],
      rows: rows,
      summaryLine: 'Total Inventory Value (at cost): ${AppFormatters.currency(value)}',
    );
  }

  Future<ReportResult> _stockMovementReport(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('inventory_movements')
        .where('storeId', isEqualTo: merchantId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      rows.add([
        AppFormatters.date(tsToDateOrNow(d['createdAt'])),
        d['type'] ?? '',
        '${d['quantityChanged'] ?? 0}',
        '${d['quantityBefore'] ?? 0} → ${d['quantityAfter'] ?? 0}',
        d['reason'] ?? '',
      ]);
    }
    return ReportResult(
      title: 'Stock Movement Report',
      headers: const ['Date', 'Type', 'Change', 'Before → After', 'Reason'],
      rows: rows,
      summaryLine: '${rows.length} movements',
    );
  }

  Future<ReportResult> _expenseReport(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('expenses')
        .where('merchantId', isEqualTo: merchantId)
        .where('incurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('incurredAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    double total = 0;
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final amount = asDouble(d['amount']);
      total += amount;
      rows.add([AppFormatters.date(tsToDateOrNow(d['incurredAt'])), d['category'] ?? '', d['description'] ?? '', AppFormatters.currency(amount)]);
    }
    return ReportResult(
      title: 'Expense Report',
      headers: const ['Date', 'Category', 'Description', 'Amount'],
      rows: rows,
      summaryLine: 'Total Expenses: ${AppFormatters.currency(total)}',
    );
  }

  Future<ReportResult> _profitSummaryReport(String merchantId, DateTime start, DateTime end) async {
    final summary = await FinanceRepository(_db).computeSummary(merchantId, start, end);
    return ReportResult(
      title: 'Profit Summary',
      headers: const ['Metric', 'Amount'],
      rows: [
        ['Gross Sales', AppFormatters.currency(summary.grossSales)],
        ['Cost of Goods Sold', AppFormatters.currency(summary.costOfGoodsSold)],
        ['Gross Profit', AppFormatters.currency(summary.grossProfit)],
        ['Operating Expenses', AppFormatters.currency(summary.operatingExpenses)],
        ['Net Profit', AppFormatters.currency(summary.netProfit)],
        ['Outstanding Loan Balance', AppFormatters.currency(summary.outstandingLoanBalance)],
        ['Consumer Receivables', AppFormatters.currency(summary.consumerReceivables)],
        ['Total Capital', AppFormatters.currency(summary.totalCapital)],
      ],
      summaryLine: 'These are business-tracking estimates, not professional accounting or lending advice.',
    );
  }

  Future<ReportResult> _loanReport(String merchantId) async {
    final snap = await _db.collection('merchant_loans').where('merchantId', isEqualTo: merchantId).get();
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final principal = asDouble(d['principal']);
      final rate = asDouble(d['interestRate']);
      final paid = asDouble(d['totalPaid']);
      final owed = principal + principal * (rate / 100);
      final remaining = (owed - paid).clamp(0, double.infinity);
      rows.add([
        d['lender'] ?? '',
        AppFormatters.currency(principal),
        AppFormatters.currency(paid),
        AppFormatters.currency(remaining),
        AppFormatters.date(tsToDateOrNow(d['dueDate'])),
      ]);
    }
    return ReportResult(title: 'Loan Report', headers: const ['Lender', 'Principal', 'Paid', 'Remaining', 'Due Date'], rows: rows);
  }

  Future<ReportResult> _consumerCreditReport(String merchantId) async {
    final snap = await _db.collection('consumer_credit_accounts').where('merchantId', isEqualTo: merchantId).get();
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final original = asDouble(d['originalAmount']);
      final paid = asDouble(d['amountPaid']);
      rows.add([
        d['consumerName'] ?? '',
        AppFormatters.currency(original),
        AppFormatters.currency(paid),
        AppFormatters.currency((original - paid).clamp(0, double.infinity)),
        d['status'] ?? '',
      ]);
    }
    return ReportResult(title: 'Consumer Credit Report', headers: const ['Consumer', 'Original', 'Paid', 'Remaining', 'Status'], rows: rows);
  }

  Future<ReportResult> _transactionReport(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('transactions')
        .where('merchantId', isEqualTo: merchantId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final rows = <List<String>>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      rows.add([
        AppFormatters.date(tsToDateOrNow(d['createdAt'])),
        doc.id,
        AppFormatters.currency(asDouble(d['amount'])),
        d['paymentMethod'] ?? '',
        d['reversed'] == true ? 'Reversed' : 'Settled',
      ]);
    }
    return ReportResult(title: 'Transaction Report', headers: const ['Date', 'Order ID', 'Amount', 'Payment', 'Status'], rows: rows);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(firestoreProvider));
});
