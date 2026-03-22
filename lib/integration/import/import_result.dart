import '../models/imported_transaction.dart';

class ImportResult {
  const ImportResult({
    required this.total,
    required this.success,
    required this.skipped,
    required this.failed,
    required this.duplicateCount,
    required this.importedTransactions,
    required this.errors,
    required this.warnings,
  });

  final int total;
  final int success;
  final int skipped;
  final int failed;
  final int duplicateCount;
  final List<ImportedTransaction> importedTransactions;
  final List<ImportError> errors;
  final List<ImportWarning> warnings;

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get isFullySuccessful => hasErrors == false && skipped == 0;

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'success': success,
      'skipped': skipped,
      'failed': failed,
      'errors': errors.map((e) => e.toJson()).toList(),
      'warnings': warnings.map((w) => w.toJson()).toList(),
    };
  }
}

class ImportPreview {
  const ImportPreview({
    required this.transactions,
    required this.duplicateCount,
    required this.warnings,
    required this.errors,
  });

  final List<ImportedTransaction> transactions;
  final int duplicateCount;
  final List<ImportWarning> warnings;
  final List<ImportError> errors;

  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;
  int get importableCount => transactions.length - duplicateCount;
}

class ImportError {
  const ImportError({
    required this.index,
    required this.message,
    this.field,
    this.row,
  });

  final int index;
  final String message;
  final String? field;
  final Map<String, dynamic>? row;

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      'field': field,
      'row': row,
    };
  }
}

class ImportWarning {
  const ImportWarning({
    required this.index,
    required this.message,
    this.warningType,
    this.row,
  });

  final int index;
  final String message;
  final ImportWarningType? warningType;
  final Map<String, dynamic>? row;

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      'warningType': warningType?.name,
      'row': row,
    };
  }
}

enum ImportWarningType {
  duplicate,
  lowConfidence,
  missingDate,
  missingAmount,
  unusualFormat,
}

class ImportStatistics {
  const ImportStatistics({
    required this.totalProcessed,
    required this.successfulImports,
    required this.duplicatesSkipped,
    required this.failedImports,
    required this.duration,
  });

  final int totalProcessed;
  final int successfulImports;
  final int duplicatesSkipped;
  final int failedImports;
  final Duration duration;

  double get successRate =>
      totalProcessed > 0 ? successfulImports / totalProcessed : 0.0;
}
