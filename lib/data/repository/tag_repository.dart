import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/tag_sanitizer.dart';
import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../local_db/chobo_schema.dart';

class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  String _generateId() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix =
        List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  Future<ChoboTagRecord> createTag({
    required String name,
    String? color,
  }) async {
    final sanitized = TagSanitizer.sanitize(name);
    if (sanitized == null) {
      throw ArgumentError('Invalid tag name: $name');
    }

    final existing = await getTagByName(sanitized);
    if (existing != null) {
      throw StateError('Tag with name "$sanitized" already exists');
    }

    final tagId = _generateId();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final tag = ChoboTagRecord(
      tagId: tagId,
      name: sanitized,
      color: color,
      createdAt: createdAt,
    );

    await _db.customInsert(
      '''
      INSERT INTO tags (tag_id, name, color, created_at)
      VALUES (?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(tagId),
        Variable(sanitized),
        Variable(color),
        Variable(createdAt),
      ],
    );

    return tag;
  }

  Future<void> updateTag(ChoboTagRecord tag) async {
    final sanitized = TagSanitizer.sanitize(tag.name);
    if (sanitized == null) {
      throw ArgumentError('Invalid tag name: ${tag.name}');
    }

    final existing = await getTag(tag.tagId);
    if (existing == null) {
      throw StateError('Tag ${tag.tagId} not found');
    }

    if (sanitized != existing.name) {
      final other = await getTagByName(sanitized);
      if (other != null && other.tagId != tag.tagId) {
        throw StateError('Tag with name "$sanitized" already exists');
      }
    }

    await _db.customUpdate(
      '''
      UPDATE tags
      SET name = ?, color = ?
      WHERE tag_id = ?
      ''',
      variables: <Variable>[
        Variable(sanitized),
        Variable(tag.color),
        Variable(tag.tagId),
      ],
    );
  }

  Future<void> deleteTag(String tagId) async {
    final deleted = await _db.customUpdate(
      'DELETE FROM tags WHERE tag_id = ?',
      variables: <Variable>[Variable(tagId)],
    );
    if (deleted == 0) {
      throw StateError('Tag $tagId not found');
    }
  }

  Future<ChoboTagRecord?> getTag(String tagId) async {
    final result = await _db.customSelect(
      'SELECT * FROM tags WHERE tag_id = ?',
      variables: <Variable>[Variable(tagId)],
    ).get();

    if (result.isEmpty) return null;
    return ChoboTagRecord.fromRow(result.first);
  }

  Future<ChoboTagRecord?> getTagByName(String name) async {
    final result = await _db.customSelect(
      'SELECT * FROM tags WHERE name = ?',
      variables: <Variable>[Variable(name)],
    ).get();

    if (result.isEmpty) return null;
    return ChoboTagRecord.fromRow(result.first);
  }

  Future<List<ChoboTagRecord>> listTags() async {
    final result = await _db
        .customSelect(
          'SELECT * FROM tags ORDER BY name ASC',
        )
        .get();

    return result.map((row) => ChoboTagRecord.fromRow(row)).toList();
  }

  Future<List<ChoboTagRecord>> searchTags(String query) async {
    final sanitized = TagSanitizer.sanitize(query);
    if (sanitized == null || sanitized.isEmpty) {
      return listTags();
    }

    final result = await _db.customSelect(
      'SELECT * FROM tags WHERE name LIKE ? ORDER BY name ASC',
      variables: <Variable>[Variable('$sanitized%')],
    ).get();

    return result.map((row) => ChoboTagRecord.fromRow(row)).toList();
  }

  Future<void> addTagToTransaction({
    required String transactionId,
    required String tagId,
  }) async {
    await _db.customInsert(
      '''
      INSERT OR IGNORE INTO ${ChoboSchema.transactionTagsTable}
      (transaction_id, tag_id) VALUES (?, ?)
      ''',
      variables: <Variable>[
        Variable(transactionId),
        Variable(tagId),
      ],
    );
  }

  Future<void> removeTagFromTransaction({
    required String transactionId,
    required String tagId,
  }) async {
    await _db.customUpdate(
      'DELETE FROM ${ChoboSchema.transactionTagsTable} WHERE transaction_id = ? AND tag_id = ?',
      variables: <Variable>[
        Variable(transactionId),
        Variable(tagId),
      ],
    );
  }

  Future<void> setTransactionTags({
    required String transactionId,
    required List<String> tagIds,
  }) async {
    await _db.customUpdate(
      'DELETE FROM ${ChoboSchema.transactionTagsTable} WHERE transaction_id = ?',
      variables: <Variable>[Variable(transactionId)],
    );

    for (final tagId in tagIds) {
      await addTagToTransaction(
        transactionId: transactionId,
        tagId: tagId,
      );
    }
  }

  Future<List<ChoboTagRecord>> getTagsForTransaction(
      String transactionId) async {
    final result = await _db.customSelect(
      '''
      SELECT t.* FROM ${ChoboSchema.tagsTable} t
      INNER JOIN ${ChoboSchema.transactionTagsTable} tt ON t.tag_id = tt.tag_id
      WHERE tt.transaction_id = ?
      ORDER BY t.name ASC
      ''',
      variables: <Variable>[Variable(transactionId)],
    ).get();

    return result.map((row) => ChoboTagRecord.fromRow(row)).toList();
  }

  Future<List<String>> getTagIdsForTransaction(String transactionId) async {
    final result = await _db.customSelect(
      'SELECT tag_id FROM ${ChoboSchema.transactionTagsTable} WHERE transaction_id = ?',
      variables: <Variable>[Variable(transactionId)],
    ).get();

    return result.map((row) => row.read<String>('tag_id')).toList();
  }

  Future<Map<String, List<ChoboTagRecord>>> getTagsForTransactions(
    List<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return {};

    final placeholders = transactionIds.map((_) => '?').join(',');
    final result = await _db.customSelect(
      '''
      SELECT t.*, tt.transaction_id as txn_id FROM ${ChoboSchema.tagsTable} t
      INNER JOIN ${ChoboSchema.transactionTagsTable} tt ON t.tag_id = tt.tag_id
      WHERE tt.transaction_id IN ($placeholders)
      ORDER BY t.name ASC
      ''',
      variables: transactionIds.map((id) => Variable(id)).toList(),
    ).get();

    final Map<String, List<ChoboTagRecord>> tagsByTransaction = {};
    for (final row in result) {
      final txnId = row.read<String>('txn_id');
      final tag = ChoboTagRecord.fromRow(row);
      tagsByTransaction.putIfAbsent(txnId, () => []).add(tag);
    }
    return tagsByTransaction;
  }
}
