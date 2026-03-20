import 'dart:convert';
import 'dart:typed_data';

import 'backup_codec_exceptions.dart';
import 'backup_file_codec.dart';
import 'backup_file_envelope.dart';
import 'backup_header_json_codec.dart';

class BinaryBackupFileCodec implements BackupFileCodec {
  BinaryBackupFileCodec({
    BackupHeaderCodec? headerCodec,
  }) : _headerCodec = headerCodec ?? const BackupHeaderJsonCodec();

  static const String magic = 'CHOBOBK1';
  static const int formatVersion = 1;

  final BackupHeaderCodec _headerCodec;

  @override
  Uint8List encode(BackupFileEnvelope envelope) {
    final headerBytes = _headerCodec.encode(envelope.header);
    final writer = _ByteWriter();
    writer.writeAscii(magic);
    writer.writeUint16(formatVersion);
    writer.writeUint32(headerBytes.length);
    writer.writeBytes(headerBytes);
    writer.writeUint32(envelope.wrappedKey.length);
    writer.writeBytes(envelope.wrappedKey);
    writer.writeUint32(envelope.nonce.length);
    writer.writeBytes(envelope.nonce);
    writer.writeUint64(envelope.ciphertext.length);
    writer.writeBytes(envelope.ciphertext);
    writer.writeUint16(envelope.authTag.length);
    writer.writeBytes(envelope.authTag);
    final footerBytes = utf8.encode(envelope.optionalFooter);
    writer.writeUint32(footerBytes.length);
    writer.writeBytes(footerBytes);
    return writer.toBytes();
  }

  @override
  BackupFileEnvelope decode(Uint8List bytes) {
    final reader = _ByteReader(bytes);
    final magicBytes = reader.readBytes(8);
    final readMagic = ascii.decode(magicBytes);
    if (readMagic != magic) {
      throw BackupFormatException('Invalid backup magic: $readMagic');
    }

    final version = reader.readUint16();
    if (version != formatVersion) {
      throw BackupFormatException('Unsupported backup format version: $version');
    }

    final headerLength = reader.readUint32();
    final header = _headerCodec.decode(reader.readBytes(headerLength));

    final wrappedKeyLength = reader.readUint32();
    final wrappedKey = reader.readBytes(wrappedKeyLength);

    final nonceLength = reader.readUint32();
    final nonce = reader.readBytes(nonceLength);

    final ciphertextLength = reader.readUint64();
    final ciphertext = reader.readBytes(ciphertextLength);

    final authTagLength = reader.readUint16();
    final authTag = reader.readBytes(authTagLength);

    final footerLength = reader.readUint32();
    final optionalFooter = utf8.decode(reader.readBytes(footerLength));

    if (!reader.isFullyConsumed) {
      throw BackupFormatException('Trailing bytes found after backup payload');
    }

    return BackupFileEnvelope(
      formatVersion: version,
      header: header,
      wrappedKey: wrappedKey,
      nonce: nonce,
      ciphertext: ciphertext,
      authTag: authTag,
      optionalFooter: optionalFooter,
    );
  }

  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 10) {
      return false;
    }
    return ascii.decode(bytes.sublist(0, 8), allowInvalid: true) == magic;
  }
}

class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void writeAscii(String text) => _builder.add(ascii.encode(text));

  void writeBytes(List<int> bytes) => _builder.add(bytes);

  void writeUint16(int value) => writeBytes(_asBytes(2, value));

  void writeUint32(int value) => writeBytes(_asBytes(4, value));

  void writeUint64(int value) => writeBytes(_asBytes(8, value));

  Uint8List toBytes() => _builder.toBytes();

  static Uint8List _asBytes(int byteCount, int value) {
    final bytes = ByteData(byteCount);
    switch (byteCount) {
      case 2:
        bytes.setUint16(0, value, Endian.little);
        return bytes.buffer.asUint8List();
      case 4:
        bytes.setUint32(0, value, Endian.little);
        return bytes.buffer.asUint8List();
      case 8:
        bytes.setUint64(0, value, Endian.little);
        return bytes.buffer.asUint8List();
      default:
        throw ArgumentError('Unsupported integer size: $byteCount');
    }
  }
}

class _ByteReader {
  _ByteReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isFullyConsumed => _offset == _bytes.length;

  Uint8List readBytes(int length) {
    _ensureAvailable(length);
    final slice = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(slice);
  }

  int readUint16() => _readInt(2);

  int readUint32() => _readInt(4);

  int readUint64() => _readInt(8);

  int _readInt(int byteCount) {
    final bytes = readBytes(byteCount);
    final data = ByteData.sublistView(bytes);
    switch (byteCount) {
      case 2:
        return data.getUint16(0, Endian.little);
      case 4:
        return data.getUint32(0, Endian.little);
      case 8:
        return data.getUint64(0, Endian.little);
      default:
        throw ArgumentError('Unsupported integer size: $byteCount');
    }
  }

  void _ensureAvailable(int length) {
    if (length < 0) {
      throw BackupFormatException('Negative length');
    }
    if (_offset + length > _bytes.length) {
      throw BackupFormatException('Unexpected end of file');
    }
  }
}
