import 'dart:convert';

import '../local_db/chobo_records.dart';
import '../repository/template_repository.dart';

class EntryTemplate {
  const EntryTemplate({
    required this.accountId,
    required this.direction,
    this.amountRatio,
    this.memo,
  });

  final String accountId;
  final String direction;
  final double? amountRatio;
  final String? memo;

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'direction': direction,
      if (amountRatio != null) 'amount_ratio': amountRatio,
      if (memo != null) 'memo': memo,
    };
  }

  static EntryTemplate fromJson(Map<String, dynamic> json) {
    return EntryTemplate(
      accountId: json['account_id'] as String,
      direction: json['direction'] as String,
      amountRatio: json['amount_ratio'] as double?,
      memo: json['memo'] as String?,
    );
  }
}

class TransactionTemplate {
  const TransactionTemplate({
    required this.templateId,
    required this.name,
    required this.transactionType,
    required this.entries,
    this.defaultDescription,
    this.usageCount = 0,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String templateId;
  final String name;
  final String transactionType;
  final List<EntryTemplate> entries;
  final String? defaultDescription;
  final int usageCount;
  final String? lastUsedAt;
  final String createdAt;
  final String updatedAt;

  String get entriesTemplateJson =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static TransactionTemplate fromRecord(
    ChoboTransactionTemplateRecord record,
  ) {
    final entriesList = (jsonDecode(record.entriesTemplate) as List)
        .map((e) => EntryTemplate.fromJson(e as Map<String, dynamic>))
        .toList();

    return TransactionTemplate(
      templateId: record.templateId,
      name: record.name,
      transactionType: record.transactionType,
      entries: entriesList,
      defaultDescription: record.defaultDescription,
      usageCount: record.usageCount,
      lastUsedAt: record.lastUsedAt,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }
}

class TemplateService {
  TemplateService(this._repository);

  final TemplateRepository _repository;

  Future<List<TransactionTemplate>> listTemplates({
    String? transactionType,
  }) async {
    final records = await _repository.listTemplates(
      transactionType: transactionType,
    );
    return records.map(TransactionTemplate.fromRecord).toList();
  }

  Future<TransactionTemplate?> getTemplate(String templateId) async {
    final record = await _repository.getTemplate(templateId);
    return record != null ? TransactionTemplate.fromRecord(record) : null;
  }

  Future<void> createTemplate(TransactionTemplate template) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final record = ChoboTransactionTemplateRecord(
      templateId: template.templateId,
      name: template.name,
      transactionType: template.transactionType,
      entriesTemplate: template.entriesTemplateJson,
      defaultDescription: template.defaultDescription,
      usageCount: 0,
      lastUsedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.createTemplate(record);
  }

  Future<void> updateTemplate(TransactionTemplate template) async {
    final record = ChoboTransactionTemplateRecord(
      templateId: template.templateId,
      name: template.name,
      transactionType: template.transactionType,
      entriesTemplate: template.entriesTemplateJson,
      defaultDescription: template.defaultDescription,
      usageCount: template.usageCount,
      lastUsedAt: template.lastUsedAt,
      createdAt: template.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _repository.updateTemplate(record);
  }

  Future<void> deleteTemplate(String templateId) async {
    await _repository.deleteTemplate(templateId);
  }

  Future<void> applyTemplate(String templateId) async {
    await _repository.incrementUsage(templateId);
  }

  Future<List<TransactionTemplate>> getSuggestedTemplates({
    required String transactionType,
    int limit = 5,
  }) async {
    final records = await _repository.getSuggestedTemplates(
      transactionType: transactionType,
      limit: limit,
    );
    return records.map(TransactionTemplate.fromRecord).toList();
  }

  Future<TransactionTemplate> createFromTransaction({
    required String name,
    required String transactionType,
    required List<EntryTemplate> entries,
    String? defaultDescription,
  }) async {
    final templateId = 'tpl_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();

    final template = TransactionTemplate(
      templateId: templateId,
      name: name,
      transactionType: transactionType,
      entries: entries,
      defaultDescription: defaultDescription,
      createdAt: now,
      updatedAt: now,
    );

    await createTemplate(template);
    return template;
  }
}
