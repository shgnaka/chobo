---
title: "CHOBO UI 用語 decision"
date: "2026-03-20"
updated: "2026-03-21"
status: "decided"
source: "docs/chobo-future-topics.md"
parent-issue: "#7"
child-issues: ["#31", "#32"]
---

# UI 用語 decision

## 1. 概要

CHOBO はユーザー設定による Basic/Advanced モード切り替えを採用する。
Basic モードでは生活用語を、Advanced モードでは会計用語を使用する。

## 2. 生活用語マッピング (Basic モード)

### 取引種別

| Internal | Basic | Advanced |
|----------|-------|----------|
| income | お金が入った | 収入 |
| expense | お金を使った | 支出 |
| transfer | お金の移動 | 振替 |
| credit_expense | カードで支払い | カード支出 |
| liability_payment | カードの支払い | 負債返済 |

### 方向

| Internal | Basic | Advanced |
|----------|-------|----------|
| increase | 入 | 増加 |
| decrease | 出 | 減少 |

### 明細

| Index | Basic | Advanced |
|-------|-------|----------|
| 0 | 出金 | 明細 1 / 借方 |
| 1 | 入金 | 明細 2 / 貸方 |

## 3. 標準勘定科目名

標準勘定科目の表示名も Basic/Advanced モードに従う。

| English | Basic | Advanced |
|---------|-------|----------|
| Cash | 現金 | Cash |
| Main Bank | メインバンク | Main Bank |
| Salary | 給与 | Salary |
| Food | 食費 | Food |
| ... | ... | ... |

## 4. 会計用語露出ポリシー

### Advanced モードでのみ表示

| 用語 | 説明 |
|------|------|
| 借方 | 左側。資産や負債の増加を記録 |
| 貸方 | 右側。資産や負債の減少を記録 |
| 勘定 | 取引を記録する科目 |
| 仕訳 | 取引を借方・貸方に分解して記録 |

### Basic モードでのツールチップ

Basic モードでは、ラベルの上にホバー/タップで会計用語のツールチップを表示する。

| Basic 用語 | ツールチップ |
|------------|-------------|
| 出金 | 出金（しゅっきん）：借方。資産や負債の増加を記録します |
| 入金 | 入金（にゅうきん）：貸方。資産や負債の減少を記録します |
| 借方 | 借方（かりかた）：左側。資産の増加または負債の減少を記録します |
| 貸方 | 貸方（かしかた）：右側。資産の減少または負債の増加を記録します |

## 5. 設定

- **設定名:** Show Accounting Terminology / 会計用語を表示
- **デフォルト:** オフ (Basic モード)
- **適用範囲:** 入力フォーム、レポート、サマリー全て
- **保存場所:** アプリ設定データベース

## 6. 実装状況

- [x] `ChoboAppSettings` に `terminologyMode` 追加
- [x] `TerminologyService` プロバイダー実装
- [x] `TermLabel` ウィジェット実装
- [x] 取引編集画面のラベル更新
- [x] 取引詳細画面のラベル更新
- [x] ホーム画面のラベル更新
- [x] 設定画面にトグル UI 追加

## 7. 関連ファイル

- `lib/core/terminology_labels.dart` - 用語定義
- `lib/core/terminology_service.dart` - 用語サービス
- `lib/widgets/term_label.dart` - 用語ラベルウィジェット
- `lib/features/settings/settings_screen.dart` - 設定画面
