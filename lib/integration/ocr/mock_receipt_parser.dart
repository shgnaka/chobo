import 'dart:typed_data';

import 'receipt_parser.dart';

class MockReceiptParser implements ReceiptParser {
  const MockReceiptParser({
    this.parseDelay = const Duration(milliseconds: 100),
    this.shouldFail = false,
    this.failError,
  });

  final Duration parseDelay;
  final bool shouldFail;
  final ReceiptParseError? failError;

  @override
  String get name => 'MockReceiptParser';

  @override
  String get version => '1.0.0';

  @override
  bool get canParseImage => true;

  @override
  bool get canParseText => true;

  @override
  Future<ReceiptParsingResult> parse(Uint8List imageData) async {
    await Future.delayed(parseDelay);

    if (shouldFail) {
      return ReceiptParsingResult(
        success: false,
        confidence: 0.0,
        errors: [failError?.message ?? 'Mock parsing failed'],
      );
    }

    return ReceiptParsingResult(
      success: true,
      parsedDate: DateTime.now(),
      merchantName: 'Mock Store',
      totalAmount: 1500,
      subtotalAmount: 1350,
      taxAmount: 150,
      lineItems: const [
        ReceiptLineItem(description: 'Item 1', amount: 500),
        ReceiptLineItem(description: 'Item 2', amount: 850),
      ],
      rawText: _mockRawText,
      confidence: 0.95,
    );
  }

  @override
  Future<ReceiptParsingResult> parseFromText(String text) async {
    await Future.delayed(parseDelay);

    if (shouldFail) {
      return ReceiptParsingResult(
        success: false,
        confidence: 0.0,
        errors: [failError?.message ?? 'Mock parsing failed'],
      );
    }

    final parsed = _parseMockText(text);

    return ReceiptParsingResult(
      success: true,
      parsedDate: parsed.date,
      merchantName: parsed.merchantName,
      totalAmount: parsed.totalAmount,
      subtotalAmount: parsed.subtotalAmount,
      taxAmount: parsed.taxAmount,
      rawText: text,
      confidence: 0.9,
    );
  }

  _MockParsedData _parseMockText(String text) {
    final lines = text.split('\n');

    String? merchantName;
    int? totalAmount;
    int? subtotalAmount;
    int? taxAmount;
    DateTime? date;

    for (final line in lines) {
      final lowerLine = line.toLowerCase();

      if (lowerLine.contains('store') || lowerLine.contains('店')) {
        merchantName = line.trim();
      }

      final totalMatch = RegExp(r'[Tt]otal[:\s]*[¥$]?(\d+)').firstMatch(line);
      if (totalMatch != null) {
        totalAmount = int.tryParse(totalMatch.group(1) ?? '');
      }

      final subtotalMatch =
          RegExp(r'[Ss]ubtotal[:\s]*[¥$]?(\d+)').firstMatch(line);
      if (subtotalMatch != null) {
        subtotalAmount = int.tryParse(subtotalMatch.group(1) ?? '');
      }

      final taxMatch = RegExp(r'[Tt]ax[:\s]*[¥$]?(\d+)').firstMatch(line);
      if (taxMatch != null) {
        taxAmount = int.tryParse(taxMatch.group(1) ?? '');
      }

      final dateMatch =
          RegExp(r'(\d{4})[/\-](\d{2})[/\-](\d{2})').firstMatch(line);
      if (dateMatch != null) {
        date = DateTime.tryParse(
          '${dateMatch.group(1)}-${dateMatch.group(2)}-${dateMatch.group(3)}',
        );
      }
    }

    return _MockParsedData(
      merchantName: merchantName ?? 'Unknown Store',
      totalAmount: totalAmount ?? 0,
      subtotalAmount: subtotalAmount ?? (totalAmount ?? 0),
      taxAmount: taxAmount ?? 0,
      date: date ?? DateTime.now(),
    );
  }

  static const String _mockRawText = '''
=====================================
          Mock Store
=====================================
Date: 2026-03-22

Item 1                    ¥500
Item 2                    ¥850

---------------------------------
Subtotal:               ¥1,350
Tax (10%):                ¥150
---------------------------------
TOTAL:                  ¥1,500
=====================================
        Thank you!
=====================================
''';
}

class _MockParsedData {
  const _MockParsedData({
    required this.merchantName,
    required this.totalAmount,
    required this.subtotalAmount,
    required this.taxAmount,
    required this.date,
  });

  final String merchantName;
  final int totalAmount;
  final int subtotalAmount;
  final int taxAmount;
  final DateTime date;
}

class MockReceiptParserBuilder {
  MockReceiptParserBuilder();

  MockReceiptParser build() {
    return MockReceiptParser(
      parseDelay: _parseDelay,
      shouldFail: _shouldFail,
      failError: _failError,
    );
  }

  Duration _parseDelay = const Duration(milliseconds: 100);
  bool _shouldFail = false;
  ReceiptParseError? _failError;

  MockReceiptParserBuilder withParseDelay(Duration delay) {
    _parseDelay = delay;
    return this;
  }

  MockReceiptParserBuilder thatFails({
    ReceiptParseError? error,
  }) {
    _shouldFail = true;
    _failError = error;
    return this;
  }

  MockReceiptParserBuilder withValidReceipt() {
    _shouldFail = false;
    return this;
  }
}
