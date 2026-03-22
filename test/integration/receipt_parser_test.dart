import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chobo/integration/integration.dart';

void main() {
  group('MockReceiptParser', () {
    test('returns successful result for image', () async {
      const parser = MockReceiptParser();
      final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      final result = await parser.parse(imageData);

      expect(result.success, isTrue);
      expect(result.merchantName, 'Mock Store');
      expect(result.totalAmount, 1500);
      expect(result.taxAmount, 150);
      expect(result.confidence, 0.95);
    });

    test('returns successful result for text', () async {
      const parser = MockReceiptParser();
      const text = '''
Store Name
Date: 2026-03-15
Item 1: 500
Total: 1500
Tax: 150
''';

      final result = await parser.parseFromText(text);

      expect(result.success, isTrue);
      expect(result.merchantName, 'Store Name');
    });

    test('returns failed result when configured', () async {
      const parser = MockReceiptParser(shouldFail: true);

      final result = await parser.parse(Uint8List.fromList([0x89, 0x50]));

      expect(result.success, isFalse);
      expect(result.hasErrors, isTrue);
    });

    test('parses text with regex patterns', () async {
      const parser = MockReceiptParser();
      const text = '''
STORE_NAME_Test
2026/03/20
Subtotal: 1350
Tax: 150
TOTAL: 1500
''';

      final result = await parser.parseFromText(text);

      expect(result.success, isTrue);
      expect(result.merchantName, contains('STORE_NAME'));
    });
  });

  group('ReceiptNormalizer', () {
    test('normalizes valid parsing result', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Grocery Store',
        totalAmount: 2500,
        confidence: 0.95,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.amount, 2500);
      expect(result.transaction!.description, 'Grocery Store');
    });

    test('returns error for failed parsing', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: false,
        errors: ['Parse failed'],
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.isSuccess, isFalse);
      expect(result.transaction, isNull);
      expect(result.errors.isNotEmpty, isTrue);
    });

    test('returns error for missing amount', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Store',
        totalAmount: null,
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.isSuccess, isFalse);
    });

    test('adds warning for missing date', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: null,
        merchantName: 'Store',
        totalAmount: 1000,
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.isSuccess, isTrue);
      expect(result.hasWarnings, isTrue);
    });

    test('infers expense type for store', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Grocery Store',
        totalAmount: 1000,
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.transaction!.inferredType, InferredTransactionType.expense);
    });

    test('infers category for food stores', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Supermarket',
        totalAmount: 2000,
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.transaction!.categoryId, 'expense:food');
    });

    test('infers category for utilities', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Electric Company',
        totalAmount: 5000,
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.transaction!.categoryId, 'expense:utilities');
    });

    test('adds warning for low confidence', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: 'Store',
        totalAmount: 1000,
        confidence: 0.5,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.hasWarnings, isTrue);
    });

    test('builds description from line items', () {
      const normalizer = ReceiptNormalizer();
      final parsingResult = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        merchantName: null,
        totalAmount: 1500,
        lineItems: [
          ReceiptLineItem(description: 'Item 1', amount: 500),
          ReceiptLineItem(description: 'Item 2', amount: 1000),
        ],
        confidence: 0.9,
      );

      final result = normalizer.normalize(parsingResult);

      expect(result.transaction!.description, contains('Item 1'));
      expect(result.transaction!.description, contains('他1件'));
    });
  });

  group('ReceiptParsingResult', () {
    test('hasValidators work correctly', () {
      final result = ReceiptParsingResult(
        success: true,
        parsedDate: DateTime(2026, 3, 15),
        totalAmount: 1000,
        confidence: 0.95,
      );

      expect(result.hasValidDate, isTrue);
      expect(result.hasValidAmount, isTrue);
    });

    test('hasValidators return false for null values', () {
      final result = ReceiptParsingResult(
        success: true,
        confidence: 0.95,
      );

      expect(result.hasValidDate, isFalse);
      expect(result.hasValidAmount, isFalse);
    });
  });
}
