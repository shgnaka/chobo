---
title: "CHOBO DB スキーマ仕様"
date: "2026-03-20"
updated: "2026-03-21"
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
- ポイント口座 (points_accounts)
- ポイント取引 (points_transactions)
- 定期取引テンプレート (recurring_templates)

## 2. 前提

- 単一端末の個人利用を前提とする
- 初期 MVP は単一通貨とする
- 正本は端末内の組み込み DB に置く
- 正本データは `transactions + entries` を中心に再計算可能であることを優先する
- SQLite の `schema_version` は 1 から始める

## 3. スキーマ方針

- SQLite のテーブルは `TEXT` / `INTEGER` を基本にする
- 真偽値は `INTEGER` の `0 | 1` で表す
- 日時は ISO 8601 文字列を `TEXT` で保存する
- 外部キーはアプリ層だけでなく DB 側でも持つ
- 1 取引あたり 2 件以上の `entries` 制約は、保存ロジック側で担保する

## 4. テーブル一覧

### 4.1 `accounts`

勘定マスタを保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `account_id` | `TEXT` | `PRIMARY KEY` |
| `kind` | `TEXT` | `NOT NULL` / `CHECK(kind IN ('asset', 'liability', 'income', 'expense', 'equity'))` |
| `name` | `TEXT` | `NOT NULL` |
| `parent_account_id` | `TEXT` | `REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE SET NULL` |
| `is_default` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(is_default IN (0, 1))` |
| `is_archived` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(is_archived IN (0, 1))` |
| `created_at` | `TEXT` | `NOT NULL` |
| `updated_at` | `TEXT` | `NOT NULL` |

#### 制約

- `account_id` は一意
- `parent_account_id` は任意
- `is_default = true` の勘定は標準勘定として扱う
- `kind` は、既存取引がある場合は変更禁止
- 標準勘定の `account_id` と `kind` は固定する
- `is_default` と `is_archived` は SQLite 上では `0 | 1` で持つ

#### 索引

- `parent_account_id`

### 4.2 `transactions`

取引のメタデータを保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `transaction_id` | `TEXT` | `PRIMARY KEY` |
| `date` | `TEXT` | `NOT NULL` |
| `type` | `TEXT` | `NOT NULL` / `CHECK(type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement'))` |
| `status` | `TEXT` | `NOT NULL` / `CHECK(status IN ('posted', 'pending', 'void'))` |
| `description` | `TEXT` | 任意 |
| `counterparty` | `TEXT` | 任意 |
| `external_ref` | `TEXT` | 任意 |
| `original_transaction_id` | `TEXT` | `REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL` |
| `refund_type` | `TEXT` | `CHECK(refund_type IN ('full', 'partial') OR refund_type IS NULL)` |
| `period_lock_state` | `TEXT` | `NOT NULL DEFAULT 'open'` |
| `created_at` | `TEXT` | `NOT NULL` |
| `updated_at` | `TEXT` | `NOT NULL` |

#### 制約

- `transaction_id` は一意
- `posted` のみ残高と集計の計算対象とする
- `pending` は未計上の取引として扱う
- `void` は取消として扱い、残高計算から除外する
- 締め済み期間に属する取引は直接更新しない

#### 索引

- `date`
- `status`
- `type`

### 4.3 `entries`

取引に属する増減明細を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `entry_id` | `TEXT` | `PRIMARY KEY` |
| `transaction_id` | `TEXT` | `NOT NULL` / `REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE CASCADE` |
| `account_id` | `TEXT` | `NOT NULL` / `REFERENCES accounts(account_id) ON UPDATE CASCADE ON DELETE RESTRICT` |
| `direction` | `TEXT` | `NOT NULL` / `CHECK(direction IN ('increase', 'decrease'))` |
| `amount` | `INTEGER` | `NOT NULL` / `CHECK(amount > 0)` |
| `memo` | `TEXT` | 任意 |

#### 制約

