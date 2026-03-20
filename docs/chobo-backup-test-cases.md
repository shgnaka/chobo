---
title: "CHOBO バックアップテストケース"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-backup-spec.md"
---

# CHOBO バックアップテストケース

## 1. 目的

この文書は、単一ファイル形式のバックアップ仕様に対して、実装前から用意しておくべきテスト観点を整理する。

## 2. 方針

- まず round-trip を保証する
- 次に破損系と互換性系を固める
- 既存 DB を壊さないことを最重要にする
- 失敗時に一時領域だけが壊れることを確認する

## 3. 作成系

### 3.1 正常作成

- 空に近い最小データでバックアップを作成できる
- 標準的なデータ量でバックアップを作成できる
- 監査イベントを含むデータでバックアップを作成できる
- 締め済み情報を含むデータでバックアップを作成できる

### 3.2 形式確認

- magic が `CHOBOBK1` で始まる
- format_version が `1`
- header が UTF-8 JSON として読める
- header に必須キーが揃っている
- payload_format が `json-v1`
- key_wrap_scheme が `os-secure-storage-v1`
- encryption_scheme が `aes-gcm-v1`

### 3.3 長さ整合

- header_length が実データ長と一致する
- wrapped_key_length が実データ長と一致する
- nonce_length が実データ長と一致する
- ciphertext_length が実データ長と一致する
- auth_tag_length が実データ長と一致する
- footer_length が実データ長と一致する

## 4. 復元系

### 4.1 正常復元

- 直前に作成したバックアップを完全復元できる
- 再起動後も同じ内容が残る
- 監査イベントも復元される

### 4.2 部分状態確認

- 復元中に失敗しても既存 DB は変わらない
- 復元中断後、一時 DB だけが破棄される
- 最終切り替え前なら正本 DB が温存される

### 4.3 データ整合

- 復元後の account 数が一致する
- 復元後の transaction 数が一致する
- 復元後の entry 数が一致する
- 締め済み期間の状態が一致する
- 監査イベント数が一致する

## 5. 破損系

### 5.1 形式破損

- magic が違う場合に失敗する
- format_version 未対応で失敗する
- header_length が壊れている場合に失敗する
- wrapped_key_length が壊れている場合に失敗する
- nonce_length が壊れている場合に失敗する
- ciphertext_length が壊れている場合に失敗する
- auth_tag_length が壊れている場合に失敗する

### 5.2 本文破損

- ciphertext の 1 byte 改ざんで失敗する
- auth_tag の 1 byte 改ざんで失敗する
- wrapped_key の 1 byte 改ざんで失敗する
- nonce の 1 byte 改ざんで失敗する

### 5.3 切断

- ファイル途中で切れていたら失敗する
- ヘッダだけ存在する場合に失敗する
- 本文だけ欠けている場合に失敗する

### 5.4 不正 JSON

- header が JSON として壊れている場合に失敗する
- payload が JSON として壊れている場合に失敗する
- payload に必須配列が欠けている場合に失敗する

## 6. 互換性系

### 6.1 将来互換

- format_version 1 の過去ファイルを復元できる
- payload_format `json-v1` を読み込める
- encryption_scheme `aes-gcm-v1` を読み込める

### 6.2 非対応

- 未知の format_version では丁寧に失敗する
- 未知の payload_format では丁寧に失敗する
- 未知の encryption_scheme では丁寧に失敗する

## 7. OS・権限系

- 追加認証がキャンセルされたら処理を止める
- secure storage から鍵を取得できない場合は失敗する
- ファイル選択をキャンセルしたら処理を止める
- 保存先に書き込めない場合は既存 DB を壊さない

## 8. 性能・容量系

- 小さいデータで問題なく動く
- MVP 想定の大きさで復元が破綻しない
- 途中まで読み込んだだけでメモリが膨らみすぎない

## 9. 最低限の round-trip

まず最初に通すべきテストは次の 3 つである。

1. 最小データの作成・復元
2. 標準データの作成・復元
3. 破損ファイルを復元せず失敗すること

## 10. 対応テストファイル

- `test/backup/backup_file_codec_test.dart`
- `test/backup/backup_roundtrip_test.dart`
- `test/backup/backup_recovery_test.dart`
