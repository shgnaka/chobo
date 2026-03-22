---
title: "CHOBO API 仕様"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-spec-memo.md"
---

# CHOBO API 仕様

## 1. 目的

この文書は、CHOBO のアプリケーション層が提供する主要なユースケース API を定義する。

対象は次のとおり。

- 月次集計
- 残高照合
- 締め処理
- バックアップ作成と復元
- 勘定管理
- 監査イベント記録

HTTP API に限定せず、アプリ内部のサービス境界として読める形で定義する。

## 2. 共通前提

- 入力は生活用語から内部モデルへ変換される
- 主要な保存操作は Repository 経由で行う
- 重要操作は再認証を伴うことがある
- 失敗時は既存データを守ることを優先する

## 3. 月次集計 API

### 3.1 概要

月次集計は、少なくとも次の出力を返す。

- 月初総資産
- 月末総資産
- 月末総負債
- 月末純資産相当
- 費用カテゴリ別合計
- 収益カテゴリ別合計
- 資産間移動合計
- カード未払増加額
- カード支払額

### 3.2 返却イメージ

```json
{
  "month": "2026-03",
  "assets_end": 320000,
  "liabilities_end": 42000,
  "net_assets_end": 278000,
  "expense_totals": {
    "food": 28000,
    "housing": 70000
  },
  "income_totals": {
    "salary": 300000
  },
  "transfer_totals": {
    "saving": 50000,
    "e_money": 12000
  },
  "card_accrual": 35000,
  "card_payment": 30000
}
```

### 3.3 主要責務

- `posted` をもとに集計する
- `expense` と `cash_out_expenses` を混同しない
- `credit_expense` と `liability_payment` を分離して集計する
- 必要なら再計算またはキャッシュ再構築を行う

## 4. 勘定管理 API

### 4.1 AccountRepository 相当

勘定管理は次を提供する。

- 勘定一覧取得
- 勘定追加
- 勘定更新
- 勘定アーカイブ
- 標準勘定セット再投入

### 4.2 ルール

- 表示名変更は許可する
- 標準勘定は `account_id` と `kind` を固定し、ユーザー編集では変えない
- `kind` 変更は、既存取引がある場合は禁止する
- 標準勘定復元は、欠けている標準勘定のみを再追加する
- 標準勘定復元は、既存のユーザー勘定やカスタム勘定を変更しない
- 標準勘定復元は、すでに存在する標準勘定を上書きしない

## 5. 取引管理 API

### 5.1 TransactionRepository 相当

取引管理は次を提供する。

- 取引とエントリの保存
- 取引詳細取得
- 条件付き取引一覧取得
- 未締め期間の取引更新
- 締め済み取引の `void`
- 訂正取引の追加

### 5.2 バリデーション

- 取引保存前にプロトコル整合性を検証する
- すべての金額は正数である
- `entries` は 2 件以上である
- `transfer` は同一通貨の `asset` 間に限る
- `credit_expense` は `liability` を含む

## 6. 締め API

### 6.1 ClosureService 相当

締め API は次を提供する。

- 締め前チェック
- 締め処理実行
- 締め履歴取得
- 指定日が締め済みかの判定

### 6.2 ルール

- 締めはユーザーの明示操作で行う
- 締め済み期間は直接編集できない
- 修正は取消または訂正取引で表す

## 7. 残高照合 API

### 7.1 ReconciliationService 相当

残高照合 API は次を提供する。

- 実残高と帳簿残高の比較
- 差額計算
- 照合記録の保存
- 差異調整フローへの接続

### 7.2 基本対象

- `asset:cash`
- `asset:bank:main`
- `asset:e_money`
- `liability:card:main`

### 7.3 ルール

- 照合は対象勘定ごとに記録する
- 未完了の照合が残る場合は締め前に警告する
- 締めは照合の完了を必須条件にしない

## 8. バックアップ API

### 8.1 BackupService 相当

バックアップ API は次を提供する。

- バックアップ生成
- バックアップ検証
- バックアップ復元
- バックアップ作成時の認証、整形、暗号化、保存