- `entry_id` は一意
- `transaction_id` は `transactions.transaction_id` を参照する
- `account_id` は `accounts.account_id` を参照する
- `direction` は `increase | decrease`
- `amount` は正数
- 1 取引あたり `entries` は 2 件以上

#### 索引

- `transaction_id`
- `account_id`

### 4.4 `period_closures`

締め済み期間を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `closure_id` | `TEXT` | `PRIMARY KEY` |
| `start_date` | `TEXT` | `NOT NULL` |
| `end_date` | `TEXT` | `NOT NULL` |
| `closed_at` | `TEXT` | `NOT NULL` |
| `note` | `TEXT` | 任意 |

#### 役割

- どの期間が締め済みかを管理する
- 締め済み期間の直接編集を防ぐために使う
- `start_date <= end_date` を満たす

#### 索引

- `start_date`
- `end_date`

### 4.5 `settings`

アプリ設定を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `setting_key` | `TEXT` | `PRIMARY KEY` |
| `setting_value` | `TEXT` | `NOT NULL` |

#### 例

- 最終バックアップ日時
- 残高照合頻度
- 生体認証の利用可否

### 4.6 `audit_events`

重要な状態変化の履歴を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `audit_event_id` | `TEXT` | `PRIMARY KEY` |
| `event_type` | `TEXT` | `NOT NULL` |
| `target_id` | `TEXT` | `NOT NULL` |
| `payload` | `TEXT` | `NOT NULL` |
| `created_at` | `TEXT` | `NOT NULL` |

#### 役割

- 取引の作成、更新、取消、訂正を追跡する
- 残高照合の完了を追跡する
- 勘定更新やバックアップなどの重要操作を記録する

#### 索引

- `created_at`
- `target_id`

### 4.7 `points_accounts`

ポイントサービスの口座を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `points_account_id` | `TEXT` | `PRIMARY KEY` |
| `name` | `TEXT` | `NOT NULL` |
| `points_currency` | `TEXT` | `NOT NULL` |
| `exchange_rate` | `INTEGER` | `NOT NULL DEFAULT 1` / `CHECK(exchange_rate > 0)` |
| `is_default` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(is_default IN (0, 1))` |
| `is_archived` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(is_archived IN (0, 1))` |
| `created_at` | `TEXT` | `NOT NULL` |
| `updated_at` | `TEXT` | `NOT NULL` |

#### 役割

- T-Point、Rakuten Super Points などのポイント口座を管理する
- `points_currency` はポイント記号（例: 'T', 'R'）
- `exchange_rate` はポイント1单位のJPY価値

#### 索引

- `name`

### 4.8 `points_transactions`

