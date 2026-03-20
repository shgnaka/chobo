---
title: "CHOBO バックアップ仕様"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-spec-memo.md"
---

# CHOBO バックアップ仕様

## 1. 目的

この文書は、CHOBO のバックアップ生成、暗号化、復元、失敗時の扱いを定義する。

バックアップは、次のために使う。

- 端末故障時の復旧
- 誤操作からの復元
- 手動での持ち出し用エクスポート

## 2. 基本方針

- バックアップファイルは常に暗号化する
- 平文バックアップは MVP では提供しない
- バックアップ作成時と復元時には追加認証を要求する
- 既存データを即時上書きしない
- 復元は一時領域を経由し、成功時のみ正本へ切り替える
- MVP では新しい端末への完全な移行は正式サポート対象にしない
- MVP で保証するのは、同一端末内でのバックアップ復元である

## 3. バックアップ対象

バックアップには、復元に必要な次の情報を含める。

- 勘定マスタ
- 取引
- エントリ
- 締め情報
- 設定のうち復元に必要なもの
- 監査イベント

メタデータ例:

- `backup_version`
- `created_at`
- `app_version`
- `schema_version`
- `device_id` または匿名化識別子

## 4. バックアップ形式

バックアップファイルは、概念上次の要素を持つ。

- ヘッダ
- ラップ済みデータ鍵
- 暗号化本文
- 整合性情報

MVP では、まず **単一ファイル形式** で足りるかを優先して判断する。  
複数ファイルを束ねる必要が明確になった場合にのみ、圧縮・アーカイブ系の依存を再検討する。

### 4.3 単一ファイル案

MVP のバックアップは、1 つのバイナリファイルにすべてを詰める。

推奨方針は次の通りである。

- ファイル拡張子は一意なものにする
- 先頭に形式判定用のマジック値を置く
- ヘッダは平文で持つ
- 本文は暗号化する
- 整合性は暗号スイートの認証タグを主とする
- 圧縮は MVP では必須にしない

概念構造は次の通り。

1. `magic`
- バックアップ形式識別子
- 誤読を防ぐための固定値

2. `format_version`
- ファイル形式の版数

3. `header_length`
- ヘッダ領域の長さ

4. `header`
- JSON などの構造化データ
- 含む情報:
  - `app_version`
  - `schema_version`
  - `created_at`
  - `encryption_scheme`
  - `key_wrap_scheme`
  - `payload_format`

5. `wrapped_key_length`
- ラップ済みデータ鍵の長さ

6. `wrapped_key`
- ラップ済みデータ鍵本体
- 内部形式は `key_wrap_scheme` で定義する

7. `nonce_length`
- 本文暗号化に使う nonce の長さ

8. `nonce`
- 本文暗号化に使う nonce

9. `ciphertext_length`
- 暗号化本文の長さ

10. `ciphertext`
- バックアップ対象データの暗号化本文

11. `auth_tag_length`
- 認証タグの長さ

12. `auth_tag`
- 整合性確認のための認証タグ

13. `optional_footer`
- 将来拡張用の予約領域
- MVP では空でもよい

この形にしておくと、圧縮を入れない単一ファイル運用を保ちながら、将来の形式拡張も後方互換で進めやすい。

### 4.4 バイト列仕様

単一ファイルは、次の順でバイト列を並べる。

| 順序 | 長さ | 型 | 内容 |
| --- | ---: | --- | --- |
| 1 | 8 | ASCII bytes | magic |
| 2 | 2 | `u16` little-endian | `format_version` |
| 3 | 4 | `u32` little-endian | `header_length` |
| 4 | `header_length` | UTF-8 bytes | `header` |
| 5 | 4 | `u32` little-endian | `wrapped_key_length` |
| 6 | `wrapped_key_length` | bytes | `wrapped_key` |
| 7 | 4 | `u32` little-endian | `nonce_length` |
| 8 | `nonce_length` | bytes | `nonce` |
| 9 | 8 | `u64` little-endian | `ciphertext_length` |
| 10 | `ciphertext_length` | bytes | `ciphertext` |
| 11 | 2 | `u16` little-endian | `auth_tag_length` |
| 12 | `auth_tag_length` | bytes | `auth_tag` |
| 13 | 4 | `u32` little-endian | `footer_length` |
| 14 | `footer_length` | UTF-8 bytes | `optional_footer` |

#### 4.4.1 magic

- 8 バイト固定
- 値は `CHOBOBK1`
- 先頭一致でバックアップ形式を識別する

#### 4.4.2 format_version

- 形式版数
- MVP 初版は `1`
- 後方互換を壊す変更ではこの値を上げる

#### 4.4.3 header

`header` は UTF-8 でエンコードした JSON 文書とする。

JSON のルールは次の通り。

- ルートは object にする
- 文字列は UTF-8
- 改行や整形用空白は入れない
- キー順は固定する
- 数値は必要最小限の型で表す

推奨キーは次の通り。

- `backup_version`
- `app_version`
- `schema_version`
- `created_at`
- `encryption_scheme`
- `key_wrap_scheme`
- `payload_format`
- `device_id`

