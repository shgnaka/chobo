class ImportedTransaction {
  const ImportedTransaction({
    this.externalId,
    required this.date,
    required this.description,
    required this.amount,
    this.counterparty,
    this.inferredType,
    this.accountId,
    this.categoryId,
    this.importSource,
    this.confidence = 1.0,
    this.metadata,
  });

  final String? externalId;
  final DateTime date;
  final String description;
  final int amount;
  final String? counterparty;
  final InferredTransactionType? inferredType;
  final String? accountId;
  final String? categoryId;
  final String? importSource;
  final double confidence;
  final Map<String, dynamic>? metadata;

  ImportedTransaction copyWith({
    String? externalId,
    DateTime? date,
    String? description,
    int? amount,
    String? counterparty,
    InferredTransactionType? inferredType,
    String? accountId,
    String? categoryId,
    String? importSource,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return ImportedTransaction(
      externalId: externalId ?? this.externalId,
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      counterparty: counterparty ?? this.counterparty,
      inferredType: inferredType ?? this.inferredType,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      importSource: importSource ?? this.importSource,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'externalId': externalId,
      'date': date.toIso8601String(),
      'description': description,
      'amount': amount,
      'counterparty': counterparty,
      'inferredType': inferredType?.name,
      'accountId': accountId,
      'categoryId': categoryId,
      'importSource': importSource,
      'confidence': confidence,
      'metadata': metadata,
    };
  }

  static ImportedTransaction fromJson(Map<String, dynamic> json) {
    return ImportedTransaction(
      externalId: json['externalId'] as String?,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      amount: json['amount'] as int,
      counterparty: json['counterparty'] as String?,
      inferredType: json['inferredType'] != null
          ? InferredTransactionType.values.firstWhere(
              (e) => e.name == json['inferredType'],
            )
          : null,
      accountId: json['accountId'] as String?,
      categoryId: json['categoryId'] as String?,
      importSource: json['importSource'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

enum InferredTransactionType {
  income,
  expense,
  transfer,
  creditExpense,
  liabilityPayment,
}

extension InferredTransactionTypeExtension on InferredTransactionType {
  String get displayName {
    switch (this) {
      case InferredTransactionType.income:
        return 'Income';
      case InferredTransactionType.expense:
        return 'Expense';
      case InferredTransactionType.transfer:
        return 'Transfer';
      case InferredTransactionType.creditExpense:
        return 'Credit Card';
      case InferredTransactionType.liabilityPayment:
        return 'Payment';
    }
  }
}
