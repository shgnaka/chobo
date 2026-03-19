---
title: "CHOBO 着手順メモ"
date: "2026-03-20"
updated: "2026-03-20"
status: "draft"
source: "docs/chobo-spec.md"
---

# CHOBO 着手順メモ

## 1. 目的

この文書は、現在の仕様群と GitHub issue を、どの順で着手するかを残すためのメモである。

## 2. 親 Issue の実装順

親 issue 単位では、次の順で進める。

1. [`#1 Spec: finalize core product spec`](https://github.com/shgnaka/chobo/issues/1)
2. [`#2 Spec: define database schema`](https://github.com/shgnaka/chobo/issues/2)
3. [`#4 Spec: define auth and encryption policy`](https://github.com/shgnaka/chobo/issues/4)
4. [`#5 Spec: define backup and restore flow`](https://github.com/shgnaka/chobo/issues/5)
5. [`#3 Spec: define application API boundaries`](https://github.com/shgnaka/chobo/issues/3)
6. [`#7 Future: define UI vocabulary`](https://github.com/shgnaka/chobo/issues/7)
7. [`#8 Future: expand transaction types`](https://github.com/shgnaka/chobo/issues/8)
8. [`#10 Future: expand monthly summary`](https://github.com/shgnaka/chobo/issues/10)
9. [`#9 Future: expand analysis axes`](https://github.com/shgnaka/chobo/issues/9)
10. [`#11 Future: add budget and forecast`](https://github.com/shgnaka/chobo/issues/11)
11. [`#12 Future: add search and input assist`](https://github.com/shgnaka/chobo/issues/12)
12. [`#13 Future: expand asset management`](https://github.com/shgnaka/chobo/issues/13)
13. [`#6 Future: prioritize next decisions`](https://github.com/shgnaka/chobo/issues/6)

## 3. 親 Issue ごとの子 Issue

### 3.1 `#1 Spec: finalize core product spec`

- [`#14 Spec/1.1: transaction protocol and balance semantics`](https://github.com/shgnaka/chobo/issues/14)
- [`#15 Spec/1.2: standard account set and editing rules`](https://github.com/shgnaka/chobo/issues/15)
- [`#16 Spec/1.3: input flow, reconciliation, and adjustment rules`](https://github.com/shgnaka/chobo/issues/16)

#### 3.1.1 `#1` の子 issue 着手順

1. [`#14 Spec/1.1: transaction protocol and balance semantics`](https://github.com/shgnaka/chobo/issues/14)
2. [`#15 Spec/1.2: standard account set and editing rules`](https://github.com/shgnaka/chobo/issues/15)
3. [`#16 Spec/1.3: input flow, reconciliation, and adjustment rules`](https://github.com/shgnaka/chobo/issues/16)

理由:

- `#14` は全体の取引表現の土台になる
- `#15` はその上で使う標準勘定を固める
- `#16` はプロトコルと勘定が固まってから詰めるほうが手戻りが少ない

### 3.2 `#2 Spec: define database schema`

- [`#17 DB/2.1: account, transaction, and entry tables`](https://github.com/shgnaka/chobo/issues/17)
- [`#18 DB/2.2: closure, settings, and audit tables`](https://github.com/shgnaka/chobo/issues/18)
- [`#19 DB/2.3: save rules, recalculation, and migration strategy`](https://github.com/shgnaka/chobo/issues/19)

#### 3.2.1 `#2` の子 issue 着手順

1. [`#17 DB/2.1: account, transaction, and entry tables`](https://github.com/shgnaka/chobo/issues/17)
2. [`#18 DB/2.2: closure, settings, and audit tables`](https://github.com/shgnaka/chobo/issues/18)
3. [`#19 DB/2.3: save rules, recalculation, and migration strategy`](https://github.com/shgnaka/chobo/issues/19)

理由:

- `#17` は永続化のコア構造を決める
- `#18` は締め・設定・監査の周辺テーブルを固める
- `#19` は前 2 つの構造が固まってから保存ルールと移行を詰める

### 3.3 `#3 Spec: define application API boundaries`

- [`#20 API/3.1: monthly summary API shape`](https://github.com/shgnaka/chobo/issues/20)
- [`#21 API/3.2: account and transaction management API`](https://github.com/shgnaka/chobo/issues/21)
- [`#22 API/3.3: reconciliation, closing, backup, and audit APIs`](https://github.com/shgnaka/chobo/issues/22)

#### 3.3.1 `#3` の子 issue 着手順

1. [`#20 API/3.1: monthly summary API shape`](https://github.com/shgnaka/chobo/issues/20)
2. [`#21 API/3.2: account and transaction management API`](https://github.com/shgnaka/chobo/issues/21)
3. [`#22 API/3.3: reconciliation, closing, backup, and audit APIs`](https://github.com/shgnaka/chobo/issues/22)

理由:

- `#20` はアプリ全体の表示・集計の中心になる
- `#21` はその上で CRUD の境界を固める
- `#22` は運用系の API なので、主要な戻り値や保存ルールが定まってから詰めるほうがよい

### 3.4 `#4 Spec: define auth and encryption policy`

- [`#23 Auth/4.1: storage-at-rest encryption and key management`](https://github.com/shgnaka/chobo/issues/23)
- [`#24 Auth/4.2: app authentication for important operations`](https://github.com/shgnaka/chobo/issues/24)
- [`#25 Auth/4.3: logs, notifications, and screen exposure limits`](https://github.com/shgnaka/chobo/issues/25)

#### 3.4.1 `#4` の子 issue 着手順

1. [`#23 Auth/4.1: storage-at-rest encryption and key management`](https://github.com/shgnaka/chobo/issues/23)
2. [`#24 Auth/4.2: app authentication for important operations`](https://github.com/shgnaka/chobo/issues/24)
3. [`#25 Auth/4.3: logs, notifications, and screen exposure limits`](https://github.com/shgnaka/chobo/issues/25)

理由:

- `#23` は保存データの保護と鍵まわりの基盤になる
- `#24` は重要操作の再認証を、鍵と保存方針が固まったあとで詰めるほうが安全
- `#25` は表示・通知・ログの露出制御なので、前 2 つの脅威モデルが固まってから決める

### 3.5 `#5 Spec: define backup and restore flow`

- [`#26 Backup/5.1: backup contents and file structure`](https://github.com/shgnaka/chobo/issues/26)
- [`#27 Backup/5.2: wrapped-key encryption and creation flow`](https://github.com/shgnaka/chobo/issues/27)
- [`#28 Backup/5.3: restore flow and failure handling`](https://github.com/shgnaka/chobo/issues/28)

#### 3.5.1 `#5` の子 issue 着手順

1. [`#26 Backup/5.1: backup contents and file structure`](https://github.com/shgnaka/chobo/issues/26)
2. [`#27 Backup/5.2: wrapped-key encryption and creation flow`](https://github.com/shgnaka/chobo/issues/27)
3. [`#28 Backup/5.3: restore flow and failure handling`](https://github.com/shgnaka/chobo/issues/28)

理由:

- `#26` はまず何を保存するかを決める基礎
- `#27` はバックアップの内容が決まってから暗号化と作成手順を詰めるほうがよい
- `#28` は復元失敗時の扱いも含むため、前 2 つが固まってから最後に整理する

### 3.6 `#6 Future: prioritize next decisions`

- [`#29 Priority/6.1: app lock and cache policy`](https://github.com/shgnaka/chobo/issues/29)
- [`#30 Priority/6.2: audit granularity and next expansion target`](https://github.com/shgnaka/chobo/issues/30)

#### 3.6.1 `#6` の子 issue 着手順

1. [`#29 Priority/6.1: app lock and cache policy`](https://github.com/shgnaka/chobo/issues/29)
2. [`#30 Priority/6.2: audit granularity and next expansion target`](https://github.com/shgnaka/chobo/issues/30)

理由:

- `#29` はアプリ保護とキャッシュ挙動の前提を先に固める
- `#30` は監査粒度と次の拡張対象を、その前提の上で決めるほうがぶれにくい

### 3.7 `#7 Future: define UI vocabulary`

- [`#31 UI/7.1: living-language input labels`](https://github.com/shgnaka/chobo/issues/31)
- [`#32 UI/7.2: accounting terminology exposure and glossary`](https://github.com/shgnaka/chobo/issues/32)

#### 3.7.1 `#7` の子 issue 着手順

1. [`#31 UI/7.1: living-language input labels`](https://github.com/shgnaka/chobo/issues/31)
2. [`#32 UI/7.2: accounting terminology exposure and glossary`](https://github.com/shgnaka/chobo/issues/32)

理由:

- `#31` は日常語で入力しやすくするための基礎
- `#32` は会計用語の見せ方なので、入力語彙が固まってから整えるほうがぶれにくい

### 3.8 `#8 Future: expand transaction types`

- [`#33 Txn/8.1: recurring transactions`](https://github.com/shgnaka/chobo/issues/33)
- [`#34 Txn/8.2: transfer, charge, and advance-payment variants`](https://github.com/shgnaka/chobo/issues/34)
- [`#35 Txn/8.3: refund, cancellation, and void behavior`](https://github.com/shgnaka/chobo/issues/35)
- [`#36 Txn/8.4: points and reward handling`](https://github.com/shgnaka/chobo/issues/36)

#### 3.8.1 `#8` の子 issue 着手順

1. [`#33 Txn/8.1: recurring transactions`](https://github.com/shgnaka/chobo/issues/33)
2. [`#34 Txn/8.2: transfer, charge, and advance-payment variants`](https://github.com/shgnaka/chobo/issues/34)
3. [`#35 Txn/8.3: refund, cancellation, and void behavior`](https://github.com/shgnaka/chobo/issues/35)
4. [`#36 Txn/8.4: points and reward handling`](https://github.com/shgnaka/chobo/issues/36)

理由:

- `#33` は取引型拡張の中でも最もベースになりやすい
- `#34` は派生取引の表現を固める段階として次に置く
- `#35` は例外処理なので、基本の取引型が固まってから詰める
- `#36` はポイントや報酬の扱いで、最も後ろで独立して整理しやすい

### 3.9 `#9 Future: expand analysis axes`

- [`#37 Analysis/9.1: tags and purpose labels`](https://github.com/shgnaka/chobo/issues/37)
- [`#38 Analysis/9.2: counterparty and merchant metadata`](https://github.com/shgnaka/chobo/issues/38)

#### 3.9.1 `#9` の子 issue 着手順

1. [`#37 Analysis/9.1: tags and purpose labels`](https://github.com/shgnaka/chobo/issues/37)
2. [`#38 Analysis/9.2: counterparty and merchant metadata`](https://github.com/shgnaka/chobo/issues/38)

理由:

- `#37` は分析の入口になるラベル系の軸を先に固める
- `#38` は相手先や店舗メタデータなので、分析軸の土台ができてから詰めるほうがよい

### 3.10 `#10 Future: expand monthly summary`

- [`#39 Summary/10.1: cash-out and liability metrics`](https://github.com/shgnaka/chobo/issues/39)
- [`#40 Summary/10.2: asset movement visualization`](https://github.com/shgnaka/chobo/issues/40)

#### 3.10.1 `#10` の子 issue 着手順

1. [`#39 Summary/10.1: cash-out and liability metrics`](https://github.com/shgnaka/chobo/issues/39)
2. [`#40 Summary/10.2: asset movement visualization`](https://github.com/shgnaka/chobo/issues/40)

理由:

- `#39` は月次集計の見せ方として現金と負債の指標を先に固める
- `#40` は資産移動の可視化なので、まず集計指標が定まってから乗せるほうが自然

### 3.11 `#11 Future: add budget and forecast`

- [`#41 Budget/11.1: monthly budget model`](https://github.com/shgnaka/chobo/issues/41)
- [`#42 Budget/11.2: end-of-month forecast`](https://github.com/shgnaka/chobo/issues/42)
- [`#43 Budget/11.3: budget alert policy`](https://github.com/shgnaka/chobo/issues/43)

#### 3.11.1 `#11` の子 issue 着手順

1. [`#41 Budget/11.1: monthly budget model`](https://github.com/shgnaka/chobo/issues/41)
2. [`#42 Budget/11.2: end-of-month forecast`](https://github.com/shgnaka/chobo/issues/42)
3. [`#43 Budget/11.3: budget alert policy`](https://github.com/shgnaka/chobo/issues/43)

理由:

- `#41` は予算機能の土台となるモデルを決める
- `#42` はそのモデルを使った予測なので次に置く
- `#43` は予測やしきい値を踏まえて決めるのがよい

### 3.12 `#12 Future: add search and input assist`

- [`#44 Assist/12.1: search filters and conditions`](https://github.com/shgnaka/chobo/issues/44)
- [`#45 Assist/12.2: reusable templates`](https://github.com/shgnaka/chobo/issues/45)
- [`#46 Assist/12.3: candidate suggestions and autocomplete`](https://github.com/shgnaka/chobo/issues/46)

#### 3.12.1 `#12` の子 issue 着手順

1. [`#44 Assist/12.1: search filters and conditions`](https://github.com/shgnaka/chobo/issues/44)
2. [`#45 Assist/12.2: reusable templates`](https://github.com/shgnaka/chobo/issues/45)
3. [`#46 Assist/12.3: candidate suggestions and autocomplete`](https://github.com/shgnaka/chobo/issues/46)

理由:

- `#44` は検索の入口となる条件設計を先に固める
- `#45` は検索や入力の型が見えてからテンプレート化するほうが自然
- `#46` は候補提示なので、検索条件とテンプレートが定まってから最後に調整する

### 3.13 `#13 Future: expand asset management`

- [`#47 Assets/13.1: due dates and month-end outlook`](https://github.com/shgnaka/chobo/issues/47)
- [`#48 Assets/13.2: integrations split`](https://github.com/shgnaka/chobo/issues/48)
- [`#49 Assets/13.3: investments, loans, and installments`](https://github.com/shgnaka/chobo/issues/49)

#### 3.13.1 `#13` の子 issue 着手順

1. [`#47 Assets/13.1: due dates and month-end outlook`](https://github.com/shgnaka/chobo/issues/47)
2. [`#48 Assets/13.2: integrations split`](https://github.com/shgnaka/chobo/issues/48)
3. [`#49 Assets/13.3: investments, loans, and installments`](https://github.com/shgnaka/chobo/issues/49)

理由:

- `#47` は資産管理の基本となる期限管理と月末見込みを先に固める
- `#48` は外部連携の切り出しで、基礎の見通しができてから整理するほうがよい
- `#49` は投資・ローン・分割払いといった拡張領域なので最後に置く

## 4. 理由

- `#1` は全体の前提を固める
- `#2` は実装の土台になる
- `#4` と `#5` はデータ保護と復旧の土台になる
- `#3` はその上に乗る API 境界を固める
- その後に UI と将来拡張を詰める
- `#6` はロードマップ確認なので最後に回してよい

## 5. 運用メモ

- 実装順が変わったらこの文書を更新する
- 個別 issue のコメントには、ここへのリンクだけを残せばよい
- 本文の仕様と着手順を混ぜない
