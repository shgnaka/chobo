import 'package:drift/drift.dart';

class ChoboAccountRecord {
  const ChoboAccountRecord({
    required this.accountId,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.currency = 'JPY',
    this.parentAccountId,
    this.isDefault = false,
    this.isArchived = false,
  });

  final String accountId;
  final String kind;
  final String name;
  final String currency;
  final String? parentAccountId;
  final bool isDefault;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  ChoboAccountRecord copyWith({
    String? accountId,
    String? kind,
    String? name,
    String? currency,
    String? parentAccountId,
    bool? isDefault,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboAccountRecord(
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      parentAccountId: parentAccountId ?? this.parentAccountId,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'account_id': accountId,
      'kind': kind,
      'name': name,
      'currency': currency,
      'parent_account_id': parentAccountId,
      'is_default': isDefault ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboAccountRecord fromRow(QueryRow row) {
    return ChoboAccountRecord(
      accountId: row.read<String>('account_id'),
      kind: row.read<String>('kind'),
      name: row.read<String>('name'),
      currency: row.read<String>('currency'),
      parentAccountId: row.readNullable<String>('parent_account_id'),
      isDefault: row.read<int>('is_default') == 1,
      isArchived: row.read<int>('is_archived') == 1,
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

class ChoboTransactionRecord {
  const ChoboTransactionRecord({
    required this.transactionId,
    required this.date,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.counterparty,
    this.externalRef,
    this.periodLockState = 'open',
  });

  final String transactionId;
  final String date;
  final String type;
  final String status;
  final String? description;
  final String? counterparty;
  final String? externalRef;
  final String periodLockState;
  final String createdAt;
  final String updatedAt;

  ChoboTransactionRecord copyWith({
    String? transactionId,
    String? date,
    String? type,
    String? status,
    String? description,
    String? counterparty,
    String? externalRef,
    String? periodLockState,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboTransactionRecord(
      transactionId: transactionId ?? this.transactionId,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      counterparty: counterparty ?? this.counterparty,
      externalRef: externalRef ?? this.externalRef,
      periodLockState: periodLockState ?? this.periodLockState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'transaction_id': transactionId,
      'date': date,
      'type': type,
      'status': status,
      'description': description,
      'counterparty': counterparty,
      'external_ref': externalRef,
      'period_lock_state': periodLockState,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboTransactionRecord fromRow(QueryRow row) {
    return ChoboTransactionRecord(
      transactionId: row.read<String>('transaction_id'),
      date: row.read<String>('date'),
      type: row.read<String>('type'),
      status: row.read<String>('status'),
      description: row.readNullable<String>('description'),
      counterparty: row.readNullable<String>('counterparty'),
      externalRef: row.readNullable<String>('external_ref'),
      periodLockState: row.read<String>('period_lock_state'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

class ChoboEntryRecord {
  const ChoboEntryRecord({
    required this.entryId,
    required this.transactionId,
    required this.accountId,
    required this.direction,
    required this.amount,
    this.memo,
  });

  final String entryId;
  final String transactionId;
  final String accountId;
  final String direction;
  final int amount;
  final String? memo;

  ChoboEntryRecord copyWith({
    String? entryId,
    String? transactionId,
    String? accountId,
    String? direction,
    int? amount,
    String? memo,
  }) {
    return ChoboEntryRecord(
      entryId: entryId ?? this.entryId,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'entry_id': entryId,
      'transaction_id': transactionId,
      'account_id': accountId,
      'direction': direction,
      'amount': amount,
      'memo': memo,
    };
  }

  static ChoboEntryRecord fromRow(QueryRow row) {
    return ChoboEntryRecord(
      entryId: row.read<String>('entry_id'),
      transactionId: row.read<String>('transaction_id'),
      accountId: row.read<String>('account_id'),
      direction: row.read<String>('direction'),
      amount: row.read<int>('amount'),
      memo: row.readNullable<String>('memo'),
    );
  }
}

class ChoboMonthlySummaryRecord {
  ChoboMonthlySummaryRecord({
    required this.month,
    required this.assetsStart,
    required this.assetsEnd,
    required this.liabilitiesStart,
    required this.liabilitiesEnd,
    required this.netAssetsStart,
    required this.netAssetsEnd,
    required Map<String, int> expenseTotals,
    required Map<String, int> incomeTotals,
    required Map<String, int> transferTotals,
    required this.cashOutExpenses,
    required this.accruedExpenses,
    required this.liabilityDue,
    required this.cardPayment,
  })  : expenseTotals = Map<String, int>.unmodifiable(expenseTotals),
        incomeTotals = Map<String, int>.unmodifiable(incomeTotals),
        transferTotals = Map<String, int>.unmodifiable(transferTotals);

  final String month;
  final int assetsStart;
  final int assetsEnd;
  final int liabilitiesStart;
  final int liabilitiesEnd;
  final int netAssetsStart;
  final int netAssetsEnd;
  final Map<String, int> expenseTotals;
  final Map<String, int> incomeTotals;
  final Map<String, int> transferTotals;
  final int cashOutExpenses;
  final int accruedExpenses;
  final int liabilityDue;
  final int cardPayment;
}

class ChoboClosureRecord {
  const ChoboClosureRecord({
    required this.closureId,
    required this.startDate,
    required this.endDate,
    required this.closedAt,
    this.note,
  });

  final String closureId;
  final String startDate;
  final String endDate;
  final String closedAt;
  final String? note;

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'closure_id': closureId,
      'start_date': startDate,
      'end_date': endDate,
      'closed_at': closedAt,
      'note': note,
    };
  }

  static ChoboClosureRecord fromRow(QueryRow row) {
    return ChoboClosureRecord(
      closureId: row.read<String>('closure_id'),
      startDate: row.read<String>('start_date'),
      endDate: row.read<String>('end_date'),
      closedAt: row.read<String>('closed_at'),
      note: row.readNullable<String>('note'),
    );
  }
}

class ChoboSettingRecord {
  const ChoboSettingRecord({
    required this.settingKey,
    required this.settingValue,
  });

  final String settingKey;
  final String settingValue;

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'setting_key': settingKey,
      'setting_value': settingValue,
    };
  }

  static ChoboSettingRecord fromRow(QueryRow row) {
    return ChoboSettingRecord(
      settingKey: row.read<String>('setting_key'),
      settingValue: row.read<String>('setting_value'),
    );
  }
}

class ChoboAuditEventRecord {
  const ChoboAuditEventRecord({
    required this.auditEventId,
    required this.eventType,
    required this.targetId,
    required this.payload,
    required this.createdAt,
  });

  final String auditEventId;
  final String eventType;
  final String targetId;
  final String payload;
  final String createdAt;

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'audit_event_id': auditEventId,
      'event_type': eventType,
      'target_id': targetId,
      'payload': payload,
      'created_at': createdAt,
    };
  }

  static ChoboAuditEventRecord fromRow(QueryRow row) {
    return ChoboAuditEventRecord(
      auditEventId: row.read<String>('audit_event_id'),
      eventType: row.read<String>('event_type'),
      targetId: row.read<String>('target_id'),
      payload: row.read<String>('payload'),
      createdAt: row.read<String>('created_at'),
    );
  }
}

class ChoboStandardAccountDefinition {
  const ChoboStandardAccountDefinition({
    required this.accountId,
    required this.kind,
    required this.displayName,
    this.currency = 'JPY',
  });

  final String accountId;
  final String kind;
  final String displayName;
  final String currency;
}

class ChoboStandardAccountSeed {
  const ChoboStandardAccountSeed(this.definition);

  final ChoboStandardAccountDefinition definition;

  ChoboAccountRecord toAccountRecord(String timestamp) {
    return ChoboAccountRecord(
      accountId: definition.accountId,
      kind: definition.kind,
      name: definition.displayName,
      currency: definition.currency,
      isDefault: true,
      isArchived: false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
