import 'dart:typed_data';

import 'import_result.dart';
import 'transaction_importer.dart';

class ImportService {
  ImportService({
    List<TransactionImporter>? importers,
  }) : _importers = importers ?? [];

  final List<TransactionImporter> _importers;

  void registerImporter(TransactionImporter importer) {
    _importers.add(importer);
  }

  void unregisterImporter(TransactionImporter importer) {
    _importers.remove(importer);
  }

  List<TransactionImporter> get availableImporters =>
      List.unmodifiable(_importers);

  TransactionImporter? findImporter(ImportSource source) {
    for (final importer in _importers) {
      if (importer.canHandle(source)) {
        return importer;
      }
    }
    return null;
  }

  Future<ImportPreview> preview(Uint8List fileData, String? fileName) async {
    final sourceType = _detectSourceType(fileName, fileData);
    final source = ImportSource(
      type: sourceType,
      fileName: fileName,
      fileData: fileData,
    );

    final importer = findImporter(source);
    if (importer == null) {
      return ImportPreview(
        transactions: [],
        duplicateCount: 0,
        warnings: [
          const ImportWarning(
            index: 0,
            message: 'No importer found for this file type',
            warningType: ImportWarningType.unusualFormat,
          ),
        ],
        errors: [
          const ImportError(
            index: 0,
            message:
                'Unsupported file format. Supported formats: CSV, OFX, QIF, receipt images',
          ),
        ],
      );
    }

    return importer.preview(source);
  }

  Future<ImportResult> import(
    Uint8List fileData,
    String? fileName, {
    bool skipDuplicates = true,
  }) async {
    final sourceType = _detectSourceType(fileName, fileData);
    final source = ImportSource(
      type: sourceType,
      fileName: fileName,
      fileData: fileData,
    );

    final importer = findImporter(source);
    if (importer == null) {
      return ImportResult(
        total: 0,
        success: 0,
        skipped: 0,
        failed: 0,
        duplicateCount: 0,
        importedTransactions: [],
        errors: [
          const ImportError(
            index: 0,
            message: 'No importer found for this file type',
          ),
        ],
        warnings: [],
      );
    }

    final result = await importer.import(source);

    return ImportResult(
      total: result.total,
      success: result.success,
      skipped: skipDuplicates ? result.duplicateCount : 0,
      failed: result.failed,
      duplicateCount: result.duplicateCount,
      importedTransactions: skipDuplicates
          ? result.importedTransactions
          : result.importedTransactions,
      errors: result.errors,
      warnings: result.warnings,
    );
  }

  Future<ImportResult> importFromText(
    String text, {
    required ImportSourceType sourceType,
    bool skipDuplicates = true,
  }) async {
    final source = ImportSource(
      type: sourceType,
      rawText: text,
    );

    final importer = findImporter(source);
    if (importer == null) {
      return ImportResult(
        total: 0,
        success: 0,
        skipped: 0,
        failed: 0,
        duplicateCount: 0,
        importedTransactions: [],
        errors: [
          const ImportError(
            index: 0,
            message: 'No importer found for this source type',
          ),
        ],
        warnings: [],
      );
    }

    return importer.import(source);
  }

  ImportSourceType _detectSourceType(String? fileName, Uint8List fileData) {
    if (fileName != null) {
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.csv')) {
        return ImportSourceType.csv;
      }
      if (lowerName.endsWith('.ofx') || lowerName.endsWith('.qfx')) {
        return ImportSourceType.ofx;
      }
      if (lowerName.endsWith('.qif')) {
        return ImportSourceType.qif;
      }
      if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png')) {
        return ImportSourceType.receiptImage;
      }
    }

    if (fileData.isNotEmpty) {
      if (_looksLikeCsv(fileData)) {
        return ImportSourceType.csv;
      }
      if (_looksLikeOfx(fileData)) {
        return ImportSourceType.ofx;
      }
      if (_looksLikeQif(fileData)) {
        return ImportSourceType.qif;
      }
      if (_looksLikeImage(fileData)) {
        return ImportSourceType.receiptImage;
      }
    }

    return ImportSourceType.csv;
  }

  bool _looksLikeCsv(Uint8List data) {
    if (data.length < 3) return false;
    final header = String.fromCharCodes(data.take(100));
    return header.contains(',') && !header.contains('<');
  }

  bool _looksLikeOfx(Uint8List data) {
    if (data.length < 10) return false;
    final header = String.fromCharCodes(data.take(200));
    return header.contains('OFXHEADER') || header.contains('<?xml');
  }

  bool _looksLikeQif(Uint8List data) {
    if (data.length < 3) return false;
    final header = String.fromCharCodes(data.take(50));
    return header.startsWith('!Type:');
  }

  bool _looksLikeImage(Uint8List data) {
    if (data.length < 4) return false;
    final magic = data.take(4).toList();
    if (magic[0] == 0xFF && magic[1] == 0xD8 && magic[2] == 0xFF) {
      return true;
    }
    if (magic[0] == 0x89 &&
        magic[1] == 0x50 &&
        magic[2] == 0x4E &&
        magic[3] == 0x47) {
      return true;
    }
    return false;
  }
}
