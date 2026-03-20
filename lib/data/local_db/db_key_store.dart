import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DbKeyStore {
  DbKeyStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'chobo_db_encryption_key_v1';

  final FlutterSecureStorage _storage;
  final String storageKey;

  Future<Uint8List> loadOrGenerate() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null) {
      return Uint8List.fromList(base64Decode(existing));
    }

    final generated = _randomBytes(32);
    await _storage.write(key: storageKey, value: base64Encode(generated));
    return generated;
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
