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
    this.counterpartyId,
    this.externalRef,
    this.originalTransactionId,
    this.refundType,
    this.periodLockState = 'open',
  });

  final String transactionId;
  final String date;
  final String type;
  final String status;
  final String? description;
  final String? counterparty;
  final String? counterpartyId;
  final String? externalRef;
  final String? originalTransactionId;
  final String? refundType;
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
    String? counterpartyId,
    String? externalRef,
    String? originalTransactionId,
    String? refundType,
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
      counterpartyId: counterpartyId ?? this.counterpartyId,
      externalRef: externalRef ?? this.externalRef,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      refundType: refundType ?? this.refundType,
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
      'counterparty_id': counterpartyId,
      'external_ref': externalRef,
      'original_transaction_id': originalTransactionId,
      'refund_type': refundType,
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
      counterpartyId: row.readNullable<String>('counterparty_id'),
      externalRef: row.readNullable<String>('external_ref'),
      originalTransactionId:
          row.readNullable<String>('original_transaction_id'),
      refundType: row.readNullable<String>('refund_type'),
      periodLockState: row.read<String>('period_lock_state'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }

  bool get isRefund => originalTransactionId != null;
  bool get isFullRefund => refundType == 'full';
  bool get isPartialRefund => refundType == 'partial';
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

class ChoboPointsAccountRecord {
  const ChoboPointsAccountRecord({
    required this.pointsAccountId,
    required this.name,
    required this.pointsCurrency,
    required this.exchangeRate,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    this.isArchived = false,
  });

