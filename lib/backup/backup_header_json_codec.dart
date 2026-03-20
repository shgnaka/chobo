import 'dart:convert';
import 'dart:typed_data';

import 'backup_file_codec.dart';
import 'backup_header.dart';

class BackupHeaderJsonCodec implements BackupHeaderCodec {
  const BackupHeaderJsonCodec();

  @override
  Uint8List encode(BackupHeader header) {
    final jsonText = jsonEncode(header.toJson());
    return Uint8List.fromList(utf8.encode(jsonText));
  }

  @override
  BackupHeader decode(Uint8List bytes) {
    final decoded = utf8.decode(bytes);
    final jsonMap = jsonDecode(decoded);
    if (jsonMap is! Map) {
      throw const FormatException('Header is not a JSON object');
    }
    return BackupHeader.fromJson(Map<String, Object?>.from(jsonMap));
  }
}