### 8.2 ルール

- バックアップは常に暗号化する
- 平文バックアップは提供しない
- 復元は一時領域を経由し、成功時のみ正本へ切り替える

## 9. 監査イベント API

### 9.1 AuditEventRepository 相当

監査イベント API は次を提供する。

- 監査イベント記録
- 監査イベント一覧取得

### 9.2 記録対象

- 取引作成
- 未締め期間の取引更新
- 残高照合の完了
- 締め済み期間の取引取消
- 訂正取引の追加
- 差異調整の実行
- 期間の締め
- 勘定作成
- 勘定更新
- 勘定アーカイブ
- 標準勘定セット復元
- バックアップ作成
- バックアップ復元
- 重要設定変更

## 10. Service 境界

API の実装では、次の責務を混ぜない。

- UI は DB を直接触らない
- Repository は保存済みデータの出し入れを担当する
- Service は複数操作の束ね役とする
- 暗号化処理は CryptoService に閉じ込める
- バックアップ処理は BackupService に閉じ込める

## 11. 予測 API

### 11.1 ForecastService 相当

予測 API は月末の見通しを提供する。

- 月末残高予測
- 未計上取引による支出/収入
- 定期取引による予定額
- 日次残高推移予測
- 勘定別請求・支払サイクル情報
- 支払期日別予測

### 11.2 返却イメージ

```json
{
  "month": "2026-03",
  "current_balance": 280000,
  "pending_expenses": 15000,
  "pending_income": 5000,
  "upcoming_recurring_expenses": 80000,
  "upcoming_recurring_income": 300000,
  "predicted_expenses": 95000,
  "predicted_income": 305000,
  "forecast_balance": 490000,
  "daily_forecasts": [
    {
      "date": "2026-03-01",
      "predicted_balance": 280000,
      "pending_amount": 5000,
      "recurring_amount": 0
    }
  ],
  "billing_cycles": [
    {
      "account_id": "liability:card:main",
      "account_name": "Main Card",
      "billing_day": 15,
      "payment_due_day": 5
    }
  ],
  "due_date_projections": [
    {
      "account_id": "liability:card:main",
      "account_name": "Main Card",
      "due_date": "2026-04-05",
      "total_due": 35000,
      "payment_count": 12,
      "is_payment_due": false
    }
  ]
}
```

### 11.3 ルール

- 予測は `pending` 状態の取引を使用する
- 定期取引テンプレートから将来occurencesを生成する
- 請求サイクルは勘定ごとに設定可能
- 支払期日予測は `due_date` フィールドを優先し、無ければ `date` を使用する

## 12. データモデル拡張

### 12.1 Transaction の拡張

`due_date` フィールドは任意で、支払期日を示す。

- `due_date` が設定された場合、予測計算で `date` の代わりに使用される
- 主にクレジットカード等の未払いで使用

### 12.2 Account の拡張

`billing_day` と `payment_due_day` は請求サイクルを示す。

- `billing_day`: 請求日 (1-31)
- `payment_due_day`: 支払期日 (1-31)
- 主にクレジットカード勘定で使用
- 任意フィールド

## 13. インポート API

### 13.1 ImportService 相当

インポート API は外部ソースからの取引取り込みを提供する。

- ファイルインポート (CSV, OFX, QIF)
- レシート OCR 取り込み
- 重複検出
- インポートプレビューと確認

### 13.2 インポートフロー

```
1. ImportSource の作成（ファイルまたはテキスト）
2. ImportService.preview() でインポート内容のプレビュー
3. ユーザー確認
4. ImportService.import() で確定
5. TransactionRepository への保存
```

### 13.3 主要インターフェース

```dart
abstract class TransactionImporter {
  Future<ImportResult> import(ImportSource source);
  Future<ImportPreview> preview(ImportSource source);
  bool canHandle(ImportSource source);
  String get name;
  String get description;
}
```

### 13.4 ReceiptImporter

レシート画像からの取引取り込み:

