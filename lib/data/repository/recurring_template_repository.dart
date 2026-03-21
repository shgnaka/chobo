import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class RecurringTemplateRepository {
  RecurringTemplateRepository(this._db);

  final AppDatabase _db;

  Future<void> createTemplate(ChoboRecurringTemplateRecord template) async {
    await _db.customInsert(
      '''
      INSERT INTO recurring_templates (
        template_id,
        name,
        transaction_type,
        frequency,
        interval_value,
        start_date,
        end_date,
        next_generation_date,
        last_generated_transaction_id,
        entries_template,
        is_active,
        auto_post,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _templateVariables(template),
    );
  }

  Future<ChoboRecurringTemplateRecord?> getTemplate(String templateId) async {
    final row = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, frequency, interval_value,
             start_date, end_date, next_generation_date,
             last_generated_transaction_id, entries_template,
             is_active, auto_post, created_at, updated_at
      FROM recurring_templates
      WHERE template_id = ?
      ''',
      variables: <Variable>[Variable(templateId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboRecurringTemplateRecord.fromRow(row);
  }

  Future<List<ChoboRecurringTemplateRecord>> listTemplates({
    bool activeOnly = false,
  }) async {
    final whereClause = activeOnly ? 'WHERE is_active = 1' : '';
    final rows = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, frequency, interval_value,
             start_date, end_date, next_generation_date,
             last_generated_transaction_id, entries_template,
             is_active, auto_post, created_at, updated_at
      FROM recurring_templates
      $whereClause
      ORDER BY next_generation_date ASC, name ASC
      ''',
    ).get();
    return rows
        .map(ChoboRecurringTemplateRecord.fromRow)
        .toList(growable: false);
  }

  Future<int> updateTemplate(ChoboRecurringTemplateRecord template) async {
    return _db.customUpdate(
      '''
      UPDATE recurring_templates
      SET name = ?,
          transaction_type = ?,
          frequency = ?,
          interval_value = ?,
          start_date = ?,
          end_date = ?,
          next_generation_date = ?,
          last_generated_transaction_id = ?,
          entries_template = ?,
          is_active = ?,
          auto_post = ?,
          created_at = ?,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(template.name),
        Variable(template.transactionType),
        Variable(template.frequency),
        Variable(template.intervalValue),
        Variable(template.startDate),
        Variable(template.endDate),
        Variable(template.nextGenerationDate),
        Variable(template.lastGeneratedTransactionId),
        Variable(template.entriesTemplate),
        Variable(template.isActive ? 1 : 0),
        Variable(template.autoPost ? 1 : 0),
        Variable(template.createdAt),
        Variable(template.updatedAt),
        Variable(template.templateId),
      ],
    );
  }

  Future<int> updateNextGenerationDate({
    required String templateId,
    required String nextGenerationDate,
    required String lastGeneratedTransactionId,
    required String updatedAt,
  }) async {
    return _db.customUpdate(
      '''
      UPDATE recurring_templates
      SET next_generation_date = ?,
          last_generated_transaction_id = ?,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(nextGenerationDate),
        Variable(lastGeneratedTransactionId),
        Variable(updatedAt),
        Variable(templateId),
      ],
    );
  }

  Future<int> pauseTemplate(String templateId, String updatedAt) async {
    return _db.customUpdate(
      '''
      UPDATE recurring_templates
      SET is_active = 0,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(updatedAt),
        Variable(templateId),
      ],
    );
  }

  Future<int> resumeTemplate(String templateId, String updatedAt) async {
    return _db.customUpdate(
      '''
      UPDATE recurring_templates
      SET is_active = 1,
          updated_at = ?
      WHERE template_id = ?
      ''',
      variables: <Variable>[
        Variable(updatedAt),
        Variable(templateId),
      ],
    );
  }

  Future<int> deleteTemplate(String templateId) async {
    return _db.customUpdate(
      'DELETE FROM recurring_templates WHERE template_id = ?',
      variables: <Variable>[Variable(templateId)],
    );
  }

  Future<List<ChoboRecurringTemplateRecord>>
      getTemplatesDueForGeneration() async {
    final now = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final rows = await _db.customSelect(
      '''
      SELECT template_id, name, transaction_type, frequency, interval_value,
             start_date, end_date, next_generation_date,
             last_generated_transaction_id, entries_template,
             is_active, auto_post, created_at, updated_at
      FROM recurring_templates
      WHERE is_active = 1
        AND (end_date IS NULL OR end_date >= ?)
        AND (next_generation_date IS NULL OR next_generation_date <= ?)
      ORDER BY next_generation_date ASC
      ''',
      variables: <Variable>[Variable(now), Variable(now)],
    ).get();
    return rows
        .map(ChoboRecurringTemplateRecord.fromRow)
        .toList(growable: false);
  }

  List<Variable> _templateVariables(ChoboRecurringTemplateRecord template) {
    return <Variable>[
      Variable(template.templateId),
      Variable(template.name),
      Variable(template.transactionType),
      Variable(template.frequency),
      Variable(template.intervalValue),
      Variable(template.startDate),
      Variable(template.endDate),
      Variable(template.nextGenerationDate),
      Variable(template.lastGeneratedTransactionId),
      Variable(template.entriesTemplate),
      Variable(template.isActive ? 1 : 0),
      Variable(template.autoPost ? 1 : 0),
      Variable(template.createdAt),
      Variable(template.updatedAt),
    ];
  }
}
