import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../repository/account_repository.dart';
import '../repository/transaction_repository.dart';

class RefundService {
  RefundService(
    this._db, {
    AccountRepository? accountRepository,
    TransactionRepository? transactionRepository,
  })  : _accountRepository = accountRepository ?? AccountRepository(_db),
        _transactionRepository =
            transactionRepository ?? TransactionRepository(_db);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  Future<RefundValidation> validateRefund({
    required String originalTransactionId,
    required int refundAmount,
  }) async {
    final original =
        await _transactionRepository.getTransaction(originalTransactionId);
    if (original == null) {
      return RefundValidation(
        canRefund: false,
        reason: '元の取引が見つかりません',
        maxRefundAmount: 0,
        remainingRefundable: 0,
      );
    }

    if (original.status == 'void') {
      return RefundValidation(
        canRefund: false,
        reason: '取消済みの取引は返金できません',
        maxRefundAmount: 0,
        remainingRefundable: 0,
      );
    }

    final entries = await _getTransactionEntries(originalTransactionId);
    if (entries.isEmpty) {
      return RefundValidation(
        canRefund: false,
        reason: '取引の明細が見つかりません',
        maxRefundAmount: 0,
        remainingRefundable: 0,
      );
    }

    final originalAmount = entries.first.amount;
    final existingRefunds =
        await _getExistingRefundAmounts(originalTransactionId);
    final totalRefunded = existingRefunds.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    final remainingRefundable = originalAmount - totalRefunded;

    if (refundAmount > remainingRefundable) {
      return RefundValidation(
        canRefund: false,
        reason: '返金額が残りの返金可能額を超えています',
        maxRefundAmount: originalAmount,
        remainingRefundable: remainingRefundable,
      );
    }

    return RefundValidation(
      canRefund: true,
      reason: '返金 가능합니다',
      maxRefundAmount: originalAmount,
      remainingRefundable: remainingRefundable,
    );
  }

  Future<RefundDecision> createRefund({
    required String refundTransactionId,
    required String originalTransactionId,
    required int refundAmount,
    required String date,
    required String refundType,
    required List<ChoboEntryRecord> refundEntries,
    String? description,
  }) async {
    final validation = await validateRefund(
      originalTransactionId: originalTransactionId,
      refundAmount: refundAmount,
    );

    if (!validation.canRefund) {
      return RefundDecision(
        success: false,
        refundTransactionId: null,
        reason: validation.reason,
      );
    }

    final original =
        await _transactionRepository.getTransaction(originalTransactionId);
    final refundTypeStr =
        original != null && _isIncomeType(original.type) ? 'expense' : 'income';

    await _transactionRepository.createTransaction(
      ChoboTransactionRecord(
        transactionId: refundTransactionId,
        date: date,
        type: refundTypeStr,
        status: 'posted',
        originalTransactionId: originalTransactionId,
        refundType: refundType,
        description: description ?? 'Refund for $originalTransactionId',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
      refundEntries,
    );

    return RefundDecision(
      success: true,
      refundTransactionId: refundTransactionId,
      reason: '返金取引を作成しました',
    );
  }

  Future<void> cancelRefund(String refundTransactionId) async {
    final refund =
        await _transactionRepository.getTransaction(refundTransactionId);
    if (refund == null) {
      throw StateError('Refund transaction not found');
    }

    if (refund.status == 'void') {
      throw StateError('Refund is already voided');
    }

    await _transactionRepository.voidTransaction(refundTransactionId);
  }

  Future<List<RefundInfo>> getRefundHistory(String transactionId) async {
    final refunds = await _db.customSelect(
      '''
      SELECT transaction_id, date, type, status, description,
             original_transaction_id, refund_type, created_at
      FROM transactions
      WHERE original_transaction_id = ?
      ORDER BY created_at DESC
      ''',
      variables: <Variable>[Variable(transactionId)],
    ).get();

    final history = <RefundInfo>[];
    for (final row in refunds) {
      final entries =
          await _getTransactionEntries(row.read<String>('transaction_id'));
      final amount = entries.isNotEmpty ? entries.first.amount : 0;

      history.add(RefundInfo(
        transactionId: row.read<String>('transaction_id'),
        date: row.read<String>('date'),
        status: row.read<String>('status'),
        description: row.readNullable<String>('description') ?? '',
        refundType: row.readNullable<String>('refund_type'),
        amount: amount,
        createdAt: row.read<String>('created_at'),
      ));
    }

    return history;
  }

  Future<int> getTotalRefundedAmount(String transactionId) async {
    final refunds = await getRefundHistory(transactionId);
    return refunds
        .where((r) => r.status == 'posted')
        .fold<int>(0, (sum, r) => sum + r.amount);
  }

  Future<List<ChoboEntryRecord>> _getTransactionEntries(
      String transactionId) async {
    final rows = await _db.customSelect(
      'SELECT entry_id, transaction_id, account_id, direction, amount, memo FROM entries WHERE transaction_id = ?',
      variables: <Variable>[Variable(transactionId)],
    ).get();
    return rows.map(ChoboEntryRecord.fromRow).toList(growable: false);
  }

  Future<List<ChoboTransactionRecord>> _getExistingRefunds(
      String transactionId) async {
    final rows = await _db.customSelect(
      '''
      SELECT transaction_id, date, type, status, description,
             original_transaction_id, refund_type, created_at, updated_at
      FROM transactions
      WHERE original_transaction_id = ? AND status = 'posted'
      ''',
      variables: <Variable>[Variable(transactionId)],
    ).get();
    return rows.map((row) {
      return ChoboTransactionRecord(
        transactionId: row.read<String>('transaction_id'),
        date: row.read<String>('date'),
        type: row.read<String>('type'),
        status: row.read<String>('status'),
        description: row.readNullable<String>('description'),
        originalTransactionId:
            row.readNullable<String>('original_transaction_id'),
        refundType: row.readNullable<String>('refund_type'),
        createdAt: row.read<String>('created_at'),
        updatedAt: row.read<String>('updated_at'),
      );
    }).toList(growable: false);
  }

  Future<List<int>> _getExistingRefundAmounts(String transactionId) async {
    final refunds = await _getExistingRefunds(transactionId);
    final amounts = <int>[];
    for (final refund in refunds) {
      final entries = await _getTransactionEntries(refund.transactionId);
      if (entries.isNotEmpty) {
        amounts.add(entries.first.amount);
      }
    }
    return amounts;
  }

  bool _isIncomeType(String type) {
    return type == 'income' || type == 'reimbursement';
  }
}

class RefundValidation {
  const RefundValidation({
    required this.canRefund,
    required this.reason,
    required this.maxRefundAmount,
    required this.remainingRefundable,
  });

  final bool canRefund;
  final String reason;
  final int maxRefundAmount;
  final int remainingRefundable;
}

class RefundDecision {
  const RefundDecision({
    required this.success,
    required this.refundTransactionId,
    required this.reason,
  });

  final bool success;
  final String? refundTransactionId;
  final String reason;
}

class RefundInfo {
  const RefundInfo({
    required this.transactionId,
    required this.date,
    required this.status,
    required this.description,
    required this.refundType,
    required this.amount,
    required this.createdAt,
  });

  final String transactionId;
  final String date;
  final String status;
  final String description;
  final String? refundType;
  final int amount;
  final String createdAt;

  bool get isFullRefund => refundType == 'full';
  bool get isPartialRefund => refundType == 'partial';
  bool get isPosted => status == 'posted';
  bool get isVoided => status == 'void';
}