ポイントの増減履歴を保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `points_transaction_id` | `TEXT` | `PRIMARY KEY` |
| `points_account_id` | `TEXT` | `NOT NULL` / `REFERENCES points_accounts(points_account_id) ON UPDATE CASCADE ON DELETE CASCADE` |
| `transaction_id` | `TEXT` | `REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL` |
| `direction` | `TEXT` | `NOT NULL` / `CHECK(direction IN ('earned', 'redeemed', 'expired', 'adjusted'))` |
| `points_amount` | `INTEGER` | `NOT NULL` |
| `jpy_value` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(jpy_value >= 0)` |
| `description` | `TEXT` | 任意 |
| `occurred_at` | `TEXT` | `NOT NULL` |
| `expiration_date` | `TEXT` | 任意 |
| `created_at` | `TEXT` | `NOT NULL` |

#### 役割

- ポイントの獲得，使用，失効、調整を記録する
- `earned` はポイント獲得
- `redeemed` はポイント使用
- `expired` はポイント失効
- `adjusted` は精算調整
- `expiration_date` はポイントの失効予定日（earning時に設定）

#### 索引

- `points_account_id`
- `transaction_id`
- `created_at`

### 4.9 `recurring_templates`

定期取引のテンプレートを保持する。

#### 列

| 列名 | 型 | 制約 |
| --- | --- | --- |
| `template_id` | `TEXT` | `PRIMARY KEY` |
| `name` | `TEXT` | `NOT NULL` |
| `transaction_type` | `TEXT` | `NOT NULL` / `CHECK(transaction_type IN ('income', 'expense', 'transfer', 'credit_expense', 'liability_payment', 'advance_payment', 'reimbursement'))` |
| `frequency` | `TEXT` | `NOT NULL` / `CHECK(frequency IN ('daily', 'weekly', 'monthly', 'yearly'))` |
| `interval_value` | `INTEGER` | `NOT NULL DEFAULT 1` / `CHECK(interval_value > 0)` |
| `start_date` | `TEXT` | `NOT NULL` |
| `end_date` | `TEXT` | 任意 |
| `next_generation_date` | `TEXT` | 任意 |
| `last_generated_transaction_id` | `TEXT` | `REFERENCES transactions(transaction_id) ON UPDATE CASCADE ON DELETE SET NULL` |
| `entries_template` | `TEXT` | `NOT NULL` (JSON) |
| `is_active` | `INTEGER` | `NOT NULL DEFAULT 1` / `CHECK(is_active IN (0, 1))` |
| `auto_post` | `INTEGER` | `NOT NULL DEFAULT 0` / `CHECK(auto_post IN (0, 1))` |
| `created_at` | `TEXT` | `NOT NULL` |
| `updated_at` | `TEXT` | `NOT NULL` |

#### 役割

- 繰り返し取引のテンプレートを管理する
- `frequency` は生成周期
- `interval_value` は周期の間隔（例: 2週間隔）
- `entries_template` はJSON形式で勘定と金額を記録
- `is_active` は有効/一時停止
- `auto_post` は自動計上するかどうか

#### 索引

- `next_generation_date`
- `is_active`

## 5. 保存ルール

1. すべての取引保存前にプロトコル整合性チェックを行う
2. `transactions` と `entries` は同一 DB トランザクションで保存する
3. 締め済み期間に属する取引は直接更新禁止とする
4. 締め済み期間の修正は `void` または新規訂正取引追加で表す
5. `account.kind` は既存取引がある場合は変更禁止とする

## 6. 読み取りと再計算

残高は、原則として `posted` 取引から再計算できる形を正本とする。

方針は次のとおり。

- 正本は `transactions + entries`
- 残高と月次集計は再計算可能であることを前提にする
- 表示高速化のためにキャッシュを持ってもよい
- キャッシュは破棄可能で、いつでも再構築できること

## 7. 暗号化境界

DB 全体は保存時暗号化を前提とする。

- DB ファイル全体を保護する
- 平文での永続化を前提にしない
- アプリ層暗号化は将来の拡張として分離可能にする

## 8. Repository 境界

DB 直接参照を各画面に散らさず、Repository を通す。

- `AccountRepository`
- `TransactionRepository`
- `EntryRepository`
- `ClosureRepository`
- `ReconciliationRepository`
- `SettingsRepository`
- `AuditEventRepository`
- `PointsRepository`
- `RecurringTemplateRepository`

## 9. 変更時の注意

- スキーマ変更時は `schema_version` を持つ前提で移行できるようにする
- バックアップ復元時は、構造検証と整合性検証を分ける
- 締め済みデータを壊す変更は、必ず移行ルールを明示する

## 10. バージョン履歴

| バージョン | 日付 | 変更内容 |
| --- | --- | --- |
| 1 | 2026-03-20 | MVP: 基本6テーブル |
| 2 | - | (既存バージョン) |
| 3 | - | (既存バージョン) |
| 4 | 2026-03-21 | 取引型の拡張（advance_payment, reimbursement）、返金対応、定期取引対応 |
| 5 | 2026-03-21 | ポイント失効日対応（expiration_date追加） |

### バージョン4の変更点

- `transactions` テーブルに `original_transaction_id`、`refund_type` 列を追加
- `points_accounts`、`points_transactions` テーブルを追加
- `recurring_templates` テーブルを追加

### バージョン5の変更点

- `points_transactions` テーブルに `expiration_date` 列を追加
- 取引タイプに `advance_payment`、`reimbursement` を追加
