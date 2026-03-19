---
title: "CHOBO 将来論点 - 月次集計の拡張"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-future-topics.md"
---

# 月次集計の拡張

## 1. 目的

月次レポートを、単なる費目集計よりも家計判断に使いやすい形へ拡張する。

## 2. 論点

### 2.1 支出と現金流出の区別

- `cash_out_expenses` の算出式を固定する
- `expense` 累計との違いを示す
- カード利用分を誤って二重計上しない

### 2.2 未払と純資産

- `liability_due` の定義を明示する
- `net_assets` の算出元を決める
- 月末時点の見え方を統一する

### 2.3 資産増減の見える化

- 貯蓄移動を支出に混ぜない
- 資産間移動の集計方法を決める
- 月次レビューの見せ方を定義する

## 3. issue 分割の目安

- `Cash flow metrics`
- `Liability and net assets metrics`
- `Asset movement visualization`

