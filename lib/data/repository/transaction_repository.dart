import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  Future<void> createTransaction(
    ChoboTransactionRecord transactionRecord,
    List<ChoboEntryRecord> entries,
  ) {
    return _db.transaction(() async {
      await _validateTransactionForSave(transactionRecord, entries);
      await _insertTransaction(transactionRecord);
      await _replaceTransactionEntries(
        transactionRecord.transactionId,
        entries,
      );
    });
  }

  Future<void> createCorrectionTransaction(
    ChoboTransactionRecord transactionRecord,
    List<ChoboEntryRecord> entries,
  ) {
    return createTransaction(transactionRecord, entries);
  }

  Future<ChoboTransactionRecord?> getTransaction(String transactionId) async {
    final row = await _db.customSelect(
      '''
      SELECT transaction_id, date, type, status, description, counterparty,
             external_ref, period_lock_state, created_at, updated_at
      FROM transactions
      WHERE transaction_id = ?
      ''',
      variables: <Variable>[Variable(transactionId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboTransactionRecord.fromRow(row);
  }

  Future<List<ChoboTransactionRecord>> listTransactions([
    TransactionFilter? filter,
  ]) async {
    final conditions = <String>[];
    final variables = <Variable>[];

    if (filter != null) {
      if (filter.dateFrom != null) {
        conditions.add('t.date >= ?');
        variables.add(Variable(filter.dateFrom!));
      }
      if (filter.dateTo != null) {
        conditions.add('t.date <= ?');
        variables.add(Variable(filter.dateTo!));
      }
      if (filter.type != null) {
        conditions.add('t.type = ?');
        variables.add(Variable(filter.type!));
      }
      if (filter.status != null) {
        conditions.add('t.status = ?');
        variables.add(Variable(filter.status!));
      }
      if (filter.accountId != null) {
        conditions.add('e.account_id = ?');
        variables.add(Variable(filter.accountId!));
      }
    }

    final whereClause =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final needsJoin = filter?.accountId != null;

    final sql = '''
      SELECT DISTINCT t.transaction_id, t.date, t.type, t.status,
             t.description, t.counterparty, t.external_ref,
             t.period_lock_state, t.created_at, t.updated_at
      FROM transactions t
      ${needsJoin ? 'INNER JOIN entries e ON t.transaction_id = e.transaction_id' : ''}
      $whereClause
      ORDER BY t.date DESC, t.created_at DESC, t.transaction_id DESC
    ''';

    final rows = await _db.customSelect(sql, variables: variables).get();
    return rows.map(ChoboTransactionRecord.fromRow).toList(growable: false);
  }

  Future<int> updateTransaction(
    ChoboTransactionRecord transactionRecord,
    List<ChoboEntryRecord> entries,
  ) {
    return _db.transaction(() async {
      final decision = await canUpdateTransaction(
        transactionRecord.transactionId,
      );
      if (!decision.canApply) {
        throw StateError(decision.reason);
      }
      final existing = await getTransaction(transactionRecord.transactionId);
      if (existing == null) {
        throw StateError(
          'Transaction ${transactionRecord.transactionId} was not found.',
        );
      }
      if (existing.status == 'void') {
        throw StateError(
          'Void transactions cannot be edited. Create a correction transaction instead.',
        );
      }
      if (transactionRecord.status == 'void') {
        throw ArgumentError(
          'Use voidTransaction() to mark a transaction as void.',
        );
      }
      if (await _isClosedDate(existing.date) ||
          await _isClosedDate(transactionRecord.date)) {
        throw StateError(
          'Transactions in a closed period cannot be updated directly.',
        );
      }
      await _validateTransactionForSave(transactionRecord, entries);
      final updated = await _db.customUpdate(
        '''
        UPDATE transactions
        SET date = ?,
            type = ?,
            status = ?,
            description = ?,
            counterparty = ?,
            external_ref = ?,
            period_lock_state = ?,
            created_at = ?,
            updated_at = ?
        WHERE transaction_id = ?
        ''',
        variables: <Variable>[
          Variable(transactionRecord.date),
          Variable(transactionRecord.type),
          Variable(transactionRecord.status),
          Variable(transactionRecord.description),
          Variable(transactionRecord.counterparty),
          Variable(transactionRecord.externalRef),
          Variable(transactionRecord.periodLockState),
          Variable(transactionRecord.createdAt),
          Variable(transactionRecord.updatedAt),
          Variable(transactionRecord.transactionId),
        ],
      );
      if (updated == 0) {
        throw StateError(
          'Transaction ${transactionRecord.transactionId} was not found.',
        );
      }
      await _replaceTransactionEntries(
        transactionRecord.transactionId,
        entries,
      );
      return updated;
    });
  }

  Future<TransactionSaveDecision> canUpdateTransaction(
    String transactionId,
  ) async {
    final transaction = await getTransaction(transactionId);
    if (transaction == null) {
      return TransactionSaveDecision.notFound(transactionId);
    }

    final isClosedPeriod = await _isClosedDate(transaction.date);
    if (transaction.status == 'void') {
      return TransactionSaveDecision.alreadyVoided(
        transactionId: transactionId,
        date: transaction.date,
        isClosedPeriod: isClosedPeriod,
      );
    }
    if (isClosedPeriod) {
      return TransactionSaveDecision.closedPeriod(
        transactionId: transactionId,
        date: transaction.date,
      );
    }

    return TransactionSaveDecision(
      transactionId: transactionId,
      date: transaction.date,
      status: transaction.status,
      isClosedPeriod: false,
      canApply: true,
      reason: '未締め期間の取引です。直接編集できます。',
    );
  }

  Future<VoidTransactionDecision> canVoidTransaction(
    String transactionId,
  ) async {
    final transaction = await getTransaction(transactionId);
    if (transaction == null) {
      return VoidTransactionDecision.notFound(transactionId);
    }

    final isClosedPeriod = await _isClosedDate(transaction.date);
    if (transaction.status == 'void') {
      return VoidTransactionDecision.alreadyVoided(
        transactionId: transactionId,
        date: transaction.date,
        isClosedPeriod: isClosedPeriod,
      );
    }

    return VoidTransactionDecision(
      transactionId: transactionId,
      date: transaction.date,
      status: transaction.status,
      isClosedPeriod: isClosedPeriod,
      canApply: true,
      reason: isClosedPeriod ? '締め済み期間の取引ですが、取消できます。' : '未締め期間の取引です。',
    );
  }

  Future<int> voidTransaction(
    String transactionId, {
    String? updatedAt,
  }) async {
    final decision = await canVoidTransaction(transactionId);
    if (!decision.canApply) {
      return 0;
    }
    return _db.customUpdate(
      '''
      UPDATE transactions
      SET status = 'void',
          updated_at = ?
      WHERE transaction_id = ?
      ''',
      variables: <Variable>[
        Variable(updatedAt ?? DateTime.now().toUtc().toIso8601String()),
        Variable(transactionId),
      ],
    );
  }

  Future<void> _replaceTransactionEntries(
    String transactionId,
    List<ChoboEntryRecord> entries,
  ) async {
    _validateTransactionEntries(transactionId, entries);
    await _db.customUpdate(
      'DELETE FROM entries WHERE transaction_id = ?',
      variables: <Variable>[Variable(transactionId)],
    );
    for (final entry in entries) {
      await _insertEntry(entry);
    }
  }

  Future<void> _validateTransactionForSave(
    ChoboTransactionRecord transaction,
    List<ChoboEntryRecord> entries,
  ) async {
    if (transaction.status == 'void') {
      throw ArgumentError(
        'Use voidTransaction() to mark a transaction as void.',
      );
    }
    _validateTransactionEntries(transaction.transactionId, entries);
    final accountInfo = await _loadAccountInfo(entries);
    _validateStandardShape(transaction, entries, accountInfo);
  }

  Future<void> _insertTransaction(ChoboTransactionRecord transaction) async {
    await _db.customInsert(
      '''
      INSERT INTO transactions (
        transaction_id,
        date,
        type,
        status,
        description,
        counterparty,
        external_ref,
        period_lock_state,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _transactionVariables(transaction),
    );
  }

  Future<List<AccountInfo>> _loadAccountInfo(
    List<ChoboEntryRecord> entries,
  ) async {
    final infos = <AccountInfo>[];
    for (final entry in entries) {
      final row = await _db.customSelect(
        'SELECT kind, currency FROM accounts WHERE account_id = ?',
        variables: <Variable>[Variable(entry.accountId)],
      ).getSingleOrNull();
      if (row == null) {
        throw StateError('Account ${entry.accountId} was not found.');
      }
      infos.add(AccountInfo(
        kind: row.read<String>('kind'),
        currency: row.read<String>('currency'),
      ));
    }
    return infos;
  }

  void _validateStandardShape(
    ChoboTransactionRecord transaction,
    List<ChoboEntryRecord> entries,
    List<AccountInfo> accountInfo,
  ) {
    if (entries.length != 2) {
      throw ArgumentError('A transaction must have exactly 2 entries.');
    }
    if (entries[0].amount != entries[1].amount) {
      throw ArgumentError('Transaction entries must have matching amounts.');
    }
    if (entries[0].entryId == entries[1].entryId) {
      throw ArgumentError('Duplicate entry ids are not allowed.');
    }

    final kindSet = accountInfo.map((info) => info.kind).toSet();
    final directionSet = entries.map((entry) => entry.direction).toSet();

    switch (transaction.type) {
      case 'income':
        _expectKinds(kindSet, <String>{'asset', 'income'});
        _expectDirections(directionSet, <String>{'increase'});
        break;
      case 'expense':
        _expectKinds(kindSet, <String>{'asset', 'expense'});
        _expectDirections(directionSet, <String>{'decrease', 'increase'});
        break;
      case 'transfer':
        _expectKinds(kindSet, <String>{'asset'});
        _expectDirections(directionSet, <String>{'decrease', 'increase'});
        _expectDistinctAccounts(entries);
        _expectSameCurrencies(accountInfo);
        break;
      case 'credit_expense':
        _expectKinds(kindSet, <String>{'liability', 'expense'});
        _expectDirections(directionSet, <String>{'increase'});
        break;
      case 'liability_payment':
        _expectKinds(kindSet, <String>{'asset', 'liability'});
        _expectDirections(directionSet, <String>{'decrease'});
        break;
      default:
        throw ArgumentError(
            'Unsupported transaction type ${transaction.type}.');
    }
  }

  Future<bool> _isClosedDate(String date) async {
    final row = await _db.customSelect(
      '''
      SELECT 1 AS closed
      FROM period_closures
      WHERE ? BETWEEN start_date AND end_date
      LIMIT 1
      ''',
      variables: <Variable>[Variable(date)],
    ).getSingleOrNull();
    return row != null;
  }

  void _expectKinds(Set<String> actual, Set<String> expected) {
    if (!_sameMembers(actual, expected)) {
      throw ArgumentError('Transaction entries do not match the save rule.');
    }
  }

  void _expectDirections(Set<String> actual, Set<String> expected) {
    if (!_sameMembers(actual, expected)) {
      throw ArgumentError('Transaction entries do not match the save rule.');
    }
  }

  bool _sameMembers(Set<String> actual, Set<String> expected) {
    return actual.length == expected.length && actual.containsAll(expected);
  }

  void _expectDistinctAccounts(List<ChoboEntryRecord> entries) {
    if (entries[0].accountId == entries[1].accountId) {
      throw ArgumentError(
          'Transfer entries must use different asset accounts.');
    }
  }

  void _expectSameCurrencies(List<AccountInfo> accountInfo) {
    if (accountInfo.length != 2) {
      return;
    }
    if (accountInfo[0].currency != accountInfo[1].currency) {
      throw ArgumentError(
        'Transfer entries must use accounts with the same currency. '
        'Found ${accountInfo[0].currency} and ${accountInfo[1].currency}.',
      );
    }
  }

  Future<void> _insertEntry(ChoboEntryRecord entry) async {
    await _db.customInsert(
      '''
      INSERT INTO entries (
        entry_id,
        transaction_id,
        account_id,
        direction,
        amount,
        memo
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: _entryVariables(entry),
    );
  }

  void _validateTransactionEntries(
    String transactionId,
    List<ChoboEntryRecord> entries,
  ) {
    if (entries.length < 2) {
      throw ArgumentError('A transaction must have at least 2 entries.');
    }
    final seenEntryIds = <String>{};
    for (final entry in entries) {
      if (entry.transactionId != transactionId) {
        throw ArgumentError(
          'Entry ${entry.entryId} does not belong to transaction $transactionId.',
        );
      }
      if (!seenEntryIds.add(entry.entryId)) {
        throw ArgumentError('Duplicate entry id ${entry.entryId} in bundle.');
      }
    }
  }

  List<Variable> _transactionVariables(
    ChoboTransactionRecord transaction,
  ) {
    return <Variable>[
      Variable(transaction.transactionId),
      Variable(transaction.date),
      Variable(transaction.type),
      Variable(transaction.status),
      Variable(transaction.description),
      Variable(transaction.counterparty),
      Variable(transaction.externalRef),
      Variable(transaction.periodLockState),
      Variable(transaction.createdAt),
      Variable(transaction.updatedAt),
    ];
  }

  List<Variable> _entryVariables(ChoboEntryRecord entry) {
    return <Variable>[
      Variable(entry.entryId),
      Variable(entry.transactionId),
      Variable(entry.accountId),
      Variable(entry.direction),
      Variable(entry.amount),
      Variable(entry.memo),
    ];
  }
}

class VoidTransactionDecision {
  const VoidTransactionDecision({
    required this.transactionId,
    required this.date,
    required this.status,
    required this.isClosedPeriod,
    required this.canApply,
    required this.reason,
  });

  factory VoidTransactionDecision.notFound(String transactionId) {
    return VoidTransactionDecision(
      transactionId: transactionId,
      date: '',
      status: 'missing',
      isClosedPeriod: false,
      canApply: false,
      reason: '取引 $transactionId が見つかりません。',
    );
  }

  factory VoidTransactionDecision.alreadyVoided({
    required String transactionId,
    required String date,
    required bool isClosedPeriod,
  }) {
    return VoidTransactionDecision(
      transactionId: transactionId,
      date: date,
      status: 'void',
      isClosedPeriod: isClosedPeriod,
      canApply: false,
      reason: '取引 $transactionId はすでに取消済みです。',
    );
  }

  final String transactionId;
  final String date;
  final String status;
  final bool isClosedPeriod;
  final bool canApply;
  final String reason;
}

class TransactionSaveDecision {
  const TransactionSaveDecision({
    required this.transactionId,
    required this.date,
    required this.status,
    required this.isClosedPeriod,
    required this.canApply,
    required this.reason,
  });

  factory TransactionSaveDecision.notFound(String transactionId) {
    return TransactionSaveDecision(
      transactionId: transactionId,
      date: '',
      status: 'missing',
      isClosedPeriod: false,
      canApply: false,
      reason: '取引 $transactionId が見つかりません。',
    );
  }

  factory TransactionSaveDecision.alreadyVoided({
    required String transactionId,
    required String date,
    required bool isClosedPeriod,
  }) {
    return TransactionSaveDecision(
      transactionId: transactionId,
      date: date,
      status: 'void',
      isClosedPeriod: isClosedPeriod,
      canApply: false,
      reason: '取消済みの取引は直接編集できません。訂正取引を作成してください。',
    );
  }

  factory TransactionSaveDecision.closedPeriod({
    required String transactionId,
    required String date,
  }) {
    return TransactionSaveDecision(
      transactionId: transactionId,
      date: date,
      status: 'posted',
      isClosedPeriod: true,
      canApply: false,
      reason: '締め済み期間の取引は直接編集できません。訂正取引を作成してください。',
    );
  }

  final String transactionId;
  final String date;
  final String status;
  final bool isClosedPeriod;
  final bool canApply;
  final String reason;
}

class TransactionFilter {
  const TransactionFilter({
    this.dateFrom,
    this.dateTo,
    this.accountId,
    this.type,
    this.status,
  });

  final String? dateFrom;
  final String? dateTo;
  final String? accountId;
  final String? type;
  final String? status;
}

class AccountInfo {
  const AccountInfo({
    required this.kind,
    required this.currency,
  });

  final String kind;
  final String currency;
}
