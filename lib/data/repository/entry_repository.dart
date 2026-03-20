import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class EntryRepository {
  EntryRepository(this._db);

  final AppDatabase _db;

  Future<List<ChoboEntryRecord>> listEntries() async {
    final rows = await _db.customSelect(
      '''
      SELECT entry_id, transaction_id, account_id, direction, amount, memo
      FROM entries
      ORDER BY transaction_id, entry_id
      ''',
    ).get();
    return rows.map(ChoboEntryRecord.fromRow).toList(growable: false);
  }

  Future<List<ChoboEntryRecord>> listEntriesForTransaction(
    String transactionId,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT entry_id, transaction_id, account_id, direction, amount, memo
      FROM entries
      WHERE transaction_id = ?
      ORDER BY entry_id
      ''',
      variables: <Variable>[Variable(transactionId)],
    ).get();
    return rows.map(ChoboEntryRecord.fromRow).toList(growable: false);
  }

  Future<ChoboEntryRecord?> getEntry(String entryId) async {
    final row = await _db.customSelect(
      '''
      SELECT entry_id, transaction_id, account_id, direction, amount, memo
      FROM entries
      WHERE entry_id = ?
      ''',
      variables: <Variable>[Variable(entryId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboEntryRecord.fromRow(row);
  }

  Future<void> createEntry(ChoboEntryRecord entry) async {
    await _assertTransactionCanAcceptStandaloneEntry(entry.transactionId);
    await _insertEntry(entry);
  }

  Future<int> updateEntry(ChoboEntryRecord entry) async {
    final existing = await getEntry(entry.entryId);
    if (existing == null) {
      throw StateError('Entry ${entry.entryId} was not found.');
    }
    if (existing.transactionId != entry.transactionId) {
      throw ArgumentError(
        'Updating an entry cannot move it between transactions.',
      );
    }

    return _db.customUpdate(
      '''
      UPDATE entries
      SET transaction_id = ?,
          account_id = ?,
          direction = ?,
          amount = ?,
          memo = ?
      WHERE entry_id = ?
      ''',
      variables: <Variable>[
        Variable(entry.transactionId),
        Variable(entry.accountId),
        Variable(entry.direction),
        Variable(entry.amount),
        Variable(entry.memo),
        Variable(entry.entryId),
      ],
    );
  }

  Future<int> deleteEntry(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      return 0;
    }
    final count = await _countEntriesForTransaction(entry.transactionId);
    if (count <= 2) {
      throw StateError(
        'Deleting this entry would leave transaction ${entry.transactionId} with fewer than 2 entries.',
      );
    }
    return _db.customUpdate(
      'DELETE FROM entries WHERE entry_id = ?',
      variables: <Variable>[Variable(entryId)],
    );
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

  Future<int> _countEntriesForTransaction(String transactionId) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS count FROM entries WHERE transaction_id = ?',
      variables: <Variable>[Variable(transactionId)],
    ).getSingle();
    return row.read<int>('count');
  }

  Future<void> _assertTransactionCanAcceptStandaloneEntry(
    String transactionId,
  ) async {
    final count = await _countEntriesForTransaction(transactionId);
    if (count == 0) {
      throw StateError(
        'Transaction $transactionId needs an initial bundle of at least 2 entries before standalone entry inserts.',
      );
    }
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
