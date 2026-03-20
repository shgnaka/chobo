import 'dart:convert';
import 'dart:typed_data';

import 'backup_file_codec.dart';
import 'backup_payload_envelope.dart';

class BackupPayloadJsonCodec implements BackupPayloadCodec {
  const BackupPayloadJsonCodec();

  @override
  Uint8List encode(BackupPayloadEnvelope payload) {
    final jsonText = jsonEncode(payload.toJson());
    return Uint8List.fromList(utf8.encode(jsonText));
  }

  @override
  BackupPayloadEnvelope decode(Uint8List bytes) {
    final decoded = utf8.decode(bytes);
    final jsonMap = jsonDecode(decoded);
    if (jsonMap is! Map) {
      throw const FormatException('Payload is not a JSON object');
    }
    return BackupPayloadEnvelope.fromJson(Map<String, Object?>.from(jsonMap));
  }
}
