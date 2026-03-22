import 'dart:typed_data';

import 'receipt_normalizer.dart';
import 'receipt_parser.dart';
import 'mock_receipt_parser.dart';

class ReceiptOcrService {
  ReceiptOcrService({
    ReceiptParser? parser,
    ReceiptNormalizer? normalizer,
  })  : _parser = parser ?? const MockReceiptParser(),
        _normalizer = normalizer ?? const ReceiptNormalizer();

  final ReceiptParser _parser;
  final ReceiptNormalizer _normalizer;

  ReceiptParser get parser => _parser;

  Future<ReceiptOcrResult> processReceipt(Uint8List imageData) async {
    final parsingResult = await _parser.parse(imageData);
    return _processResult(parsingResult);
  }

  Future<ReceiptOcrResult> processReceiptText(String text) async {
    final parsingResult = await _parser.parseFromText(text);
    return _processResult(parsingResult);
  }

  ReceiptOcrResult processReceiptSync(Uint8List imageData) {
    final parsingResult = _parser.parse(imageData);
    return _processResultSync(parsingResult);
  }

  ReceiptOcrResult processReceiptTextSync(String text) {
    final parsingResult = _parser.parseFromText(text);
    return _processResultSync(parsingResult);
  }

  Future<ReceiptOcrResult> _processResult(
    ReceiptParsingResult parsingResult,
  ) async {
    final normalizationResult = _normalizer.normalize(parsingResult);

    return ReceiptOcrResult(
      success: normalizationResult.isSuccess,
      transaction: normalizationResult.transaction,
      parsingConfidence: parsingResult.confidence,
      rawText: parsingResult.rawText,
      errors: [
        ...parsingResult.errors ?? [],
        ...normalizationResult.errors.map((e) => e.message),
      ],
      warnings: [
        ...normalizationResult.warnings.map((w) => w.message),
      ],
      hasLowConfidence: parsingResult.confidence < 0.7,
    );
  }

  ReceiptOcrResult _processResultSync(
    Future<ReceiptParsingResult> parsingResultFuture,
  ) {
    final result = _normalizer.normalize(
      ReceiptParsingResult(
        success: false,
        errors: ['Sync processing not supported'],
      ),
    );

    return ReceiptOcrResult(
      success: false,
      transaction: null,
      parsingConfidence: 0.0,
      rawText: null,
      errors: ['This method requires async processing'],
      warnings: [],
      hasLowConfidence: true,
    );
  }
}

class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.success,
    required this.transaction,
    required this.parsingConfidence,
    required this.rawText,
    required this.errors,
    required this.warnings,
    required this.hasLowConfidence,
  });

  final bool success;
  final dynamic transaction;
  final double parsingConfidence;
  final String? rawText;
  final List<String> errors;
  final List<String> warnings;
  final bool hasLowConfidence;

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get needsReview => hasErrors || hasLowConfidence;
}
