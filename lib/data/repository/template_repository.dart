import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class TemplateRepository {
  TemplateRepository(this._db);

  final AppDatabase _db;

  Future<List<ChoboTransactionTemplateRecord>> listTemplates({
    String? transactionType,
    bool orderByUsage = true,
  }) async {
    String orderClause = orderByUsage
        ? 'ORDER BY usage_count DESC, name ASC'
        : 'ORDER BY name ASC';

    String whereClause = '';
    List<Variable> variables = [];

    if (transactionType != null) {
      whereClause = 'WHERE transaction_type = ?';
      variables = [Variable(transactionType)];
    }

    final List<Variable<Object>> sqlVariables = variables.isEmpty
        ? <Variable<Object>>[]
        : variables.map((v) => Variable<Object>(v.value as Object)).toList();

    final rows = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, entries_template,
             default_description, usage_count, last_used_at,
             created_at, updated_at
      FROM transaction_templates
      $whereClause
      $orderClause
      ''',
      variables: sqlVariables,
    ).get();

    return rows.map(ChoboTransactionTemplateRecord.fromRow).toList();
  }

  Future<ChoboTransactionTemplateRecord?> getTemplate(String templateId) async {
    final rows = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, entries_template,
             default_description, usage_count, last_used_at,
             created_at, updated_at
      FROM transaction_templates
      WHERE template_id = ?
      ''',
      variables: <Variable>[Variable(templateId)],
    ).getSingleOrNull();

    return rows == null ? null : ChoboTransactionTemplateRecord.fromRow(rows);
  }

  Future<void> createTemplate(ChoboTransactionTemplateRecord template) async {
    await _db.customInsert(
      '''
      INSERT INTO transaction_templates (
        template_id,
        name,
        transaction_type,
        entries_template,
        default_description,
        usage_count,
        last_used_at,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _templateVariables(template),
    );
  }

  Future<int> updateTemplate(ChoboTransactionTemplateRecord template) async {
    return await _db.customUpdate(
      '''
      UPDATE transaction_templates
      SET name = ?,
          transaction_type = ?,
          entries_template = ?,
          default_description = ?,
          usage_count = ?,
          last_used_at = ?,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(template.name),
        Variable(template.transactionType),
        Variable(template.entriesTemplate),
        Variable(template.defaultDescription),
        Variable(template.usageCount),
        Variable(template.lastUsedAt),
        Variable(template.updatedAt),
        Variable(template.templateId),
      ],
    );
  }

  Future<int> deleteTemplate(String templateId) async {
    return await _db.customUpdate(
      'DELETE FROM transaction_templates WHERE template_id = ?',
      variables: <Variable>[Variable(templateId)],
    );
  }

  Future<void> incrementUsage(String templateId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.customUpdate(
      '''
      UPDATE transaction_templates
      SET usage_count = usage_count + 1,
          last_used_at = ?,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(now),
        Variable(now),
        Variable(templateId),
      ],
    );
  }

  Future<List<ChoboTransactionTemplateRecord>> getSuggestedTemplates({
    required String transactionType,
    int limit = 5,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, entries_template,
             default_description, usage_count, last_used_at,
             created_at, updated_at
      FROM transaction_templates
      WHERE transaction_type = ?
      ORDER BY usage_count DESC, last_used_at DESC
      LIMIT ?
      ''',
      variables: <Variable>[Variable(transactionType), Variable(limit)],
    ).get();

    return rows.map(ChoboTransactionTemplateRecord.fromRow).toList();
  }

  List<Variable> _templateVariables(ChoboTransactionTemplateRecord template) {
    return <Variable>[
      Variable(template.templateId),
      Variable(template.name),
      Variable(template.transactionType),
      Variable(template.entriesTemplate),
      Variable(template.defaultDescription),
      Variable(template.usageCount),
      Variable(template.lastUsedAt),
      Variable(template.createdAt),
      Variable(template.updatedAt),
    ];
  }
}
