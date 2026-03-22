import 'dart:typed_data';

abstract class ReceiptParser {
  Future<ReceiptParsingResult> parse(Uint8List imageData);
  Future<ReceiptParsingResult> parseFromText(String text);
  bool get canParseImage => true;
  bool get canParseText => true;
  String get name;
  String get version;
}

class ReceiptParsingResult {
  const ReceiptParsingResult({
    required this.success,
    this.parsedDate,
    this.merchantName,
    this.description,
    this.totalAmount,
    this.subtotalAmount,
    this.taxAmount,
    this.tipAmount,
    this.lineItems,
    this.rawText,
    this.confidence = 0.0,
    this.errors,
    this.warnings,
  });

  final bool success;
  final DateTime? parsedDate;
  final String? merchantName;
  final String? description;
  final int? totalAmount;
  final int? subtotalAmount;
  final int? taxAmount;
  final int? tipAmount;
  final List<ReceiptLineItem>? lineItems;
  final String? rawText;
  final double confidence;
  final List<String>? errors;
  final List<String>? warnings;

  bool get hasErrors => errors != null && errors!.isNotEmpty;
  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
  bool get hasValidAmount => totalAmount != null && totalAmount! > 0;
  bool get hasValidDate => parsedDate != null;

  ReceiptParsingResult copyWith({
    bool? success,
    DateTime? parsedDate,
    String? merchantName,
    int? totalAmount,
    int? subtotalAmount,
    int? taxAmount,
    int? tipAmount,
    List<ReceiptLineItem>? lineItems,
    String? rawText,
    double? confidence,
    List<String>? errors,
    List<String>? warnings,
  }) {
    return ReceiptParsingResult(
      success: success ?? this.success,
      parsedDate: parsedDate ?? this.parsedDate,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      lineItems: lineItems ?? this.lineItems,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
    );
  }
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.description,
    required this.amount,
    this.quantity,
    this.unitPrice,
    this.taxRate,
  });

  final String description;
  final int amount;
  final int? quantity;
  final int? unitPrice;
  final double? taxRate;

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
    };
  }
}

class ReceiptParseError {
  const ReceiptParseError({
    required this.code,
    required this.message,
    this.field,
  });

  final String code;
  final String message;
  final String? field;

  static const unsupportedFormat = ReceiptParseError(
    code: 'UNSUPPORTED_FORMAT',
    message: 'Image format is not supported',
  );

  static const tooSmall = ReceiptParseError(
    code: 'IMAGE_TOO_SMALL',
    message: 'Image is too small to parse',
  );

  static const parseFailed = ReceiptParseError(
    code: 'PARSE_FAILED',
    message: 'Failed to parse receipt content',
  );

  static const noTextFound = ReceiptParseError(
    code: 'NO_TEXT_FOUND',
    message: 'No text could be extracted from the image',
  );
}