#### 4.4.4 wrapped_key

- ラップ済みデータ鍵の生バイト列
- 内部形式は `key_wrap_scheme` で定義する
- 保存形式上は不透明な bytes として扱う

#### 4.4.5 nonce

- 本文暗号化に使う nonce
- 内部形式は `encryption_scheme` で定義する
- 保存形式上は不透明な bytes として扱う

#### 4.4.6 ciphertext

- バックアップ対象データの暗号化本文
- 直列化済み plaintext を暗号化した後の bytes
- plaintext 側の形式は `payload_format` で定義する

#### 4.4.7 auth_tag

- 認証タグの bytes
- 内容改ざん検出に使う
- 長さは `encryption_scheme` で定義する

#### 4.4.8 optional_footer

- 将来拡張用の予備領域
- MVP では空文字列相当でもよい
- 後方互換を壊さずに補助メタデータを足したい場合に使う

#### 4.4.9 endianness

可変長前の長さフィールドは、すべて little-endian とする。  
このルールは Android / iOS / desktop で共通にする。

#### 4.4.10 payload_format

初版の `payload_format` は `json-v1` とする。

plaintext の JSON は次の考え方で作る。

- `accounts`
- `transactions`
- `entries`
- `period_closures`
- `settings`
- `audit_events`

各配列要素は、データベースの row をそのまま表現できる構造にする。  
数値は文字列化せず、アプリ側で扱う型に合わせる。

#### 4.4.11 encryption_scheme

初版の `encryption_scheme` は、`aes-gcm-v1` のように明示的な識別子を持たせる。  
実装では、`nonce`、`ciphertext`、`auth_tag` の対応をこの識別子に固定する。

将来別方式に変える場合は、`format_version` または `encryption_scheme` を更新する。

#### 4.4.12 key_wrap_scheme

初版の `key_wrap_scheme` は、`os-secure-storage-v1` とする。

意味は次の通りである。

- 少量のマスター鍵素材は `flutter_secure_storage` に預ける
- そのマスター鍵素材で data key を包む
- wrapped key の内側も versioned blob として扱う

wrapped key の内側は、次の順でバイト列を並べる。

| 順序 | 長さ | 型 | 内容 |
| --- | ---: | --- | --- |
| 1 | 2 | `u16` little-endian | `wrap_version` |
| 2 | 4 | `u32` little-endian | `wrap_nonce_length` |
| 3 | `wrap_nonce_length` | bytes | `wrap_nonce` |
| 4 | 4 | `u32` little-endian | `wrapped_data_key_length` |
| 5 | `wrapped_data_key_length` | bytes | `wrapped_data_key` |
| 6 | 2 | `u16` little-endian | `wrap_tag_length` |
| 7 | `wrap_tag_length` | bytes | `wrap_tag` |

- `wrap_version` の初版は `1`
- `wrap_nonce` は 12 bytes を想定する
- `wrap_tag` は 16 bytes を想定する
- `wrapped_data_key` は 32 bytes の data key を暗号化した bytes とする

#### 4.4.13 header sample

```json
{"backup_version":1,"app_version":"1.0.0","schema_version":1,"created_at":"2026-03-20T00:00:00Z","encryption_scheme":"aes-gcm-v1","key_wrap_scheme":"os-secure-storage-v1","payload_format":"json-v1","device_id":"device-opaque-001"}
```

#### 4.4.14 backup payload sample

`payload_format = json-v1` の本文例は、次のような配列オブジェクトとする。

```json
{"accounts":[{"account_id":"asset:bank:main","kind":"asset","name":"Main Bank","parent_account_id":null,"is_default":true,"is_archived":false}],"transactions":[{"transaction_id":"txn_001","date":"2026-03-20","type":"expense","status":"posted","description":"Lunch","counterparty":"Cafe","external_ref":null}],"entries":[{"entry_id":"ent_001","transaction_id":"txn_001","account_id":"asset:bank:main","direction":"decrease","amount":1200,"memo":null},{"entry_id":"ent_002","transaction_id":"txn_001","account_id":"expense:food","direction":"increase","amount":1200,"memo":null}],"period_closures":[],"settings":[],"audit_events":[]}
```

実装では、各配列に保存対象レコードを順序付きで格納する。

### 4.1 ヘッダ

ヘッダには少なくとも次を含める。

- バックアップ形式のバージョン
- アプリバージョン
- スキーマバージョン
- 暗号化方式識別子
- 鍵ラップ方式識別子
- 作成日時

### 4.2 本文

本文には、バックアップ対象データを内部オブジェクトとして直列化したものを入れる。

本文は JSON などの構造化形式にしてよいが、平文のまま保存してはならない。

実装境界は [`chobo-backup-codec-interface.md`](chobo-backup-codec-interface.md) に分離する。

## 5. 暗号化方式

鍵管理と再認証の詳細は [`chobo-auth-encryption-spec.md`](chobo-auth-encryption-spec.md) を参照する。

CHOBO のバックアップは、ラップ鍵方式を採用する。

### 5.1 鍵の役割

