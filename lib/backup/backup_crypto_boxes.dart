import 'dart:typed_data';

class CiphertextBox {
  const CiphertextBox({
    required this.ciphertext,
    required this.authTag,
  });

  final Uint8List ciphertext;
  final Uint8List authTag;
}