  final String pointsAccountId;
  final String name;
  final String pointsCurrency;
  final int exchangeRate;
  final bool isDefault;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  ChoboPointsAccountRecord copyWith({
    String? pointsAccountId,
    String? name,
    String? pointsCurrency,
    int? exchangeRate,
    bool? isDefault,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboPointsAccountRecord(
      pointsAccountId: pointsAccountId ?? this.pointsAccountId,
      name: name ?? this.name,
      pointsCurrency: pointsCurrency ?? this.pointsCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'points_account_id': pointsAccountId,
      'name': name,
      'points_currency': pointsCurrency,
      'exchange_rate': exchangeRate,
      'is_default': isDefault ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboPointsAccountRecord fromRow(QueryRow row) {
    return ChoboPointsAccountRecord(
      pointsAccountId: row.read<String>('points_account_id'),
      name: row.read<String>('name'),
      pointsCurrency: row.read<String>('points_currency'),
      exchangeRate: row.read<int>('exchange_rate'),
      isDefault: row.read<int>('is_default') == 1,
      isArchived: row.read<int>('is_archived') == 1,
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

class ChoboPointsTransactionRecord {
  const ChoboPointsTransactionRecord({
    required this.pointsTransactionId,
    required this.pointsAccountId,
    required this.direction,
    required this.pointsAmount,
    required this.occurredAt,
    required this.createdAt,
    this.transactionId,
    this.jpyValue = 0,
    this.description,
    this.expirationDate,
  });

  final String pointsTransactionId;
  final String pointsAccountId;
  final String? transactionId;
  final String direction;
  final int pointsAmount;
  final int jpyValue;
  final String? description;
  final String occurredAt;
  final String? expirationDate;
  final String createdAt;

  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(DateTime.parse(expirationDate!));
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    final expDate = DateTime.parse(expirationDate!);
    return expDate.isBefore(thirtyDaysFromNow) && !isExpired;
  }

  ChoboPointsTransactionRecord copyWith({
    String? pointsTransactionId,
    String? pointsAccountId,
    String? transactionId,
    String? direction,
    int? pointsAmount,
    int? jpyValue,
    String? description,
    String? occurredAt,
    String? expirationDate,
    String? createdAt,
  }) {
    return ChoboPointsTransactionRecord(
      pointsTransactionId: pointsTransactionId ?? this.pointsTransactionId,
      pointsAccountId: pointsAccountId ?? this.pointsAccountId,
      transactionId: transactionId ?? this.transactionId,
      direction: direction ?? this.direction,
      pointsAmount: pointsAmount ?? this.pointsAmount,
      jpyValue: jpyValue ?? this.jpyValue,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'points_transaction_id': pointsTransactionId,
      'points_account_id': pointsAccountId,
      'transaction_id': transactionId,
      'direction': direction,
      'points_amount': pointsAmount,
      'jpy_value': jpyValue,
      'description': description,
      'occurred_at': occurredAt,
      'expiration_date': expirationDate,
      'created_at': createdAt,
    };
  }

  static ChoboPointsTransactionRecord fromRow(QueryRow row) {
    return ChoboPointsTransactionRecord(
      pointsTransactionId: row.read<String>('points_transaction_id'),
      pointsAccountId: row.read<String>('points_account_id'),
      transactionId: row.readNullable<String>('transaction_id'),
      direction: row.read<String>('direction'),
      pointsAmount: row.read<int>('points_amount'),
      jpyValue: row.read<int>('jpy_value'),
      description: row.readNullable<String>('description'),
      occurredAt: row.read<String>('occurred_at'),
      expirationDate: row.readNullable<String>('expiration_date'),
      createdAt: row.read<String>('created_at'),
    );
  }
}

class ChoboPointsBalanceRecord {
  const ChoboPointsBalanceRecord({
    required this.pointsAccountId,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.totalExpired,
    required this.totalAdjusted,
    required this.currentBalance,
  });

  final String pointsAccountId;
  final int totalEarned;
  final int totalRedeemed;
  final int totalExpired;
  final int totalAdjusted;
  final int currentBalance;

  int get availableBalance =>
      totalEarned - totalRedeemed - totalExpired + totalAdjusted;
}

class ChoboRecurringTemplateRecord {
  const ChoboRecurringTemplateRecord({
    required this.templateId,
    required this.name,
    required this.transactionType,
    required this.frequency,
    required this.intervalValue,
    required this.startDate,
    required this.entriesTemplate,
    required this.createdAt,
    required this.updatedAt,
    this.endDate,
    this.nextGenerationDate,
    this.lastGeneratedTransactionId,
    this.isActive = true,
    this.autoPost = false,
  });

  final String templateId;
  final String name;
  final String transactionType;
  final String frequency;
  final int intervalValue;
  final String startDate;
  final String? endDate;
  final String? nextGenerationDate;
  final String? lastGeneratedTransactionId;
  final String entriesTemplate;
  final bool isActive;
  final bool autoPost;
  final String createdAt;
  final String updatedAt;

  ChoboRecurringTemplateRecord copyWith({
    String? templateId,
    String? name,
    String? transactionType,
    String? frequency,
    int? intervalValue,
    String? startDate,
    String? endDate,
    String? nextGenerationDate,
    String? lastGeneratedTransactionId,
    String? entriesTemplate,
    bool? isActive,
    bool? autoPost,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboRecurringTemplateRecord(
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      transactionType: transactionType ?? this.transactionType,
      frequency: frequency ?? this.frequency,
      intervalValue: intervalValue ?? this.intervalValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextGenerationDate: nextGenerationDate ?? this.nextGenerationDate,
      lastGeneratedTransactionId:
          lastGeneratedTransactionId ?? this.lastGeneratedTransactionId,
      entriesTemplate: entriesTemplate ?? this.entriesTemplate,
      isActive: isActive ?? this.isActive,
      autoPost: autoPost ?? this.autoPost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'template_id': templateId,
      'name': name,
      'transaction_type': transactionType,
      'frequency': frequency,
      'interval_value': intervalValue,
      'start_date': startDate,
      'end_date': endDate,
      'next_generation_date': nextGenerationDate,
      'last_generated_transaction_id': lastGeneratedTransactionId,
      'entries_template': entriesTemplate,
      'is_active': isActive ? 1 : 0,
      'auto_post': autoPost ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboRecurringTemplateRecord fromRow(QueryRow row) {
    return ChoboRecurringTemplateRecord(
      templateId: row.read<String>('template_id'),
      name: row.read<String>('name'),
      transactionType: row.read<String>('transaction_type'),
      frequency: row.read<String>('frequency'),
      intervalValue: row.read<int>('interval_value'),
      startDate: row.read<String>('start_date'),
      endDate: row.readNullable<String>('end_date'),
      nextGenerationDate: row.readNullable<String>('next_generation_date'),
      lastGeneratedTransactionId:
          row.readNullable<String>('last_generated_transaction_id'),
      entriesTemplate: row.read<String>('entries_template'),
      isActive: row.read<int>('is_active') == 1,
      autoPost: row.read<int>('auto_post') == 1,
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.parse(endDate!).isBefore(DateTime.now());
  }

  bool get shouldGenerate {
    if (!isActive) return false;
    if (isExpired) return false;
    if (nextGenerationDate == null) return true;
    return DateTime.parse(nextGenerationDate!).isBefore(DateTime.now()) ||
        DateTime.parse(nextGenerationDate!).isAtSameMomentAs(DateTime.now());
  }
}

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
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

class ChoboAppSettings {
  ChoboAppSettings._();

  static const String appLockEnabled = 'app_lock_enabled';
  static const String lockMode = 'lock_mode';
  static const String cacheDurationSeconds = 'cache_duration_seconds';
  static const String auditGranularity = 'audit_granularity';

  static const String lockModeBiometric = 'biometric';
  static const String lockModeNone = 'none';

  static const String auditGranularityMinimal = 'minimal';
  static const String auditGranularitySummary = 'summary';
  static const String auditGranularityFull = 'full';

  static const int defaultCacheDurationSeconds = 300;

  static const String terminologyMode = 'terminology_mode';

  static const String terminologyModeBasic = 'basic';
  static const String terminologyModeAdvanced = 'advanced';

  static const String defaultTerminologyMode = terminologyModeBasic;
}

class ChoboTagRecord {
  const ChoboTagRecord({
    required this.tagId,
    required this.name,
    this.color,
    required this.createdAt,
  });

  final String tagId;
  final String name;
  final String? color;
  final String createdAt;

  ChoboTagRecord copyWith({
    String? tagId,
    String? name,
    String? color,
    String? createdAt,
  }) {
    return ChoboTagRecord(
      tagId: tagId ?? this.tagId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'tag_id': tagId,
      'name': name,
      'color': color,
      'created_at': createdAt,
    };
  }

  static ChoboTagRecord fromRow(QueryRow row) {
    return ChoboTagRecord(
      tagId: row.read<String>('tag_id'),
      name: row.read<String>('name'),
      color: row.readNullable<String>('color'),
      createdAt: row.read<String>('created_at'),
    );
  }
}

class ChoboTransactionTagRecord {
  const ChoboTransactionTagRecord({
    required this.transactionId,
    required this.tagId,
  });

  final String transactionId;
  final String tagId;

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'transaction_id': transactionId,
      'tag_id': tagId,
    };
  }

  static ChoboTransactionTagRecord fromRow(QueryRow row) {
    return ChoboTransactionTagRecord(
      transactionId: row.read<String>('transaction_id'),
      tagId: row.read<String>('tag_id'),
    );
  }
}

class ChoboCounterpartyRecord {
  const ChoboCounterpartyRecord({
    required this.counterpartyId,
    required this.normalizedName,
    required this.rawName,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String counterpartyId;
  final String normalizedName;
  final String rawName;
  final String? metadata;
  final String createdAt;
  final String updatedAt;

  ChoboCounterpartyRecord copyWith({
    String? counterpartyId,
    String? normalizedName,
    String? rawName,
    String? metadata,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboCounterpartyRecord(
      counterpartyId: counterpartyId ?? this.counterpartyId,
      normalizedName: normalizedName ?? this.normalizedName,
      rawName: rawName ?? this.rawName,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'counterparty_id': counterpartyId,
      'normalized_name': normalizedName,
      'raw_name': rawName,
      'metadata': metadata,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboCounterpartyRecord fromRow(QueryRow row) {
    return ChoboCounterpartyRecord(
      counterpartyId: row.read<String>('counterparty_id'),
      normalizedName: row.read<String>('normalized_name'),
      rawName: row.read<String>('raw_name'),
      metadata: row.readNullable<String>('metadata'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

class ChoboBudgetRecord {
  const ChoboBudgetRecord({
    required this.budgetId,
    required this.accountId,
    required this.month,
    required this.amount,
    this.alertThresholdPercent = 80,
    required this.createdAt,
    required this.updatedAt,
  });

  final String budgetId;
  final String accountId;
  final String month;
  final int amount;
  final int alertThresholdPercent;
  final String createdAt;
  final String updatedAt;

  ChoboBudgetRecord copyWith({
    String? budgetId,
    String? accountId,
    String? month,
    int? amount,
    int? alertThresholdPercent,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboBudgetRecord(
      budgetId: budgetId ?? this.budgetId,
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      alertThresholdPercent:
          alertThresholdPercent ?? this.alertThresholdPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'budget_id': budgetId,
      'account_id': accountId,
      'month': month,
      'amount': amount,
      'alert_threshold_percent': alertThresholdPercent,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboBudgetRecord fromRow(QueryRow row) {
    return ChoboBudgetRecord(
      budgetId: row.read<String>('budget_id'),
      accountId: row.read<String>('account_id'),
      month: row.read<String>('month'),
      amount: row.read<int>('amount'),
      alertThresholdPercent: row.read<int>('alert_threshold_percent'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

class ChoboTransactionTemplateRecord {
  const ChoboTransactionTemplateRecord({
    required this.templateId,
    required this.name,
    required this.transactionType,
    required this.entriesTemplate,
    this.defaultDescription,
    this.usageCount = 0,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String templateId;
  final String name;
  final String transactionType;
  final String entriesTemplate;
  final String? defaultDescription;
  final int usageCount;
  final String? lastUsedAt;
  final String createdAt;
  final String updatedAt;

  ChoboTransactionTemplateRecord copyWith({
    String? templateId,
    String? name,
    String? transactionType,
    String? entriesTemplate,
    String? defaultDescription,
    int? usageCount,
    String? lastUsedAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return ChoboTransactionTemplateRecord(
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      transactionType: transactionType ?? this.transactionType,
      entriesTemplate: entriesTemplate ?? this.entriesTemplate,
      defaultDescription: defaultDescription ?? this.defaultDescription,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'template_id': templateId,
      'name': name,
      'transaction_type': transactionType,
      'entries_template': entriesTemplate,
      'default_description': defaultDescription,
      'usage_count': usageCount,
      'last_used_at': lastUsedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ChoboTransactionTemplateRecord fromRow(QueryRow row) {
    return ChoboTransactionTemplateRecord(
      templateId: row.read<String>('template_id'),
      name: row.read<String>('name'),
      transactionType: row.read<String>('transaction_type'),
      entriesTemplate: row.read<String>('entries_template'),
      defaultDescription: row.readNullable<String>('default_description'),
      usageCount: row.read<int>('usage_count'),
      lastUsedAt: row.readNullable<String>('last_used_at'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }
}

enum SelectionFieldType { account, counterparty, description, tag }

class ChoboRecentSelectionRecord {
  const ChoboRecentSelectionRecord({
    required this.selectionId,
    required this.fieldType,
    required this.fieldValue,
    this.transactionType,
    this.frequency = 1,
    required this.lastSelectedAt,
    required this.createdAt,
  });

  final String selectionId;
  final SelectionFieldType fieldType;
  final String fieldValue;
  final String? transactionType;
  final int frequency;
  final String lastSelectedAt;
  final String createdAt;

  ChoboRecentSelectionRecord copyWith({
    String? selectionId,
    SelectionFieldType? fieldType,
    String? fieldValue,
    String? transactionType,
    int? frequency,
    String? lastSelectedAt,
    String? createdAt,
  }) {
    return ChoboRecentSelectionRecord(
      selectionId: selectionId ?? this.selectionId,
      fieldType: fieldType ?? this.fieldType,
      fieldValue: fieldValue ?? this.fieldValue,
      transactionType: transactionType ?? this.transactionType,
      frequency: frequency ?? this.frequency,
      lastSelectedAt: lastSelectedAt ?? this.lastSelectedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'selection_id': selectionId,
      'field_type': fieldType.name,
      'field_value': fieldValue,
      'transaction_type': transactionType,
      'frequency': frequency,
      'last_selected_at': lastSelectedAt,
      'created_at': createdAt,
    };
  }

  static ChoboRecentSelectionRecord fromRow(QueryRow row) {
    return ChoboRecentSelectionRecord(
      selectionId: row.read<String>('selection_id'),
      fieldType: SelectionFieldType.values.firstWhere(
        (e) => e.name == row.read<String>('field_type'),
      ),
      fieldValue: row.read<String>('field_value'),
      transactionType: row.readNullable<String>('transaction_type'),
      frequency: row.read<int>('frequency'),
      lastSelectedAt: row.read<String>('last_selected_at'),
      createdAt: row.read<String>('created_at'),
    );
  }
}

class ChoboBudgetAlertRecord {
  const ChoboBudgetAlertRecord({
    required this.alertId,
    required this.budgetId,
    required this.triggeredAt,
    required this.actualAmount,
    required this.budgetAmount,
    required this.thresholdPercent,
    this.notified = false,
  });

  final String alertId;
  final String budgetId;
  final String triggeredAt;
  final int actualAmount;
  final int budgetAmount;
  final int thresholdPercent;
  final bool notified;

  ChoboBudgetAlertRecord copyWith({
    String? alertId,
    String? budgetId,
    String? triggeredAt,
    int? actualAmount,
    int? budgetAmount,
    int? thresholdPercent,
    bool? notified,
  }) {
    return ChoboBudgetAlertRecord(
      alertId: alertId ?? this.alertId,
      budgetId: budgetId ?? this.budgetId,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      actualAmount: actualAmount ?? this.actualAmount,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
      notified: notified ?? this.notified,
    );
  }

  Map<String, Object?> toDatabaseJson() {
    return <String, Object?>{
      'alert_id': alertId,
      'budget_id': budgetId,
      'triggered_at': triggeredAt,
      'actual_amount': actualAmount,
      'budget_amount': budgetAmount,
      'threshold_percent': thresholdPercent,
      'notified': notified ? 1 : 0,
    };
  }

  static ChoboBudgetAlertRecord fromRow(QueryRow row) {
    return ChoboBudgetAlertRecord(
      alertId: row.read<String>('alert_id'),
      budgetId: row.read<String>('budget_id'),
      triggeredAt: row.read<String>('triggered_at'),
      actualAmount: row.read<int>('actual_amount'),
      budgetAmount: row.read<int>('budget_amount'),
      thresholdPercent: row.read<int>('threshold_percent'),
      notified: row.read<int>('notified') == 1,
    );
  }
}
