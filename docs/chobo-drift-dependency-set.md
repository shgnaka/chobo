---
title: "CHOBO drift 前提の依存セット"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-flutter-dependency-matrix.md"
---

# CHOBO drift 前提の依存セット

## 1. 目的

この文書は、CHOBO を Flutter + drift 前提で作るときの、現時点での依存セット案を整理する。

採用済みではなく、実装開始前の準備メモとして扱う。

## 2. 採用方針

- UI は Flutter で共通化する
- DB 層は drift を中核にする
- Android 先行で始め、iOS に展開しやすい構成にする
- desktop も将来の拡張先として壊しにくい構成にする
- 依存は最小限に抑える

## 3. 中核依存

### 3.1 `drift`

- 役割: DB スキーマ、クエリ、マイグレーション、DAO の中核
- 採用理由:
  - 型安全に DB を扱いやすい
  - 複数画面・複数集計でも DB 層を整理しやすい
  - Android / iOS / desktop に同じ考え方で広げやすい
- 閉じ込め先: `data/local_db`

### 3.2 `drift_flutter`

- 役割: Flutter 側から drift を使うための接続補助
- 採用理由:
  - Flutter アプリとしての初期化を整理しやすい
  - プラットフォームごとの差を減らしやすい
- 閉じ込め先: `data/local_db`

### 3.3 `sqlite3_flutter_libs`

- 役割: モバイルや desktop で SQLite 実装を確実に用意するための補助
- 採用理由:
  - platform ごとの SQLite バイナリ差分を吸収しやすい
  - iOS / desktop でも動作前提を揃えやすい
- 閉じ込め先: `data/local_db`

### 3.4 `path_provider`

- 役割: DB ファイルやバックアップの保存先取得
- 採用理由:
  - Android / iOS / desktop で保存先の考え方を揃えやすい
  - 保存先ロジックを OS ごとに分岐しやすい
- 判断: 採用
- 閉じ込め先: `platform/files`

### 3.5 `flutter_secure_storage`

- 役割: DB 鍵やバックアップ鍵など、少量の秘密情報を OS の安全領域に預ける
- 採用理由:
  - Keychain / Encrypted Shared Preferences を自前で包まずに済む
  - Android / iOS の両方で同じ扱いにしやすい
  - 将来 desktop を足しても、秘密情報の置き場所を 1 つの境界に閉じ込めやすい
- 注意:
  - 大きいデータ保存用ではない
  - 保存対象は鍵やトークンなどの小さい値に限る
- 判断: 採用
- 閉じ込め先: `platform/storage`

## 4. ほぼ必要になる候補

### 4.1 `flutter_riverpod`

- 役割: 状態管理、Repository 配線、非同期データの扱い
- 採用理由:
  - 画面とデータ層を分離しやすい
  - drift の DB 操作と相性がよい
  - desktop を足しても構造を保ちやすい
- 判断: 採用
- 代替案: 小規模なら `setState` や薄い Controller

### 4.2 `go_router`

- 役割: 画面遷移
- 採用理由:
  - 画面数が増えてもルート定義を整理しやすい
  - Android / iOS / desktop で同じ遷移構造を保ちやすい
- 判断: 採用
- 代替案: 標準 Navigator

### 4.3 `local_auth`

- 役割: 重要操作時の追加認証
- 採用理由:
  - 生体認証と端末認証を OS 標準に寄せられる
  - バックアップ・復元・設定変更の安全性を上げやすい
- 判断: 採用
- 閉じ込め先: `platform/auth`

### 4.4 `intl`

- 役割: 日付、金額、ロケール整形
- 採用理由:
  - ロケール差分を減らしやすい
  - 月次集計や明細表示で再利用しやすい

## 5. バックアップ周辺

### 5.1 `file_picker`

- 役割: 復元対象ファイル選択
- 採用理由:
  - Android / iOS / desktop で選択 UI を揃えやすい
- 判断: 採用
- 閉じ込め先: `platform/files`

### 5.2 `share_plus`

- 役割: エクスポートやバックアップ共有
- 採用理由:
  - 端末外への受け渡しを共通化しやすい
- 判断: 今回は見送り
- 閉じ込め先: `platform/files`

### 5.3 `archive`

- 役割: バックアップの圧縮やパッケージ化
- 採用理由:
  - 将来のバックアップ形式拡張に使いやすい
- 判断: MVP では不要
- 注意:
  - MVP では単一ファイルで足りるかを先に判断する

## 6. まだ採用を急がない候補

- `connectivity_plus`
- `permission_handler`
- `flutter_secure_storage`
- `uuid`
- `collection`

理由:
- いまの仕様で本当に必要かを都度確認したい
- 代替が標準機能や小さい自前実装で足りる可能性がある

## 7. フォルダの閉じ込め方

依存を増やす場合でも、次のように層を分ける。

- `lib/domain`: 純粋なドメインモデル
- `lib/data/local_db`: drift と SQLite 周り
- `lib/data/repository`: 永続化の公開窓口
- `lib/platform/auth`: 生体認証などの OS 依存
- `lib/platform/files`: 保存先や共有、ファイル選択
- `lib/app`: アプリ起動、ルーティング、DI
- `lib/features/...`: 画面ごとの UI と状態管理

## 8. 次の確認事項

この依存セットを実装に落とす前に、次を決める。

- バックアップ共有を `share_plus` でよいか
- desktop を最初から CI に入れるか
