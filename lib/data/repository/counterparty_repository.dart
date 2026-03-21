import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/counterparty_sanitizer.dart';
import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../local_db/chobo_schema.dart';

class CounterpartyRepository {
  CounterpartyRepository(this._db);

  final AppDatabase _db;

  String _generateId() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix =
        List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  Future<ChoboCounterpartyRecord> getOrCreateCounterparty({
    required String rawName,
    String? metadata,
  }) async {
    final normalizedName = CounterpartySanitizer.normalize(rawName);
    final existing = await getByNormalizedName(normalizedName);
    if (existing != null) {
      return existing;
    }

    return createCounterparty(
      rawName: CounterpartySanitizer.displayName(rawName),
      normalizedName: normalizedName,
      metadata: metadata,
    );
  }

  Future<ChoboCounterpartyRecord> createCounterparty({
    required String normalizedName,
    required String rawName,
    String? metadata,
  }) async {
    final counterpartyId = _generateId();
    final now = DateTime.now().toUtc().toIso8601String();

    final counterparty = ChoboCounterpartyRecord(
      counterpartyId: counterpartyId,
      normalizedName: normalizedName,
      rawName: rawName,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    await _db.customInsert(
      '''
      INSERT INTO ${ChoboSchema.counterpartiesTable}
      (counterparty_id, normalized_name, raw_name, metadata, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(counterpartyId),
        Variable(normalizedName),
        Variable(rawName),
        Variable(metadata),
        Variable(now),
        Variable(now),
      ],
    );

    return counterparty;
  }

  Future<void> updateCounterparty(ChoboCounterpartyRecord counterparty) async {
    final normalizedName =
        CounterpartySanitizer.normalize(counterparty.rawName);
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.customUpdate(
      '''
      UPDATE ${ChoboSchema.counterpartiesTable}
      SET normalized_name = ?, raw_name = ?, metadata = ?, updated_at = ?
      WHERE counterparty_id = ?
      ''',
      variables: <Variable>[
        Variable(normalizedName),
        Variable(counterparty.rawName),
        Variable(counterparty.metadata),
        Variable(now),
        Variable(counterparty.counterpartyId),
      ],
    );
  }

  Future<void> deleteCounterparty(String counterpartyId) async {
    await _db.customUpdate(
      'DELETE FROM ${ChoboSchema.counterpartiesTable} WHERE counterparty_id = ?',
      variables: <Variable>[Variable(counterpartyId)],
    );
  }

  Future<ChoboCounterpartyRecord?> getCounterparty(
      String counterpartyId) async {
    final result = await _db.customSelect(
      'SELECT * FROM ${ChoboSchema.counterpartiesTable} WHERE counterparty_id = ?',
      variables: <Variable>[Variable(counterpartyId)],
    ).get();

    if (result.isEmpty) return null;
    return ChoboCounterpartyRecord.fromRow(result.first);
  }

  Future<ChoboCounterpartyRecord?> getByNormalizedName(
      String normalizedName) async {
    final result = await _db.customSelect(
      'SELECT * FROM ${ChoboSchema.counterpartiesTable} WHERE normalized_name = ?',
      variables: <Variable>[Variable(normalizedName)],
    ).get();

    if (result.isEmpty) return null;
    return ChoboCounterpartyRecord.fromRow(result.first);
  }

  Future<List<ChoboCounterpartyRecord>> listCounterparties() async {
    final result = await _db
        .customSelect(
          'SELECT * FROM ${ChoboSchema.counterpartiesTable} ORDER BY raw_name ASC',
        )
        .get();

    return result.map((row) => ChoboCounterpartyRecord.fromRow(row)).toList();
  }

  Future<List<ChoboCounterpartyRecord>> searchCounterparties(
      String query) async {
    if (query.isEmpty) {
      return listCounterparties();
    }

    final normalizedQuery = CounterpartySanitizer.normalize(query);

    final result = await _db.customSelect(
      '''
      SELECT * FROM ${ChoboSchema.counterpartiesTable}
      WHERE normalized_name LIKE ? OR raw_name LIKE ?
      ORDER BY raw_name ASC
      LIMIT 20
      ''',
      variables: <Variable>[
        Variable('%$normalizedQuery%'),
        Variable('%$query%'),
      ],
    ).get();

    return result.map((row) => ChoboCounterpartyRecord.fromRow(row)).toList();
  }

  Future<List<ChoboCounterpartyRecord>> findSimilarCounterparties(
    String rawName, {
    double threshold = 0.7,
  }) async {
    final normalized = CounterpartySanitizer.normalize(rawName);
    if (normalized.isEmpty) return [];

    final result = await _db
        .customSelect(
          'SELECT * FROM ${ChoboSchema.counterpartiesTable} ORDER BY raw_name ASC LIMIT 50',
        )
        .get();

    final candidates =
        result.map((row) => ChoboCounterpartyRecord.fromRow(row)).toList();
    final similar = <ChoboCounterpartyRecord>[];

    for (final candidate in candidates) {
      if (_similarity(normalized, candidate.normalizedName) >= threshold) {
        similar.add(candidate);
      }
    }

    return similar;
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    final longerLength = longer.length;
    if (longerLength == 0) return 1;

    return (longerLength - _editDistance(longer, shorter)) / longerLength;
  }

  int _editDistance(String a, String b) {
    final aChars = a.split('');
    final bChars = b.split('');

    final distances = List.generate(
      aChars.length + 1,
      (_) => List.filled(bChars.length + 1, 0),
    );

    for (var i = 0; i <= aChars.length; i++) {
      distances[i][0] = i;
    }
    for (var j = 0; j <= bChars.length; j++) {
      distances[0][j] = j;
    }

    for (var i = 1; i <= aChars.length; i++) {
      for (var j = 1; j <= bChars.length; j++) {
        final cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1;
        distances[i][j] = [
          distances[i - 1][j] + 1,
          distances[i][j - 1] + 1,
          distances[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return distances[aChars.length][bChars.length];
  }
}
