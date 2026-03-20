import 'dart:convert';
import 'dart:typed_data';

import 'package:chobo/chobo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupFileCodec', () {
    test('encodes and decodes a minimal envelope round-trip', () {
      final codec = BinaryBackupFileCodec();
      final envelope = _sampleEnvelope(optionalFooter: '');

      final bytes = codec.encode(envelope);
      final decoded = codec.decode(bytes);

      expect(decoded.formatVersion, envelope.formatVersion);
      expect(decoded.header.appVersion, envelope.header.appVersion);
      expect(decoded.header.schemaVersion, envelope.header.schemaVersion);
      expect(decoded.header.encryptionScheme, envelope.header.encryptionScheme);
      expect(decoded.header.keyWrapScheme, envelope.header.keyWrapScheme);
      expect(decoded.header.payloadFormat, envelope.header.payloadFormat);
      expect(decoded.header.deviceId, envelope.header.deviceId);
      expect(decoded.wrappedKey, envelope.wrappedKey);
      expect(decoded.nonce, envelope.nonce);
      expect(decoded.ciphertext, envelope.ciphertext);
      expect(decoded.authTag, envelope.authTag);
      expect(decoded.optionalFooter, envelope.optionalFooter);
    });

    test('encodes and decodes a standard envelope round-trip', () {
      final codec = BinaryBackupFileCodec();
      final envelope = _sampleEnvelope(optionalFooter: 'backup-footer');

      final bytes = codec.encode(envelope);
      final decoded = codec.decode(bytes);

      expect(decoded.header.createdAt.toUtc(),
          envelope.header.createdAt.toUtc());
      expect(decoded.optionalFooter, 'backup-footer');
      expect(decoded.ciphertext.length, 32);
      expect(decoded.authTag.length, 16);
    });

    test('rejects files with an invalid magic value', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final tampered = Uint8List.fromList(bytes);
      tampered[0] = 'X'.codeUnitAt(0);

      expect(() => codec.decode(tampered),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects unsupported format versions', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final tampered = Uint8List.fromList(bytes);
      tampered[8] = 2;
      tampered[9] = 0;

      expect(() => codec.decode(tampered),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects truncated files', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final truncated = Uint8List.sublistView(bytes, 0, bytes.length - 1);

      expect(() => codec.decode(truncated),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects files with length mismatches', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final tampered = Uint8List.fromList(bytes);

      final headerLengthOffset = 10;
      final data = ByteData.sublistView(tampered);
      data.setUint32(headerLengthOffset, 9999, Endian.little);

      expect(() => codec.decode(tampered),
          throwsA(isA<BackupFormatException>()));
    });

    test('rejects files with invalid UTF-8 headers', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final tampered = Uint8List.fromList(bytes);
      final data = ByteData.sublistView(tampered);
      final headerLength = data.getUint32(10, Endian.little);
      final headerStart = 14;
      tampered[headerStart] = 0xFF;
      expect(() => codec.decode(tampered), throwsA(isA<FormatException>()));
      expect(headerLength, greaterThan(0));
    });

    test('rejects files with invalid JSON headers', () {
      final codec = BinaryBackupFileCodec();
      final bytes = codec.encode(_sampleEnvelope(optionalFooter: ''));
      final tampered = Uint8List.fromList(bytes);
      final headerStart = 14;
      tampered[headerStart] = 'x'.codeUnitAt(0);

      expect(() => codec.decode(tampered), throwsA(isA<FormatException>()));
    });
  });
}

BackupFileEnvelope _sampleEnvelope({required String optionalFooter}) {
  final header = BackupHeader(
    appVersion: '1.0.0',
    schemaVersion: 1,
    createdAt: DateTime.utc(2026, 3, 20),
    encryptionScheme: 'aes-gcm-v1',
    keyWrapScheme: 'os-secure-storage-v1',
    payloadFormat: 'json-v1',
    deviceId: 'device-opaque-001',
  );

  return BackupFileEnvelope(
    formatVersion: BinaryBackupFileCodec.formatVersion,
    header: header,
    wrappedKey: List<int>.generate(48, (index) => index + 1),
    nonce: List<int>.generate(12, (index) => index + 2),
    ciphertext: List<int>.generate(32, (index) => index + 3),
    authTag: List<int>.generate(16, (index) => index + 4),
    optionalFooter: optionalFooter,
  );
}
