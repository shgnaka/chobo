import 'dart:typed_data';

import 'import_result.dart';

abstract class TransactionImporter {
  Future<ImportResult> import(ImportSource source);
  Future<ImportPreview> preview(ImportSource source);
  bool canHandle(ImportSource source);
  String get name;
  String get description;
}

class ImportSource {
  const ImportSource({
    required this.type,
    this.fileName,
    this.fileData,
    this.rawText,
  });

  final ImportSourceType type;
  final String? fileName;
  final Uint8List? fileData;
  final String? rawText;

  bool get hasFile => fileData != null;
  bool get hasText => rawText != null;
}

enum ImportSourceType {
  csv,
  ofx,
  qif,
  receiptImage,
  receiptText,
  bankApi,
}
