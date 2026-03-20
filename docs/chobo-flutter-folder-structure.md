---
title: "CHOBO Flutter folder structure"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-drift-dependency-set.md"
---

# CHOBO Flutter folder structure

## 1. 目的

この文書は、Flutter + drift 前提で CHOBO を実装するときの、Android 先行・iOS 追随・desktop 拡張を見据えたフォルダ構成案を示す。

## 2. 基本方針

- UI とドメインを分離する
- drift を data 層に閉じ込める
- OS 固有処理を platform 層に閉じ込める
- features 単位で画面と状態をまとめる
- desktop 追加時にアプリ全体を崩さない

## 3. 推奨構成

```text
lib/
  main.dart
  app/
    chobo_app.dart
    router.dart
  domain/
    account/
    transaction/
    reconciliation/
    backup/
    audit/
    value_objects/
  data/
    local_db/
      chobo_drift_connection.dart
      app_database.dart
      tables/
      daos/
      mappers/
      migrations/
    repository/
      account_repository.dart
      transaction_repository.dart
      entry_repository.dart
      ledger_repository.dart
    service/
      monthly_summary_service.dart
      settings_repository.dart
      audit_repository.dart
  platform/
    auth/
      local_auth_service.dart
    files/
      backup_file_service.dart
      file_picker_service.dart
      share_service.dart
    storage/
      secure_key_store.dart
  features/
    home/
    transactions/
    reconciliation/
    settings/
    backup/
    accounts/
  shared/
    widgets/
    theme/
    utils/
```

現時点の実装はこのうち以下を先に置いている。

- `lib/main.dart`
- `lib/app/chobo_app.dart`
- `lib/app/router.dart`
- `lib/features/home/home_screen.dart`
- `lib/data/local_db/app_database.dart`
- `lib/data/local_db/chobo_drift_connection.dart`
- `lib/data/repository/account_repository.dart`
- `lib/data/repository/transaction_repository.dart`
- `lib/data/repository/entry_repository.dart`
- `lib/data/repository/ledger_repository.dart`

## 4. 各層の役割

### 4.1 `app`

- 起動処理
- DI の組み立て
- ルーティング
- アプリ全体の設定

### 4.2 `domain`

- 勘定、取引、照合、バックアップ、監査の純粋なモデル
- Flutter や DB に依存しないロジック
- 仕様の土台

### 4.3 `data/local_db`

- drift 定義
- SQL 相当の永続化
- マイグレーション
- Row と Domain の変換

### 4.4 `data/repository`

- 画面や use case が直接 DB を触らないための窓口
- 読み書きの責務をまとめる

### 4.5 `platform`

- OS 固有の認証
- ファイル選択
- 共有
- 保存先取得

### 4.6 `features`

- 画面単位の UI
- 状態管理
- 入力フォーム
- 一覧
- 詳細

### 4.7 `shared`

- 共通 widget
- テーマ
- 汎用ユーティリティ

## 5. desktop を見据えたポイント

- 画面解像度に依存しないレイアウトにする
- タブレットや desktop ではサイドバーや 2 カラムに拡張しやすい UI にする
- ファイル入出力は platform 層に隔離する
- DB スキーマ変更は data 層だけで閉じる
- desktop 特有のショートカットやメニューは app 層の追加で吸収する

## 6. iOS 追随を見据えたポイント

- Android 専用コードを features に散らさない
- 生体認証や安全領域は platform/auth と platform/storage に閉じる
- 保存先や共有は platform/files に閉じる
- 権限まわりの差分はサービス境界で吸収する

## 7. 実装順のおすすめ

1. `domain`
2. `data/local_db`
3. `data/repository`
4. `platform`
5. `features`
6. `app`

理由:
- まずドメインを固めると、DB と UI のブレが減る
- 次に DB を閉じると、永続化ルールが安定する
- その後に UI と platform を載せると、Android 先行でも後戻りしにくい

## 8. 将来の分岐

desktop を本格的に入れる場合でも、次の境界が保てていれば崩れにくい。

- domain は変更しない
- data 層の実装差し替えを最小限にする
- platform 層で OS 差分を閉じる
- features は共通のまま保つ
