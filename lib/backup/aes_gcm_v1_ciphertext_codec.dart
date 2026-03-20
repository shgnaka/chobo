import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'backup_codec_exceptions.dart';
import 'backup_crypto_boxes.dart';
import 'backup_file_codec.dart';

class AesGcmV1CiphertextCodec implements CiphertextCodec {
  const AesGcmV1CiphertextCodec();

  static const int keyLengthBytes = 32;
  static const int nonceLengthBytes = 12;
  static const int authTagLengthBytes = 16;

  @override
  CiphertextBox encrypt({
    required Uint8List plaintext,
    required Uint8List dataKey,
    required Uint8List nonce,
    required List<int> aad,
  }) {
    _validateInputs(dataKey: dataKey, nonce: nonce);

    try {
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        true,
        AEADParameters(
          KeyParameter(dataKey),
          authTagLengthBytes * 8,
          nonce,
          Uint8List.fromList(aad),
        ),
      );

      final output = Uint8List(cipher.getOutputSize(plaintext.length));
      var length =
          cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
      length += cipher.doFinal(output, length);

      if (length < authTagLengthBytes) {
        throw BackupCryptoException('Encrypted output too short');
      }

      final ciphertextLength = length - authTagLengthBytes;
      final ciphertext = Uint8List.sublistView(output, 0, ciphertextLength);
      final authTag = Uint8List.sublistView(output, ciphertextLength, length);
      return CiphertextBox(ciphertext: ciphertext, authTag: authTag);
    } on InvalidCipherTextException catch (error) {
      throw BackupCryptoException(error.message ?? 'Unknown error');
    } on ArgumentError catch (error) {
      throw BackupCryptoException(error.message ?? 'Unknown error');
    }
  }

  @override
  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List authTag,
    required Uint8List dataKey,
    required Uint8List nonce,
    required List<int> aad,
  }) {
    _validateInputs(dataKey: dataKey, nonce: nonce);
    if (authTag.length != authTagLengthBytes) {
      throw BackupCryptoException('Invalid auth tag length');
    }

    final combined = Uint8List(ciphertext.length + authTag.length);
    combined.setAll(0, ciphertext);
    combined.setAll(ciphertext.length, authTag);

    try {
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        false,
        AEADParameters(
          KeyParameter(dataKey),
          authTagLengthBytes * 8,
          nonce,
          Uint8List.fromList(aad),
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

  void _validateInputs({
    required Uint8List dataKey,
    required Uint8List nonce,
  }) {
    if (dataKey.length != keyLengthBytes) {
      throw BackupCryptoException('Invalid data key length');
    }
    if (nonce.length != nonceLengthBytes) {
      throw BackupCryptoException('Invalid nonce length');
    }
  }
}
