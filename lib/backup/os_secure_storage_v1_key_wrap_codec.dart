import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'backup_codec_exceptions.dart';
import 'backup_file_codec.dart';

class OsSecureStorageV1KeyWrapCodec implements KeyWrapCodec {
  const OsSecureStorageV1KeyWrapCodec();

  static const int wrapVersion = 1;
  static const int wrapNonceLengthBytes = 12;
  static const int wrapAuthTagLengthBytes = 16;
  static const int dataKeyLengthBytes = 32;
  static const int masterKeyLengthBytes = 32;

  @override
  Uint8List wrap({
    required Uint8List dataKey,
    required Uint8List masterKey,
  }) {
    _validateKeyLengths(dataKey: dataKey, masterKey: masterKey);

    try {
      final wrapNonce = _randomBytes(wrapNonceLengthBytes);
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        true,
        AEADParameters(
          KeyParameter(masterKey),
          wrapAuthTagLengthBytes * 8,
          wrapNonce,
          Uint8List.fromList(<int>[wrapVersion]),
        ),
      );

      final output = Uint8List(cipher.getOutputSize(dataKey.length));
      var length = cipher.processBytes(dataKey, 0, dataKey.length, output, 0);
      length += cipher.doFinal(output, length);
      if (length < wrapAuthTagLengthBytes) {
        throw BackupCryptoException('Wrapped key output too short');
      }

      final wrappedDataKeyLength = length - wrapAuthTagLengthBytes;
      final wrappedDataKey =
          Uint8List.sublistView(output, 0, wrappedDataKeyLength);
      final wrapTag =
          Uint8List.sublistView(output, wrappedDataKeyLength, length);

      final bytes = BytesBuilder(copy: false)
        ..add(_u16(wrapVersion))
        ..add(_u32(wrapNonce.length))
        ..add(wrapNonce)
        ..add(_u32(wrappedDataKey.length))
        ..add(wrappedDataKey)
        ..add(_u16(wrapTag.length))
        ..add(wrapTag);
      return bytes.toBytes();
    } on InvalidCipherTextException catch (error) {
      throw BackupCryptoException(error.message ?? 'Unknown error');
    } on ArgumentError catch (error) {
      throw BackupCryptoException(error.message ?? 'Unknown error');
    }
  }

  @override
  Uint8List unwrap({
    required Uint8List wrappedKey,
    required Uint8List masterKey,
  }) {
    _validateMasterKey(masterKey);
    final reader = _ByteReader(wrappedKey);
    final version = reader.readUint16();
    if (version != wrapVersion) {
      throw BackupCryptoException('Unsupported wrap version: $version');
    }
    final wrapNonce = reader.readBytes(reader.readUint32());
    final wrappedDataKey = reader.readBytes(reader.readUint32());
    final wrapTag = reader.readBytes(reader.readUint16());
    if (!reader.isFullyConsumed) {
      throw BackupCryptoException('Trailing bytes in wrapped key');
    }
    if (wrapTag.length != wrapAuthTagLengthBytes) {
      throw BackupCryptoException('Invalid wrap tag length');
    }
    if (wrapNonce.length != wrapNonceLengthBytes) {
      throw BackupCryptoException('Invalid wrap nonce length');
    }

    final combined = Uint8List(wrappedDataKey.length + wrapTag.length);
    combined.setAll(0, wrappedDataKey);
    combined.setAll(wrappedDataKey.length, wrapTag);

    try {
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        false,
        AEADParameters(
          KeyParameter(masterKey),
          wrapAuthTagLengthBytes * 8,
          wrapNonce,
          Uint8List.fromList(<int>[wrapVersion]),
        ),
      );

      final output = Uint8List(cipher.getOutputSize(combined.length));
      var length = cipher.processBytes(combined, 0, combined.length, output, 0);
      length += cipher.doFinal(output, length);
      return Uint8List.sublistView(output, 0, length);
    } on InvalidCipherTextException catch (error) {
      throw BackupCryptoException(error.message);
    } on ArgumentError catch (error) {
      throw BackupCryptoException(error.message);
    }
  }

  void _validateKeyLengths({
    required Uint8List dataKey,
    required Uint8List masterKey,
  }) {
    if (dataKey.length != dataKeyLengthBytes) {
      throw BackupCryptoException('Invalid data key length');
    }
    _validateMasterKey(masterKey);
  }

  void _validateMasterKey(Uint8List masterKey) {
    if (masterKey.length != masterKeyLengthBytes) {
      throw BackupCryptoException('Invalid master key length');
    }
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _u16(int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  Uint8List _u32(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

class _ByteReader {
  _ByteReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isFullyConsumed => _offset == _bytes.length;

  Uint8List readBytes(int length) {
    if (_offset + length > _bytes.length) {
      throw BackupCryptoException('Unexpected end of wrapped key');
    }
    final slice = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(slice);
  }

  int readUint16() {
    final bytes = readBytes(2);
    return ByteData.sublistView(bytes).getUint16(0, Endian.little);
  }

  int readUint32() {
    final bytes = readBytes(4);
    return ByteData.sublistView(bytes).getUint32(0, Endian.little);
  }
}
