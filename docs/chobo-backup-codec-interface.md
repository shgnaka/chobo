---
title: "CHOBO BackupFileCodec interface"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-backup-spec.md"
---

# CHOBO BackupFileCodec interface

## 1. 目的

この文書は、単一ファイルバックアップを読み書きする `BackupFileCodec` の責務境界を定義する。

Codec は、ファイル形式の parse / compose に専念し、DB 操作や OS 認証は持たない。

## 2. 責務

`BackupFileCodec` が行うこと。

- 単一バックアップファイルを bytes に変換する
- bytes を単一バックアップファイルとして解析する
- magic、length、header、ciphertext、auth_tag の整合を検査する
- 形式版数と scheme 名を読み取り、未対応なら失敗する

`BackupFileCodec` が行わないこと。

- 追加認証
- secure storage とのやり取り
- DB からのスナップショット取得
- JSON payload の業務整合性検証
- 一時 DB への復元

## 3. データ型

### 3.1 `BackupFileEnvelope`

- `formatVersion`
- `header`
- `wrappedKey`
- `nonce`
- `ciphertext`
- `authTag`
- `optionalFooter`

### 3.2 `BackupHeader`

- `appVersion`
- `schemaVersion`
- `createdAt`
- `encryptionScheme`
- `keyWrapScheme`
- `payloadFormat`
- `deviceId`

### 3.3 `BackupPayload`

- `accounts`
- `transactions`
- `entries`
- `periodClosures`
- `settings`
- `auditEvents`

## 4. インターフェース案

```text
interface BackupFileCodec {
  Uint8List encode(BackupFileEnvelope envelope)
  BackupFileEnvelope decode(Uint8List bytes)
  bool canDecode(Uint8List bytes)
}
```

### 4.1 `encode`

- 入力: `BackupFileEnvelope`
- 出力: 1 つのバイナリファイル bytes
- 役割: バイト列の compose

### 4.2 `decode`

- 入力: バイナリファイル bytes
- 出力: `BackupFileEnvelope`
- 役割: バイト列の parse
- 失敗時: 形式エラー、版数エラー、長さ不整合、切断、JSON エラー

### 4.3 `canDecode`

- 入力: バイナリファイル bytes
- 出力: 形式判定の可否
- 役割: magic と最低限の長さだけを素早く確認する

## 5. 実装境界

Codec は次の下位部品に分けてよい。

- `HeaderCodec`
- `PayloadCodec`
- `KeyWrapCodec`
- `CiphertextCodec`

ただし外部公開は `BackupFileCodec` 1 本にまとめる。

## 6. 想定呼び出し順

### 6.1 作成時

1. DB のスナップショットを取る
2. payload を作る
3. data key を生成する
4. payload を暗号化する
5. wrapped key を作る
6. envelope を組む
7. `BackupFileCodec.encode` を呼ぶ

### 6.2 復元時

1. ファイル bytes を読む
2. `BackupFileCodec.decode` を呼ぶ
3. header から scheme を読む
4. secure storage から鍵を取る
5. wrapped key をほどく
6. payload を復号する
7. payload を JSON から domain へ変換する
8. DB へ反映する

## 7. テスト観点

Codec 単体では次をテストする。

- encode/decode round-trip
- magic mismatch
- truncated bytes
- length mismatch
- unsupported format_version
- invalid UTF-8 header
- invalid JSON header
- invalid JSON payload

## 8. Dart type definitions

以下は実装のたたき台である。  
`domain` と `data` の責務を混ぜないよう、純粋な値オブジェクトとして定義する。

### 8.1 `BackupHeader`

```dart
class BackupHeader {
  const BackupHeader({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.encryptionScheme,
    required this.keyWrapScheme,
    required this.payloadFormat,
    required this.deviceId,
  });

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String encryptionScheme;
  final String keyWrapScheme;
  final String payloadFormat;
  final String? deviceId;

  Map<String, Object?> toJson() => <String, Object?>{
        'app_version': appVersion,
        'schema_version': schemaVersion,
        'created_at': createdAt.toUtc().toIso8601String(),
        'encryption_scheme': encryptionScheme,
        'key_wrap_scheme': keyWrapScheme,
        'payload_format': payloadFormat,
        'device_id': deviceId,
      };

  static BackupHeader fromJson(Map<String, Object?> json) {
    return BackupHeader(
      appVersion: json['app_version'] as String,
      schemaVersion: json['schema_version'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      encryptionScheme: json['encryption_scheme'] as String,
      keyWrapScheme: json['key_wrap_scheme'] as String,
      payloadFormat: json['payload_format'] as String,
      deviceId: json['device_id'] as String?,
    );
  }
}
```

