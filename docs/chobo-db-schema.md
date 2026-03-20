---
title: "CHOBO DB スキーマ仕様"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-spec-memo.md"
---

# CHOBO DB スキーマ仕様

## 1. 目的

この文書は、CHOBO のローカル DB に保存する正本データの構造を定義する。

対象は次のとおり。

- 勘定マスタ
- 取引履歴
- 取引エントリ
- 締め情報
- 設定
- 監査イベント

## 2. 前提

- 単一端末の個人利用を前提とする
- 初期 MVP は単一通貨とする
- 正本は端末内の組み込み DB に置く
- 正本データは `transactions + entries` を中心に再計算可能であることを優先する

## 3. テーブル一覧

### 3.1 `accounts`

勘定マスタを保持する。

#### 列

- `account_id`
- `kind`
- `name`
- `parent_account_id`
- `is_default`
- `is_archived`
- `created_at`
- `updated_at`

#### 制約

- `account_id` は一意
- `kind` は `asset | liability | income | expense | equity`
- `parent_account_id` は任意
- `is_default = true` の勘定は標準勘定として扱う
- `kind` は、既存取引がある場合は変更禁止
- 標準勘定の `account_id` と `kind` は固定する

### 3.2 `transactions`

取引のメタデータを保持する。

#### 列

- `transaction_id`
- `date`
- `type`
- `status`
- `description`
- `counterparty`
- `external_ref`
- `period_lock_state`
- `created_at`
- `updated_at`

#### 制約

- `transaction_id` は一意
- `type` は `income | expense | transfer | credit_expense | liability_payment`
- `status` は `posted | pending | void`
- `posted` のみ残高と集計の計算対象とする
- `pending` は未計上の取引として扱う
- `void` は取消として扱い、残高計算から除外する
- 締め済み期間に属する取引は直接更新しない

### 3.3 `entries`

取引に属する増減明細を保持する。

#### 列

- `entry_id`
- `transaction_id`
- `account_id`
- `direction`
- `amount`
- `memo`

#### 制約

- `entry_id` は一意
- `transaction_id` は `transactions.transaction_id` を参照する
- `account_id` は `accounts.account_id` を参照する
- `direction` は `increase | decrease`
- `amount` は正数
- 1 取引あたり `entries` は 2 件以上

### 3.4 `period_closures`

締め済み期間を保持する。

#### 列

- `closure_id`
- `start_date`
- `end_date`
- `closed_at`
- `note`

#### 役割

- どの期間が締め済みかを管理する
- 締め済み期間の直接編集を防ぐために使う

### 3.5 `settings`

アプリ設定を保持する。

#### 列

- `setting_key`
- `setting_value`

#### 例

- 最終バックアップ日時
- 残高照合頻度
- 生体認証の利用可否

### 3.6 `audit_events`

重要な状態変化の履歴を保持する。

#### 列

- `audit_event_id`
- `event_type`
- `target_id`
- `payload`
- `created_at`

#### 役割

- 取引の作成、更新、取消、訂正を追跡する
- 残高照合の完了を追跡する
- 勘定更新やバックアップなどの重要操作を記録する

## 4. 保存ルール

1. すべての取引保存前にプロトコル整合性チェックを行う
2. `transactions` と `entries` は同一 DB トランザクションで保存する
3. 締め済み期間に属する取引は直接更新禁止とする
4. 締め済み期間の修正は `void` または新規訂正取引追加で表す
5. `account.kind` は既存取引がある場合は変更禁止とする

## 5. 読み取りと再計算

残高は、原則として `posted` 取引から再計算できる形を正本とする。

方針は次のとおり。

- 正本は `transactions + entries`
- 残高と月次集計は再計算可能であることを前提にする
- 表示高速化のためにキャッシュを持ってもよい
- キャッシュは破棄可能で、いつでも再構築できること

## 6. 暗号化境界

DB 全体は保存時暗号化を前提とする。

- DB ファイル全体を保護する
- 平文での永続化を前提にしない
- アプリ層暗号化は将来の拡張として分離可能にする

## 7. Repository 境界

DB 直接参照を各画面に散らさず、Repository を通す。

- `AccountRepository`
- `TransactionRepository`
- `ClosureRepository`
- `ReconciliationRepository`
- `SettingsRepository`
- `AuditEventRepository`

## 8. 変更時の注意

- スキーマ変更時は `schema_version` を持つ前提で移行できるようにする
- バックアップ復元時は、構造検証と整合性検証を分ける
- 締め済みデータを壊す変更は、必ず移行ルールを明示する
