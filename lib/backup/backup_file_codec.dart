import 'dart:typed_data';

import 'backup_crypto_boxes.dart';
import 'backup_file_envelope.dart';
import 'backup_header.dart';
import 'backup_payload_envelope.dart';

abstract class BackupFileCodec {
  Uint8List encode(BackupFileEnvelope envelope);

  BackupFileEnvelope decode(Uint8List bytes);

  bool canDecode(Uint8List bytes);
}

abstract class BackupHeaderCodec {
  Uint8List encode(BackupHeader header);

  BackupHeader decode(Uint8List bytes);
}

abstract class BackupPayloadCodec {
  Uint8List encode(BackupPayloadEnvelope payload);

  BackupPayloadEnvelope decode(Uint8List bytes);
}

abstract class KeyWrapCodec {
  Uint8List wrap({
    required Uint8List dataKey,
    required Uint8List masterKey,
  });

  Uint8List unwrap({
    required Uint8List wrappedKey,
    required Uint8List masterKey,
  });
}

abstract class CiphertextCodec {
  CiphertextBox encrypt({
    required Uint8List plaintext,
    required Uint8List dataKey,
    required Uint8List nonce,
    required List<int> aad,
  });

  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List authTag,
    required Uint8List dataKey,
    required Uint8List nonce,
    required List<int> aad,
  });
}
