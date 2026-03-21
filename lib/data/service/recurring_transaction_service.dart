import 'dart:convert';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../repository/recurring_template_repository.dart';
import '../repository/transaction_repository.dart';

class RecurringTransactionService {
  RecurringTransactionService(
    this._db, {
    RecurringTemplateRepository? templateRepository,
    TransactionRepository? transactionRepository,
  })  : _templateRepository =
            templateRepository ?? RecurringTemplateRepository(_db),
        _transactionRepository =
            transactionRepository ?? TransactionRepository(_db);

  final AppDatabase _db;
  final RecurringTemplateRepository _templateRepository;
  final TransactionRepository _transactionRepository;

  Future<List<RecurringGenerationResult>> processDueTemplates() async {
    final templates = await _templateRepository.getTemplatesDueForGeneration();
    final results = <RecurringGenerationResult>[];

    for (final template in templates) {
      try {
        final result = await generateTransactionFromTemplate(template);
        results.add(result);
      } catch (e) {
        results.add(RecurringGenerationResult(
          templateId: template.templateId,
          success: false,
          errorMessage: e.toString(),
        ));
      }
    }

    return results;
  }

  Future<RecurringGenerationResult> generateTransactionFromTemplate(
    ChoboRecurringTemplateRecord template,
  ) async {
    final now = DateTime.now();
    final date = template.nextGenerationDate ?? template.startDate;

    final entries = _parseEntriesTemplate(template.entriesTemplate);
    if (entries == null) {
      return RecurringGenerationResult(
        templateId: template.templateId,
        success: false,
        errorMessage: 'Invalid entries template',
      );
    }

    final transactionId = _generateTransactionId(template.templateId);
    final transaction = ChoboTransactionRecord(
      transactionId: transactionId,
      date: date,
      type: template.transactionType,
      status: template.autoPost ? 'posted' : 'pending',
      description: 'Recurring: ${template.name}',
      createdAt: now.toUtc().toIso8601String(),
      updatedAt: now.toUtc().toIso8601String(),
    );

    final updatedEntries = entries.map((e) {
      return e.copyWith(
        entryId: '${transactionId}_${e.entryId}',
        transactionId: transactionId,
      );
    }).toList();

    if (await _checkForDuplicate(transaction.date, template, updatedEntries)) {
      return RecurringGenerationResult(
        templateId: template.templateId,
        success: false,
        errorMessage: 'Duplicate transaction detected',
        transactionId: transactionId,
      );
    }

    await _transactionRepository.createTransaction(transaction, updatedEntries);

    final nextDate =
        _calculateNextDate(date, template.frequency, template.intervalValue);
    await _templateRepository.updateNextGenerationDate(
      templateId: template.templateId,
      nextGenerationDate: nextDate,
      lastGeneratedTransactionId: transactionId,
      updatedAt: now.toUtc().toIso8601String(),
    );

    return RecurringGenerationResult(
      templateId: template.templateId,
      success: true,
      transactionId: transactionId,
      nextGenerationDate: nextDate,
    );
  }

  Future<bool> _checkForDuplicate(
    String date,
    ChoboRecurringTemplateRecord template,
    List<ChoboEntryRecord> entries,
  ) async {
    final existingTransactions = await _transactionRepository.listTransactions(
      TransactionFilter(
        dateFrom: date,
        dateTo: date,
        type: template.transactionType,
      ),
    );

    for (final existing in existingTransactions) {
      if (existing.description?.contains(template.name) == true) {
        return true;
      }
    }

    return false;
  }

  String _calculateNextDate(
      String currentDate, String frequency, int interval) {
    final date = DateTime.parse(currentDate);
    final nextDate = switch (frequency) {
      'daily' => date.add(Duration(days: interval)),
      'weekly' => date.add(Duration(days: 7 * interval)),
      'monthly' => DateTime(date.year, date.month + interval, date.day),
      'yearly' => DateTime(date.year + interval, date.month, date.day),
      _ => date.add(Duration(days: 30 * interval)),
    };
    return nextDate.toIso8601String().substring(0, 10);
  }

  List<ChoboEntryRecord>? _parseEntriesTemplate(String template) {
    try {
      final List<dynamic> json = jsonDecode(template);
      return json.map((e) {
        final map = Map<String, dynamic>.from(e);
        return ChoboEntryRecord(
          entryId: map['entry_id'] as String,
          transactionId: '',
          accountId: map['account_id'] as String,
          direction: map['direction'] as String,
          amount: map['amount'] as int,
          memo: map['memo'] as String?,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  String _generateTransactionId(String templateId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'rtxn_${templateId}_$timestamp';
  }

  String serializeEntriesTemplate(List<ChoboEntryRecord> entries) {
    final json = entries.map((e) {
      return {
        'entry_id': e.entryId,
        'account_id': e.accountId,
        'direction': e.direction,
        'amount': e.amount,
        'memo': e.memo,
      };
    }).toList();
    return jsonEncode(json);
  }

  Future<List<UpcomingRecurringTransaction>> getUpcomingTransactions({
    int daysAhead = 30,
  }) async {
    final templates = await _templateRepository.listTemplates(activeOnly: true);
    final upcoming = <UpcomingRecurringTransaction>[];

    for (final template in templates) {
      final now = DateTime.now();
      final endDate = now.add(Duration(days: daysAhead));
      var currentDate = template.nextGenerationDate != null
          ? DateTime.parse(template.nextGenerationDate!)
          : DateTime.parse(template.startDate);

      while (currentDate.isBefore(endDate)) {
        if (currentDate.isAfter(now) || currentDate.isAtSameMomentAs(now)) {
          upcoming.add(UpcomingRecurringTransaction(
            templateId: template.templateId,
            templateName: template.name,
            transactionType: template.transactionType,
            scheduledDate: currentDate.toIso8601String().substring(0, 10),
          ));
        }

        if (template.endDate != null &&
            currentDate.isAfter(DateTime.parse(template.endDate!))) {
          break;
        }

        currentDate = DateTime.parse(
          _calculateNextDate(
            currentDate.toIso8601String().substring(0, 10),
            template.frequency,
            template.intervalValue,
          ),
        );
      }
    }

    upcoming.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return upcoming;
  }
}

class RecurringGenerationResult {
  const RecurringGenerationResult({
    required this.templateId,
    required this.success,
    this.transactionId,
    this.nextGenerationDate,
    this.errorMessage,
  });

  final String templateId;
  final bool success;
  final String? transactionId;
  final String? nextGenerationDate;
  final String? errorMessage;
}

class UpcomingRecurringTransaction {
  const UpcomingRecurringTransaction({
    required this.templateId,
    required this.templateName,
    required this.transactionType,
    required this.scheduledDate,
  });

  final String templateId;
  final String templateName;
  final String transactionType;
  final String scheduledDate;
}
