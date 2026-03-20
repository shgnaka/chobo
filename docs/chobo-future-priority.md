---
title: "CHOBO 将来論点 - 優先論点"
date: "2026-03-20"
updated: "2026-03-20"
status: "final"
source: "docs/chobo-future-topics.md"
---

# 優先論点

## 1. 目的

MVP 後に、まず何を決めるべきかを整理する。

## 2. 論点（決定済み）

### 2.1 起動時ロック

**決定: 標準機能として実装する**

- ロックモード: 起動時に毎回ロック画面を表示
- 認証方式: バイオメトリック認証のみ（MVP）
- 設定キー: `app_lock_enabled`, `lock_mode`
- 関連ファイル:
  - `lib/features/lock/app_lock_screen.dart`
  - `lib/features/lock/app_lock_state.dart`

### 2.2 集計キャッシュ

**決定: 5分間のタイムベースキャッシュを採用**

- デフォルトキャッシュ時間: 300秒（5分）
- キャッシュ無効化のトリガー:
  - 取引の作成・更新・取消
  - 勘定の変更
  - 照合完了
- 設定キー: `cache_duration_seconds`
- 関連ファイル:
  - `lib/core/aggregation_cache_policy.dart`
  - `lib/data/service/monthly_summary_service.dart`

### 2.3 監査イベントの粒度

**決定: Summary レベルで実装する**

- 記録内容: イベントタイプ、タイムスタンプ、ターゲットID、変更フィールド名のサマリー
- void 取引: 元取引の日付、タイプ、合計金額のみを記録
- 完全な変更前後の値は記録しない
- 設定キー: `audit_granularity`
- 関連ファイル:
  - `lib/core/audit_policy.dart`
  - `lib/core/audit_event_factory.dart`

### 2.4 将来拡張の最初の対象

**決定: 保留（今後の議論待ち）**

- 候補は継続:
  - 銀行連携
  - カード連携
  - レシート OCR
  - 位置起点通知

## 3. issue 分割の目安（実装済み）

- `App lock policy` - ✅ 実装完了
- `Aggregation cache policy` - ✅ 実装完了
- `Audit event granularity` - ✅ 実装完了
- `Next expansion target` - 保留