```dart
ReceiptOcrService
  └─ ReceiptParser (抽象化)
      ├─ MockReceiptParser (テスト用)
      └─ Platform-specific implementations (future)
  └─ ReceiptNormalizer
      └─ ImportedTransaction
```

### 13.5 返却イメージ

```json
{
  "total": 5,
  "success": 4,
  "skipped": 1,
  "failed": 0,
  "duplicateCount": 1,
  "importedTransactions": [
    {
      "externalId": "bank_12345",
      "date": "2026-03-15",
      "description": "Store Name",
      "amount": 1500,
      "counterparty": "Store Name",
      "inferredType": "expense",
      "confidence": 0.95
    }
  ],
  "errors": [],
  "warnings": [
    {
      "index": 0,
      "message": "Low confidence in OCR results",
      "warningType": "lowConfidence"
    }
  ]
}
```

### 13.6 ルール

- インポート前にバリデーションを行う
- 重複は `external_ref` フィールドで検出
- 低い信頼度の结果是警告として返す
- 失敗した行はスキップされずに報告される

## 14. 金融商品の追跡パターン

### 14.1 基本方針

投資・ローン・分割払いは既存の勘定と取引タイプで対応する。
高機能な自動追跡は将来課題とする。

### 14.2 投資の追跡

資産勘定として追跡:

```json
{
  "account": {
    "account_id": "asset:investment:broker",
    "kind": "asset",
    "name": "証券:main"
  }
}
```

取引パターン:

```json
{
  "purchase": {
    "type": "expense",
    "description": "AAPL 株式購入",
    "entries": [
      {"account": "expense:investment", "direction": "increase"},
      {"account": "asset:bank", "direction": "decrease"}
    ]
  },
  "sale": {
    "type": "income",
    "description": "AAPL 売却",
    "entries": [
      {"account": "asset:bank", "direction": "increase"},
      {"account": "income:capital_gain", "direction": "increase"},
      {"account": "asset:investment", "direction": "decrease"}
    ]
  },
  "dividend": {
    "type": "income",
    "description": "AAPL 配当",
    "entries": [
      {"account": "asset:investment", "direction": "increase"},
      {"account": "income:dividend", "direction": "increase"}
    ]
  }
}
```

### 14.3 ローンの追跡

負債勘定として追跡:

```json
{
  "account": {
    "account_id": "liability:loan:car",
    "kind": "liability",
    "name": "自動車ローン",
    "payment_due_day": 25
  }
}
```

取引パターン:

```json
{
  "disbursement": {
    "type": "transfer",
    "description": "自動車ローン実行",
    "entries": [
      {"account": "asset:bank", "direction": "increase"},
      {"account": "liability:loan:car", "direction": "increase"}
    ]
  },
  "payment": {
    "type": "liability_payment",
    "description": "自動車ローン 月額返済",
    "entries": [
      {"account": "liability:loan:car", "direction": "decrease"},
      {"account": "asset:bank", "direction": "decrease"}
    ]
  },
  "withInterest": {
    "description": "自動車ローン 元利均等返済",
    "entries": [
      {"account": "expense:interest", "direction": "increase"},
      {"account": "liability:loan:car", "direction": "decrease"},
      {"account": "asset:bank", "direction": "decrease"}
    ]
  }
}
```

### 14.4 分割払いの追跡

credit_expense と liability_payment で追跡:

```json
{
  "purchase": {
    "type": "credit_expense",
    "description": "店舗名 (12回払い) 1/12",
    "entries": [
      {"account": "expense:food", "direction": "increase"},
      {"account": "liability:card:main", "direction": "increase"}
    ]
  },
  "payment": {
    "type": "liability_payment",
    "description": "店舗名 分割払い 2/12",
    "entries": [
      {"account": "liability:card:main", "direction": "decrease"},
      {"account": "asset:bank", "direction": "decrease"}
    ]
  }
}
```

### 14.5 ルール

- 投資・ローン・分割払いは既存の勘定タイプで対応
- 詳細な追跡（コストベース、残回数等）は手動または将来機能で対応
- billing_day / payment_due_day で支払リマインダー設定可能
- 説明文に情報を含めることで手動追跡を可能にする
