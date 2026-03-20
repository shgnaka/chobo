enum AuditGranularity {
  minimal,
  summary,
  full,
}

enum AuditEventType {
  transactionCreated,
  transactionUpdated,
  transactionVoided,
  accountCreated,
  accountUpdated,
  accountArchived,
  accountReconciled,
  periodClosed,
  backupCreated,
  backupRestored,
  settingChanged,
  adjustmentMade,
}

class AuditEventTemplate {
  const AuditEventTemplate({
    required this.eventType,
    required this.targetIdField,
    required this.payloadFields,
  });

  final AuditEventType eventType;
  final String targetIdField;
  final List<String> payloadFields;
}

class AuditPolicy {
  AuditPolicy._();

  static const AuditGranularity defaultGranularity = AuditGranularity.summary;

  static const Map<AuditGranularity, Set<String>> minimalEvents =
      <AuditGranularity, Set<String>>{
    AuditGranularity.minimal: <String>{
      'transaction_created',
      'transaction_updated',
      'transaction_voided',
      'account_created',
      'account_updated',
      'account_archived',
      'account_reconciled',
      'period_closed',
      'backup_created',
      'backup_restored',
      'setting_changed',
      'adjustment_made',
    },
  };

  static const Map<AuditEventType, AuditEventTemplate> templates =
      <AuditEventType, AuditEventTemplate>{
    AuditEventType.transactionCreated: AuditEventTemplate(
      eventType: AuditEventType.transactionCreated,
      targetIdField: 'transaction_id',
      payloadFields: <String>['date', 'type', 'total_amount'],
    ),
    AuditEventType.transactionUpdated: AuditEventTemplate(
      eventType: AuditEventType.transactionUpdated,
      targetIdField: 'transaction_id',
      payloadFields: <String>['changed_fields'],
    ),
    AuditEventType.transactionVoided: AuditEventTemplate(
      eventType: AuditEventType.transactionVoided,
      targetIdField: 'transaction_id',
      payloadFields: <String>['original_date', 'original_type', 'total_amount'],
    ),
    AuditEventType.accountCreated: AuditEventTemplate(
      eventType: AuditEventType.accountCreated,
      targetIdField: 'account_id',
      payloadFields: <String>['name', 'kind'],
    ),
    AuditEventType.accountUpdated: AuditEventTemplate(
      eventType: AuditEventType.accountUpdated,
      targetIdField: 'account_id',
      payloadFields: <String>['changed_fields'],
    ),
    AuditEventType.accountArchived: AuditEventTemplate(
      eventType: AuditEventType.accountArchived,
      targetIdField: 'account_id',
      payloadFields: <String>['name'],
    ),
    AuditEventType.accountReconciled: AuditEventTemplate(
      eventType: AuditEventType.accountReconciled,
      targetIdField: 'account_id',
      payloadFields: <String>['book_balance', 'actual_balance', 'diff'],
    ),
    AuditEventType.periodClosed: AuditEventTemplate(
      eventType: AuditEventType.periodClosed,
      targetIdField: 'period',
      payloadFields: <String>['transaction_count'],
    ),
    AuditEventType.backupCreated: AuditEventTemplate(
      eventType: AuditEventType.backupCreated,
      targetIdField: 'timestamp',
      payloadFields: <String>['size'],
    ),
    AuditEventType.backupRestored: AuditEventTemplate(
      eventType: AuditEventType.backupRestored,
      targetIdField: 'timestamp',
      payloadFields: <String>['size'],
    ),
    AuditEventType.settingChanged: AuditEventTemplate(
      eventType: AuditEventType.settingChanged,
      targetIdField: 'setting_key',
      payloadFields: <String>['previous_value', 'new_value'],
    ),
    AuditEventType.adjustmentMade: AuditEventTemplate(
      eventType: AuditEventType.adjustmentMade,
      targetIdField: 'account_id',
      payloadFields: <String>['amount', 'reason'],
    ),
  };

  static String eventTypeToString(AuditEventType type) {
    switch (type) {
      case AuditEventType.transactionCreated:
        return 'transaction_created';
      case AuditEventType.transactionUpdated:
        return 'transaction_updated';
      case AuditEventType.transactionVoided:
        return 'transaction_voided';
      case AuditEventType.accountCreated:
        return 'account_created';
      case AuditEventType.accountUpdated:
        return 'account_updated';
      case AuditEventType.accountArchived:
        return 'account_archived';
      case AuditEventType.accountReconciled:
        return 'account_reconciled';
      case AuditEventType.periodClosed:
        return 'period_closed';
      case AuditEventType.backupCreated:
        return 'backup_created';
      case AuditEventType.backupRestored:
        return 'backup_restored';
      case AuditEventType.settingChanged:
        return 'setting_changed';
      case AuditEventType.adjustmentMade:
        return 'adjustment_made';
    }
  }
}
