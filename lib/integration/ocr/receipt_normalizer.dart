import '../import/import_result.dart';
import '../models/imported_transaction.dart';
import 'receipt_parser.dart';

class ReceiptNormalizer {
  const ReceiptNormalizer({
    this.defaultAccountId,
    this.defaultCategoryId,
  });

  final String? defaultAccountId;
  final String? defaultCategoryId;

  NormalizationResult normalize(ReceiptParsingResult parsingResult) {
    final errors = <ImportError>[];
    final warnings = <ImportWarning>[];
    ImportedTransaction? transaction;

    if (!parsingResult.success) {
      errors.add(ImportError(
        index: 0,
        message: 'Receipt parsing failed',
        field: 'parsing',
      ));
      return NormalizationResult(
        transaction: null,
        errors: errors,
        warnings: warnings,
      );
    }

    if (!parsingResult.hasValidDate) {
      warnings.add(ImportWarning(
        index: 0,
        message: 'Could not determine date from receipt',
        warningType: ImportWarningType.missingDate,
      ));
    }

    if (!parsingResult.hasValidAmount) {
      errors.add(ImportError(
        index: 0,
        message: 'Could not determine total amount from receipt',
        field: 'amount',
      ));
      return NormalizationResult(
        transaction: null,
        errors: errors,
        warnings: warnings,
      );
    }

    final description = _buildDescription(
      parsingResult.merchantName,
      parsingResult.lineItems,
    );

    final inferredType = _inferTransactionType(
      parsingResult.merchantName,
      description,
    );

    final categoryId = _inferCategory(
      parsingResult.merchantName,
      description,
    );

    transaction = ImportedTransaction(
      date: parsingResult.parsedDate ?? DateTime.now(),
      description: description,
      amount: parsingResult.totalAmount!,
      counterparty: parsingResult.merchantName,
      inferredType: inferredType,
      accountId: defaultAccountId,
      categoryId: categoryId ?? defaultCategoryId,
      importSource: 'receipt_ocr',
      confidence: parsingResult.confidence,
      metadata: {
        'rawText': parsingResult.rawText,
        'taxAmount': parsingResult.taxAmount,
        'tipAmount': parsingResult.tipAmount,
        'lineItems':
            parsingResult.lineItems?.map((item) => item.toJson()).toList(),
      },
    );

    if (parsingResult.hasWarnings) {
      for (final warning in parsingResult.warnings!) {
        warnings.add(ImportWarning(
          index: 0,
          message: warning,
          warningType: ImportWarningType.lowConfidence,
        ));
      }
    }

    if (parsingResult.confidence < 0.7) {
      warnings.add(ImportWarning(
        index: 0,
        message:
            'Low confidence in OCR results (${(parsingResult.confidence * 100).toStringAsFixed(0)}%)',
        warningType: ImportWarningType.lowConfidence,
      ));
    }

    return NormalizationResult(
      transaction: transaction,
      errors: errors,
      warnings: warnings,
    );
  }

  String _buildDescription(
      String? merchantName, List<ReceiptLineItem>? lineItems) {
    if (merchantName != null && merchantName.isNotEmpty) {
      return merchantName;
    }

    if (lineItems != null && lineItems.isNotEmpty) {
      final firstItem = lineItems.first.description;
      if (lineItems.length == 1) {
        return firstItem;
      }
      return '$firstItem 他${lineItems.length - 1}件';
    }

    return 'レシート';
  }

  InferredTransactionType _inferTransactionType(
    String? merchantName,
    String description,
  ) {
    final lowerMerchant = merchantName?.toLowerCase() ?? '';
    final lowerDesc = description.toLowerCase();

    if (lowerMerchant.contains('atm') ||
        lowerMerchant.contains('銀行') ||
        lowerMerchant.contains('bank')) {
      return InferredTransactionType.transfer;
    }

    if (lowerDesc.contains('給与') ||
        lowerDesc.contains('salary') ||
        lowerDesc.contains('income')) {
      return InferredTransactionType.income;
    }

    return InferredTransactionType.expense;
  }

  String? _inferCategory(String? merchantName, String description) {
    final text = '${merchantName ?? ''} ${description}'.toLowerCase();

    if (text.contains('restaurant') ||
        text.contains('食堂') ||
        text.contains('カフェ') ||
        text.contains('food')) {
      return 'expense:food';
    }

    if (text.contains('supermarket') ||
        text.contains(' grocery') ||
        text.contains('超市') ||
        text.contains(' grocery')) {
      return 'expense:food';
    }

    if (text.contains('gas') || text.contains('石油') || text.contains('加油站')) {
      return 'expense:transport';
    }

    if (text.contains('hospital') ||
        text.contains('药店') ||
        text.contains(' pharmacy')) {
      return 'expense:medical';
    }

    if (text.contains('electric') ||
        text.contains('electricity') ||
        text.contains('電気')) {
      return 'expense:utilities';
    }

    if (text.contains('hotel') || text.contains('旅馆')) {
      return 'expense:entertainment';
    }

    return null;
  }
}

class NormalizationResult {
  const NormalizationResult({
    required this.transaction,
    required this.errors,
    required this.warnings,
  });

  final ImportedTransaction? transaction;
  final List<ImportError> errors;
  final List<ImportWarning> warnings;

  bool get isSuccess => transaction != null && errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}