### 8.2 `BackupFileEnvelope`

```dart
class BackupFileEnvelope {
  const BackupFileEnvelope({
    required this.formatVersion,
    required this.header,
    required this.wrappedKey,
    required this.nonce,
    required this.ciphertext,
    required this.authTag,
    required this.optionalFooter,
  });

  final int formatVersion;
  final BackupHeader header;
  final List<int> wrappedKey;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> authTag;
  final String optionalFooter;
}
```

### 8.3 補助型

```dart
class BackupPayloadEnvelope {
  const BackupPayloadEnvelope({
    required this.accounts,
    required this.transactions,
    required this.entries,
    required this.periodClosures,
    required this.settings,
    required this.auditEvents,
  });

  final List<Map<String, Object?>> accounts;
  final List<Map<String, Object?>> transactions;
  final List<Map<String, Object?>> entries;
  final List<Map<String, Object?>> periodClosures;
  final List<Map<String, Object?>> settings;
  final List<Map<String, Object?>> auditEvents;

  Map<String, Object?> toJson() => <String, Object?>{
        'accounts': accounts,
        'transactions': transactions,
        'entries': entries,
        'period_closures': periodClosures,
        'settings': settings,
        'audit_events': auditEvents,
      };
}
```

## 9. `BackupFileCodec` class skeleton

`BackupFileCodec` は byte-level codec だけを担当する。

```dart
abstract class BackupFileCodec {
  Uint8List encode(BackupFileEnvelope envelope);

  BackupFileEnvelope decode(Uint8List bytes);

  bool canDecode(Uint8List bytes);
}
```

### 9.1 実装補助

実装では次の小さな責務に分けてよい。

```dart
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
```

## 10. バックアップ復元ユースケースの分割案

復元は 1 つの関数で抱えず、次のユースケースへ分割する。

### 10.1 `ValidateRestoreRequest`

- 役割: 入力ファイル、権限、状態の初期検査
- 入力: 選択されたバックアップファイル
- 出力: 復元を続けてよいか
- 担当:
  - 追加認証済みか
  - ファイルが存在するか
  - 復元中でないか

### 10.2 `ParseBackupEnvelope`

- 役割: bytes を `BackupFileEnvelope` に変換する
- 入力: ファイル bytes
- 出力: `BackupFileEnvelope`
- 担当:
  - magic 検証
  - 長さ検証
  - version 検証

### 10.3 `LoadBackupMasterKey`

- 役割: secure storage からラップ鍵素材を取得する
- 入力: なし
- 出力: master key bytes
- 担当:
  - `flutter_secure_storage` からの取得
  - 鍵欠損時の失敗

### 10.4 `UnwrapDataKey`

- 役割: wrapped key をほどいて data key を得る
- 入力: `wrappedKey`, `masterKey`
- 出力: data key bytes
- 担当:
  - `key_wrap_scheme` の検証
  - wrap version の検証

### 10.5 `DecryptBackupPayload`

- 役割: ciphertext を plaintext payload に戻す
- 入力: `ciphertext`, `dataKey`, `nonce`, `aad`
- 出力: plaintext bytes
- 担当:
  - `encryption_scheme` の検証
  - tag 検証

### 10.6 `ValidateBackupPayload`

- 役割: payload JSON とプロトコル整合性を確認する
- 入力: plaintext payload
- 出力: payload domain object
- 担当:
  - JSON 構造検証
  - 必須フィールド検証
  - 取引整合性検証

### 10.7 `RestorePayloadToTemporaryDatabase`

- 役割: 一時 DB に書き込む
- 入力: payload domain object
- 出力: 一時 DB の状態
- 担当:
  - DB へ挿入
  - 制約違反の検出

### 10.8 `FinalizeRestore`

- 役割: 一時 DB を正本へ切り替える
- 入力: 一時 DB
- 出力: 正本更新結果
- 担当:
  - 最終整合性確認
  - 切り替え
  - 失敗時の破棄

## 11. 呼び出し順の例

```text
restore flow:
  ValidateRestoreRequest
  ParseBackupEnvelope
  LoadBackupMasterKey
  UnwrapDataKey
  DecryptBackupPayload
  ValidateBackupPayload
  RestorePayloadToTemporaryDatabase
  FinalizeRestore
```

## 12. 想定ファイル配置

- `lib/backup/backup_header.dart`
- `lib/backup/backup_payload_envelope.dart`
- `lib/backup/backup_file_envelope.dart`
- `lib/backup/backup_file_codec.dart`
- `test/backup/backup_file_codec_test.dart`
- `test/backup/backup_roundtrip_test.dart`
- `test/backup/backup_recovery_test.dart`