- データ鍵: バックアップ本文を暗号化するためのランダム鍵
- ラップ鍵: データ鍵を保護するための鍵

### 5.2 方式

1. バックアップごとに新しいデータ鍵を生成する
2. データ鍵で本文を暗号化する
3. ラップ鍵でデータ鍵をラップする
4. ラップ済みデータ鍵と暗号化本文を 1 ファイルにまとめる

### 5.3 鍵管理

- ラップ鍵は OS の安全領域に依存する
- 平文鍵を永続保存しない
- バックアップ専用パスフレーズは MVP では必須にしない
- 将来の方式変更に備えて、鍵管理境界は分離しておく

## 6. バックアップ作成フロー

1. 追加認証を通す
2. DB から一貫したスナップショットを取得する
3. バックアップ用オブジェクトへ整形する
4. 直列化する
5. データ鍵で本文を暗号化する
6. ラップ鍵でデータ鍵をラップする
7. ヘッダ、ラップ済み鍵、暗号化本文、整合性情報を 1 ファイルへ保存する
8. 必要に応じて保存後検証を行う

## 7. 復元フロー

復元は次の順で行う。

1. 追加認証を通す
2. バックアップファイルを選択する
3. 形式検証を行う
4. バージョン確認を行う
5. ラップ済み鍵をアンラップする
6. 本文を復号する
7. 構造検証を行う
8. プロトコル整合性検証を行う
9. 一時 DB へ復元する
10. 最終整合性確認を行う
11. 正本 DB と切り替える

### 7.1 復元処理の擬似コード

```text
function restoreBackup(file):
  requireAdditionalAuth()

  bytes = readAllBytes(file)
  parsed = parseBackupFile(bytes)

  if parsed.magic != "CHOBOBK1":
    fail("invalid format")

  if parsed.format_version != 1:
    fail("unsupported format")

  header = parseJson(parsed.header)
  validateHeader(header)

  wrapKey = loadMasterKeyFromSecureStorage()
  dataKey = unwrapDataKey(parsed.wrapped_key, wrapKey, header.key_wrap_scheme)
  plaintext = decryptPayload(
    ciphertext = parsed.ciphertext,
    key = dataKey,
    nonce = parsed.nonce,
    aad = [parsed.magic, parsed.format_version, parsed.header]
  )

  payload = parseJson(plaintext)
  validatePayloadStructure(payload)
  validateProtocolIntegrity(payload)

  tempDb = createTemporaryDatabase()
  importPayloadToDatabase(tempDb, payload)
  runFinalIntegrityCheck(tempDb)
  replacePrimaryDatabaseWith(tempDb)
```

### 7.2 バックアップ作成の擬似コード

```text
function createBackup():
  requireAdditionalAuth()

  snapshot = readConsistentSnapshotFromDatabase()
  payload = serializePayload(snapshot, format="json-v1")

  dataKey = generateRandomBytes(32)
  nonce = generateRandomBytes(12)
  ciphertext, authTag = encryptPayload(
    plaintext = payload,
    key = dataKey,
    nonce = nonce,
    aad = ["CHOBOBK1", 1, headerJson]
  )

  wrapKey = loadMasterKeyFromSecureStorage()
  wrappedKey = wrapDataKey(dataKey, wrapKey, scheme="os-secure-storage-v1")

  writeSingleFile(
    magic = "CHOBOBK1",
    format_version = 1,
    header = headerJson,
    wrapped_key = wrappedKey,
    nonce = nonce,
    ciphertext = ciphertext,
    auth_tag = authTag,
    footer = ""
  )
```

## 8. 検証ルール

復元前後では、次の検証を分けて行う。

- 形式検証: ファイルがバックアップ形式として読めるか
- 構造検証: 必須フィールドが揃っているか
- 整合性検証: プロトコル上の不正がないか

復号失敗や構造破損があっても、既存 DB は変更しない。

## 9. 自動バックアップ

MVP では、手動バックアップに加えて、端末内自動バックアップを持つ。

- 保存先はアプリ管理領域とする
- 直近 7 世代を保持する
- 容量逼迫時は最古世代から削除する
- 最低 1 世代は必ず残す

自動バックアップは、直近の復旧可能性を高める補助機能と位置づける。

## 10. 失敗時の扱い

- バックアップ作成失敗は既存データに影響させない
- バックアップ破損時は DB へ一切書き込まない
- 復号失敗時は部分復元しない
- 復元途中失敗時は一時 DB のみ破棄する
- ローカル DB 破損時は通常起動せず、復旧モードへ入る

ユーザーには、少なくとも次を明示する。

- 何が失敗したか
- 現在のデータが守られているか
- 次に何をすればよいか

## 11. 重要操作

次の操作は追加認証を必須にする。

- バックアップ作成
- バックアップ復元
- バックアップ関連設定変更
- データ初期化や全削除

## 12. 管理上の注意

- バックアップ内容をログに出さない
- 復号情報や鍵素材を保存しない
- バックアップ本文をサポート用画面に表示しない
- 復元導線は深い管理画面に置く
- テスト観点は [`chobo-backup-test-cases.md`](chobo-backup-test-cases.md) に分離する
