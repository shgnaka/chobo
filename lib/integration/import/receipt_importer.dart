import 'dart:typed_data';

import '../import/import_result.dart';
import '../import/transaction_importer.dart';
import '../models/imported_transaction.dart';
import '../ocr/receipt_normalizer.dart';
import '../ocr/receipt_ocr_service.dart';
import '../ocr/receipt_parser.dart';

class ReceiptImporter implements TransactionImporter {
  ReceiptImporter({
    ReceiptOcrService? ocrService,
    ReceiptNormalizer? normalizer,
    String? defaultAccountId,
    String? defaultCategoryId,
  })  : _ocrService = ocrService ?? ReceiptOcrService(),
        _normalizer = normalizer ??
            ReceiptNormalizer(
              defaultAccountId: defaultAccountId,
              defaultCategoryId: defaultCategoryId,
            );

  final ReceiptOcrService _ocrService;
  final ReceiptNormalizer _normalizer;

  @override
  String get name => 'Receipt Importer';

  @override
  String get description => 'Import transactions from receipt images';

  @override
  bool canHandle(ImportSource source) {
    return source.type == ImportSourceType.receiptImage ||
        source.type == ImportSourceType.receiptText;
  }

  @override
  Future<ImportPreview> preview(ImportSource source) async {
    final result = await _processSource(source);

    if (!result.success || result.transaction == null) {
      return ImportPreview(
        transactions: [],
        duplicateCount: 0,
        warnings: result.warnings
            .map((w) => ImportWarning(
                  index: 0,
                  message: w,
                  warningType: ImportWarningType.lowConfidence,
                ))
            .toList(),
        errors: result.errors
            .map((e) => ImportError(
                  index: 0,
                  message: e,
                ))
            .toList(),
      );
    }

    return ImportPreview(
      transactions: [result.transaction!],
      duplicateCount: 0,
      warnings: result.warnings
          .map((w) => ImportWarning(
                index: 0,
                message: w,
                warningType: ImportWarningType.lowConfidence,
              ))
          .toList(),
      errors: [],
    );
  }

  @override
  Future<ImportResult> import(ImportSource source) async {
    final result = await _processSource(source);

    if (!result.success || result.transaction == null) {
      return ImportResult(
        total: 0,
        success: 0,
        skipped: 0,
        failed: 0,
        duplicateCount: 0,
        importedTransactions: [],
        errors: result.errors
            .map((e) => ImportError(
                  index: 0,
                  message: e,
                ))
            .toList(),
        warnings: result.warnings
            .map((w) => ImportWarning(
                  index: 0,
                  message: w,
                  warningType: ImportWarningType.lowConfidence,
                ))
            .toList(),
      );
    }

    return ImportResult(
      total: 1,
      success: 1,
      skipped: 0,
      failed: 0,
      duplicateCount: 0,
      importedTransactions: [result.transaction!],
      errors: [],
      warnings: result.warnings
          .map((w) => ImportWarning(
                index: 0,
                message: w,
                warningType: ImportWarningType.lowConfidence,
              ))
          .toList(),
    );
  }

  Future<_ReceiptProcessResult> _processSource(ImportSource source) async {
    if (source.type == ImportSourceType.receiptImage &&
        source.fileData != null) {
      return _processImage(source.fileData!);
    }

    if (source.type == ImportSourceType.receiptText && source.rawText != null) {
      return _processText(source.rawText!);
    }

    if (source.type == ImportSourceType.receiptImage &&
        source.rawText != null) {
      return _processText(source.rawText!);
    }

    return _ReceiptProcessResult(
      success: false,
      transaction: null,
      errors: ['No image data or text provided'],
      warnings: [],
    );
  }

  Future<_ReceiptProcessResult> _processImage(Uint8List imageData) async {
    final ocrResult = await _ocrService.processReceipt(imageData);

    if (!ocrResult.success) {
      return _ReceiptProcessResult(
        success: false,
        transaction: null,
        errors: ocrResult.errors,
        warnings: ocrResult.warnings,
      );
    }

    final normalizationResult = _normalizer.normalize(
      ReceiptParsingResult(
        success: true,
        parsedDate: DateTime.now(),
        totalAmount: ocrResult.transaction?.amount ?? 0,
        description: ocrResult.transaction?.description ?? 'Receipt',
        rawText: ocrResult.rawText,
        confidence: ocrResult.parsingConfidence,
      ),
    );

    return _ReceiptProcessResult(
      success: normalizationResult.isSuccess,
      transaction: normalizationResult.transaction,
      errors: normalizationResult.errors.map((e) => e.message).toList(),
      warnings: normalizationResult.warnings.map((w) => w.message).toList(),
    );
  }

  Future<_ReceiptProcessResult> _processText(String text) async {
    final ocrResult = await _ocrService.processReceiptText(text);

    if (!ocrResult.success) {
      return _ReceiptProcessResult(
        success: false,
        transaction: null,
        errors: ocrResult.errors,
        warnings: ocrResult.warnings,
      );
    }

    final normalizationResult = _normalizer.normalize(
      ReceiptParsingResult(
        success: true,
        parsedDate: ocrResult.transaction?.date ?? DateTime.now(),
        totalAmount: ocrResult.transaction?.amount ?? 0,
        description: ocrResult.transaction?.description ?? 'Receipt',
        rawText: ocrResult.rawText,
        confidence: ocrResult.parsingConfidence,
      ),
    );

    return _ReceiptProcessResult(
      success: normalizationResult.isSuccess,
      transaction: normalizationResult.transaction,
      errors: normalizationResult.errors.map((e) => e.message).toList(),
      warnings: normalizationResult.warnings.map((w) => w.message).toList(),
    );
  }
}

class _ReceiptProcessResult {
  const _ReceiptProcessResult({
    required this.success,
    required this.transaction,
    required this.errors,
    required this.warnings,
  });

  final bool success;
  final ImportedTransaction? transaction;
  final List<String> errors;
  final List<String> warnings;
}
