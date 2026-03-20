import '../data/repository/audit_event_repository.dart';
import 'audit_policy.dart';

class AuditEventFactory {
  AuditEventFactory(this._auditEventRepository);

  final AuditEventRepository _auditEventRepository;

  Future<void> recordTransactionCreated({
    required String transactionId,
    required String date,
    required String type,
    required int totalAmount,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType:
          AuditPolicy.eventTypeToString(AuditEventType.transactionCreated),
      targetId: transactionId,
      payload: <String, Object?>{
        'date': date,
        'type': type,
        'total_amount': totalAmount,
      },
    );
  }

  Future<void> recordTransactionUpdated({
    required String transactionId,
    required List<String> changedFields,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType:
          AuditPolicy.eventTypeToString(AuditEventType.transactionUpdated),
      targetId: transactionId,
      payload: <String, Object?>{
        'changed_fields': changedFields,
      },
    );
  }

  Future<void> recordTransactionVoided({
    required String transactionId,
    required String originalDate,
    required String originalType,
    required int totalAmount,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType:
          AuditPolicy.eventTypeToString(AuditEventType.transactionVoided),
      targetId: transactionId,
      payload: <String, Object?>{
        'original_date': originalDate,
        'original_type': originalType,
        'total_amount': totalAmount,
      },
    );
  }

  Future<void> recordAccountCreated({
    required String accountId,
    required String name,
    required String kind,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.accountCreated),
      targetId: accountId,
      payload: <String, Object?>{
        'name': name,
        'kind': kind,
      },
    );
  }

  Future<void> recordAccountUpdated({
    required String accountId,
    required List<String> changedFields,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.accountUpdated),
      targetId: accountId,
      payload: <String, Object?>{
        'changed_fields': changedFields,
      },
    );
  }

  Future<void> recordAccountArchived({
    required String accountId,
    required String name,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.accountArchived),
      targetId: accountId,
      payload: <String, Object?>{
        'name': name,
      },
    );
  }

  Future<void> recordAccountReconciled({
    required String accountId,
    required int bookBalance,
    required int actualBalance,
    required int diff,
  }) async {
    final eventId = _generateId();
    await _auditEventRepository.recordJsonEvent(
      auditEventId: eventId,
      eventType:
          AuditPolicy.eventTypeToString(AuditEventType.accountReconciled),
      targetId: accountId,
      payload: <String, Object?>{
        'book_balance': bookBalance,
        'actual_balance': actualBalance,
        'diff': diff,
      },
    );
  }

  String generateId() => _generateId();

  Future<void> recordPeriodClosed({
    required String period,
    required int transactionCount,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.periodClosed),
      targetId: period,
      payload: <String, Object?>{
        'transaction_count': transactionCount,
      },
    );
  }

  Future<void> recordBackupCreated({
    required int size,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.backupCreated),
      targetId: timestamp,
      payload: <String, Object?>{
        'size': size,
      },
    );
  }

  Future<void> recordBackupRestored({
    required int size,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.backupRestored),
      targetId: timestamp,
      payload: <String, Object?>{
        'size': size,
      },
    );
  }

  Future<void> recordSettingChanged({
    required String settingKey,
    String? previousValue,
    String? newValue,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.settingChanged),
      targetId: settingKey,
      payload: <String, Object?>{
        'previous_value': previousValue,
        'new_value': newValue,
      },
    );
  }

  Future<void> recordAdjustmentMade({
    required String accountId,
    required int amount,
    required String reason,
  }) async {
    await _auditEventRepository.recordJsonEvent(
      auditEventId: _generateId(),
      eventType: AuditPolicy.eventTypeToString(AuditEventType.adjustmentMade),
      targetId: accountId,
      payload: <String, Object?>{
        'amount': amount,
        'reason': reason,
      },
    );
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(
      length,
      (index) => chars[(random + index * 7) % chars.length],
    ).join();
  }
}
