import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class AutocompleteRepository {
  AutocompleteRepository(this._db);

  final AppDatabase _db;

  Future<List<ChoboRecentSelectionRecord>> getRecentSuggestions({
    required SelectionFieldType fieldType,
    String? transactionType,
    int limit = 10,
  }) async {
    String whereClause = 'WHERE field_type = ?';
    List<Variable<Object>> variables = [Variable<Object>(fieldType.name)];

    if (transactionType != null) {
      whereClause += ' AND (transaction_type = ? OR transaction_type IS NULL)';
      variables.add(Variable<Object>(transactionType));
    }

    final rows = await _db.customSelect(
      '''
      SELECT selection_id, field_type, field_value, transaction_type,
             frequency, last_selected_at, created_at
      FROM recent_selections
      $whereClause
      ORDER BY last_selected_at DESC
      LIMIT ?
      ''',
      variables: [...variables, Variable<Object>(limit)],
    ).get();

    return rows.map(ChoboRecentSelectionRecord.fromRow).toList();
  }

  Future<List<ChoboRecentSelectionRecord>> getFrequentSuggestions({
    required SelectionFieldType fieldType,
    String? transactionType,
    int limit = 10,
  }) async {
    String whereClause = 'WHERE field_type = ?';
    List<Variable<Object>> variables = [Variable<Object>(fieldType.name)];

    if (transactionType != null) {
      whereClause += ' AND (transaction_type = ? OR transaction_type IS NULL)';
      variables.add(Variable<Object>(transactionType));
    }

    final rows = await _db.customSelect(
      '''
      SELECT selection_id, field_type, field_value, transaction_type,
             frequency, last_selected_at, created_at
      FROM recent_selections
      $whereClause
      ORDER BY frequency DESC, last_selected_at DESC
      LIMIT ?
      ''',
      variables: [...variables, Variable<Object>(limit)],
    ).get();

    return rows.map(ChoboRecentSelectionRecord.fromRow).toList();
  }

  Future<List<ChoboRecentSelectionRecord>> getSmartSuggestions({
    required SelectionFieldType fieldType,
    String? transactionType,
    int limit = 10,
  }) async {
    String whereClause = 'WHERE field_type = ?';
    List<Variable<Object>> variables = [Variable<Object>(fieldType.name)];

    if (transactionType != null) {
      whereClause += ' AND (transaction_type = ? OR transaction_type IS NULL)';
      variables.add(Variable<Object>(transactionType));
    }

    final rows = await _db.customSelect(
      '''
      SELECT selection_id, field_type, field_value, transaction_type,
             frequency, last_selected_at, created_at
      FROM recent_selections
      $whereClause
      ORDER BY (frequency * 0.3 + (
        SELECT COUNT(*) FROM recent_selections
      ) - CAST(strftime('%s', 'now') - strftime('%s', last_selected_at) AS INTEGER) / 86400 * 0.1) DESC
      LIMIT ?
      ''',
      variables: [...variables, Variable<Object>(limit)],
    ).get();

    return rows.map(ChoboRecentSelectionRecord.fromRow).toList();
  }

  Future<void> recordSelection(ChoboRecentSelectionRecord selection) async {
    final existing = await _db.customSelect(
      '''
      SELECT selection_id, field_type, field_value, transaction_type,
             frequency, last_selected_at, created_at
      FROM recent_selections
      WHERE field_type = ? AND field_value = ? AND (transaction_type = ? OR (transaction_type IS NULL AND ? IS NULL))
      ''',
      variables: <Variable>[
        Variable(selection.fieldType.name),
        Variable(selection.fieldValue),
        Variable(selection.transactionType),
        Variable(selection.transactionType),
      ],
    ).getSingleOrNull();

    final now = DateTime.now().toUtc().toIso8601String();

    if (existing != null) {
      final existingRecord = ChoboRecentSelectionRecord.fromRow(existing);
      await _db.customUpdate(
        '''
        UPDATE recent_selections
        SET frequency = frequency + 1,
            last_selected_at = ?,
            created_at = COALESCE(created_at, ?)
        WHERE selection_id = ?
        ''',
        variables: <Variable>[
          Variable(now),
          Variable(existingRecord.createdAt),
          Variable(existingRecord.selectionId),
        ],
      );
    } else {
      await _db.customInsert(
        '''
        INSERT INTO recent_selections (
          selection_id,
          field_type,
          field_value,
          transaction_type,
          frequency,
          last_selected_at,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: <Variable>[
          Variable(selection.selectionId),
          Variable(selection.fieldType.name),
          Variable(selection.fieldValue),
          Variable(selection.transactionType),
          Variable(selection.frequency),
          Variable(now),
          Variable(now),
        ],
      );
    }
  }

  Future<void> pruneOldSelections({int maxAgeInDays = 90}) async {
    await _db.customUpdate(
      '''
      DELETE FROM recent_selections
      WHERE last_selected_at < date('now', ?)
      AND frequency < 3
      ''',
      variables: <Variable>[Variable('-$maxAgeInDays days')],
    );
  }
}
