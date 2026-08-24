import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../models/capital_entry.dart';
import '../../../models/consumer_credit.dart';
import '../../../models/expense.dart';
import '../../../models/merchant_loan.dart';
import '../../../models/transaction_record.dart';

/// Computed once per period selection (§7) — never persisted, always
/// derived live from `transactions` (settled sales, never-cancelled) and
/// `expenses`, plus point-in-time loan/receivable/capital balances.
class FinanceSummary {
  final double grossSales;
  final double costOfGoodsSold;
  final double operatingExpenses;
  final double outstandingLoanBalance;
  final double consumerReceivables;
  final double totalCapital;

  const FinanceSummary({
    required this.grossSales,
    required this.costOfGoodsSold,
    required this.operatingExpenses,
    required this.outstandingLoanBalance,
    required this.consumerReceivables,
    required this.totalCapital,
  });

  double get grossProfit => grossSales - costOfGoodsSold;
  double get netProfit => grossProfit - operatingExpenses;
}

class FinanceRepository {
  final FirebaseFirestore _db;
  FinanceRepository(this._db);

  /// Gross sales / COGS for the given period — filtered to non-reversed
  /// transactions only, so cancelled/refunded orders are never counted
  /// as completed sales (§7).
  Future<(double grossSales, double cogs)> _salesInRange(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('transactions')
        .where('merchantId', isEqualTo: merchantId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    double sales = 0;
    double cogs = 0;
    for (final doc in snap.docs) {
      final t = TransactionRecord.fromMap(doc.id, doc.data());
      if (t.reversed) continue;
      sales += t.amount;
      cogs += t.cogs;
    }
    return (sales, cogs);
  }

  Future<double> _expensesInRange(String merchantId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection('expenses')
        .where('merchantId', isEqualTo: merchantId)
        .where('incurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('incurredAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snap.docs.fold<double>(0, (total, d) => total + asDouble(d.data()['amount']));
  }

  Future<double> _outstandingLoanBalance(String merchantId) async {
    final snap = await _db.collection('merchant_loans').where('merchantId', isEqualTo: merchantId).get();
    double total = 0;
    for (final doc in snap.docs) {
      final loan = MerchantLoan.fromMap(doc.id, doc.data());
      if (!loan.isCancelled) total += loan.remainingBalance;
    }
    return total;
  }

  Future<double> _consumerReceivables(String merchantId) async {
    final snap = await _db.collection('consumer_credit_accounts').where('merchantId', isEqualTo: merchantId).get();
    double total = 0;
    for (final doc in snap.docs) {
      final credit = ConsumerCreditAccount.fromMap(doc.id, doc.data());
      if (credit.status != CreditStatus.cancelled) total += credit.remainingBalance;
    }
    return total;
  }

  Future<double> _totalCapital(String merchantId) async {
    final snap = await _db.collection('capital_entries').where('merchantId', isEqualTo: merchantId).get();
    return snap.docs.fold<double>(0, (total, d) => total + asDouble(d.data()['amount']));
  }

  Future<FinanceSummary> computeSummary(String merchantId, DateTime start, DateTime end) async {
    final results = await Future.wait([
      _salesInRange(merchantId, start, end),
      _expensesInRange(merchantId, start, end),
      _outstandingLoanBalance(merchantId),
      _consumerReceivables(merchantId),
      _totalCapital(merchantId),
    ]);
    final sales = results[0] as (double, double);
    return FinanceSummary(
      grossSales: sales.$1,
      costOfGoodsSold: sales.$2,
      operatingExpenses: results[1] as double,
      outstandingLoanBalance: results[2] as double,
      consumerReceivables: results[3] as double,
      totalCapital: results[4] as double,
    );
  }

  // ---------------- Expenses ----------------
  Stream<List<Expense>> watchExpenses(String merchantId) {
    return _db
        .collection('expenses')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('incurredAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  Future<void> addExpense({
    required String merchantId,
    required String storeId,
    required ExpenseCategory category,
    required String description,
    required double amount,
    required DateTime incurredAt,
    required String recordedByUserId,
  }) async {
    await _db.collection('expenses').add({
      'merchantId': merchantId,
      'storeId': storeId,
      'category': category.name,
      'description': description,
      'amount': amount,
      'incurredAt': Timestamp.fromDate(incurredAt),
      'recordedByUserId': recordedByUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- Capital ----------------
  Stream<List<CapitalEntry>> watchCapital(String merchantId) {
    return _db
        .collection('capital_entries')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CapitalEntry.fromMap(d.id, d.data())).toList());
  }

  Future<void> addCapital({
    required String merchantId,
    required String storeId,
    required bool isInitial,
    required double amount,
    required String source,
    String? notes,
  }) async {
    await _db.collection('capital_entries').add({
      'merchantId': merchantId,
      'storeId': storeId,
      'isInitial': isInitial,
      'amount': amount,
      'source': source,
      'notes': notes,
      'recordedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- Loans ----------------
  Stream<List<MerchantLoan>> watchLoans(String merchantId) {
    return _db
        .collection('merchant_loans')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MerchantLoan.fromMap(d.id, d.data())).toList());
  }

  Stream<MerchantLoan?> watchLoan(String id) {
    return _db.collection('merchant_loans').doc(id).snapshots().map((d) => d.exists ? MerchantLoan.fromMap(d.id, d.data()!) : null);
  }

  Stream<List<MerchantLoanPayment>> watchLoanPayments(String loanId) {
    return _db
        .collection('merchant_loans')
        .doc(loanId)
        .collection('payments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MerchantLoanPayment.fromMap(d.id, d.data())).toList());
  }

  Future<void> addLoan({
    required String merchantId,
    required String storeId,
    required String lender,
    required double principal,
    required double interestRate,
    required DateTime dueDate,
    String? notes,
  }) async {
    await _db.collection('merchant_loans').add({
      'merchantId': merchantId,
      'storeId': storeId,
      'lender': lender,
      'principal': principal,
      'interestRate': interestRate,
      'totalPaid': 0,
      'dueDate': Timestamp.fromDate(dueDate),
      'notes': notes,
      'isCancelled': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordLoanPayment(String loanId, double amount, String recordedByUserId, {String? notes}) async {
    final loanRef = _db.collection('merchant_loans').doc(loanId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(loanRef);
      if (!snap.exists) return;
      final currentPaid = asDouble(snap.data()!['totalPaid']);
      tx.update(loanRef, {'totalPaid': currentPaid + amount, 'updatedAt': FieldValue.serverTimestamp()});
      final paymentRef = loanRef.collection('payments').doc();
      tx.set(paymentRef, {
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'recordedByUserId': recordedByUserId,
      });
    });
  }

  // ---------------- Consumer Credit ----------------
  Stream<List<ConsumerCreditAccount>> watchMerchantCredit(String merchantId) {
    return _db
        .collection('consumer_credit_accounts')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ConsumerCreditAccount.fromMap(d.id, d.data())).toList());
  }

  Stream<List<ConsumerCreditAccount>> watchConsumerOwnCredit(String consumerId) {
    return _db
        .collection('consumer_credit_accounts')
        .where('consumerId', isEqualTo: consumerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ConsumerCreditAccount.fromMap(d.id, d.data())).toList());
  }

  Stream<ConsumerCreditAccount?> watchCreditAccount(String id) {
    return _db.collection('consumer_credit_accounts').doc(id).snapshots().map((d) => d.exists ? ConsumerCreditAccount.fromMap(d.id, d.data()!) : null);
  }

  Stream<List<ConsumerCreditPayment>> watchCreditPayments(String accountId) {
    return _db
        .collection('consumer_credit_accounts')
        .doc(accountId)
        .collection('payments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ConsumerCreditPayment.fromMap(d.id, d.data())).toList());
  }

  Future<void> addCreditAccount({
    required String merchantId,
    required String storeId,
    required String consumerId,
    required String consumerName,
    String? relatedOrderId,
    required double originalAmount,
    required DateTime dueDate,
    String? paymentSchedule,
    String? notes,
  }) async {
    await _db.collection('consumer_credit_accounts').add({
      'merchantId': merchantId,
      'storeId': storeId,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'relatedOrderId': relatedOrderId,
      'originalAmount': originalAmount,
      'amountPaid': 0,
      'dueDate': Timestamp.fromDate(dueDate),
      'paymentSchedule': paymentSchedule,
      'notes': notes,
      'status': CreditStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordCreditPayment(String accountId, double amount, String recordedByUserId, {String? notes}) async {
    final accountRef = _db.collection('consumer_credit_accounts').doc(accountId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(accountRef);
      if (!snap.exists) return;
      final account = ConsumerCreditAccount.fromMap(snap.id, snap.data()!);
      final newPaid = account.amountPaid + amount;
      final newStatus = newPaid >= account.originalAmount
          ? CreditStatus.fullyPaid
          : (DateTime.now().isAfter(account.dueDate) ? CreditStatus.overdue : CreditStatus.partiallyPaid);
      tx.update(accountRef, {'amountPaid': newPaid, 'status': newStatus.name, 'updatedAt': FieldValue.serverTimestamp()});
      final paymentRef = accountRef.collection('payments').doc();
      tx.set(paymentRef, {
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
        'recordedByUserId': recordedByUserId,
        'notes': notes,
      });
    });
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(firestoreProvider));
});

final merchantExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchExpenses(user.id);
});

final merchantCapitalProvider = StreamProvider<List<CapitalEntry>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchCapital(user.id);
});

final merchantLoansProvider = StreamProvider<List<MerchantLoan>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchLoans(user.id);
});

final loanDetailProvider = StreamProvider.family<MerchantLoan?, String>((ref, id) {
  return ref.watch(financeRepositoryProvider).watchLoan(id);
});

final loanPaymentsProvider = StreamProvider.family<List<MerchantLoanPayment>, String>((ref, loanId) {
  return ref.watch(financeRepositoryProvider).watchLoanPayments(loanId);
});

final merchantCreditProvider = StreamProvider<List<ConsumerCreditAccount>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchMerchantCredit(user.id);
});

final consumerOwnCreditProvider = StreamProvider<List<ConsumerCreditAccount>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchConsumerOwnCredit(user.id);
});

final creditAccountDetailProvider = StreamProvider.family<ConsumerCreditAccount?, String>((ref, id) {
  return ref.watch(financeRepositoryProvider).watchCreditAccount(id);
});

final creditPaymentsProvider = StreamProvider.family<List<ConsumerCreditPayment>, String>((ref, id) {
  return ref.watch(financeRepositoryProvider).watchCreditPayments(id);
});
