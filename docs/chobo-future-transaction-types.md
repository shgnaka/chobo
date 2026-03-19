---
title: "CHOBO 将来論点 - 取引型の拡張"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-future-topics.md"
---

# 取引型の拡張

## 1. 目的

MVP の 5 取引型で足りないケースを、後から安全に追加するための整理である。

## 2. 論点

### 2.1 定期取引

- 繰り返し周期を持たせる
- 次回予定を生成する
- 既存取引との重複防止を考える

### 2.2 振替・チャージ・立替

- 振替とチャージを分ける
- 立替と返済を分ける
- 資産移動と費用認識を混同しない

### 2.3 返金・取消・キャンセル

- 返金の会計表現を定義する
- キャンセル時の履歴の残し方を定義する
- `void` と併用するかを決める

### 2.4 ポイント・還元

- ポイントの会計上の扱いを決める
- 還元時の入金先を定義する
- 実現時点と付与時点の差を扱う

## 3. issue 分割の目安

- `Recurring transactions`
- `Transfer and charge variants`
- `Refund and cancellation`
- `Points and rewards`

