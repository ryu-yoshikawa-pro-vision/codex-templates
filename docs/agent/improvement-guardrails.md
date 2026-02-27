# 自己改善提案ガードレール

## 目的
- Codex の自己改善提案を安全に運用し、意図しない変更や過剰自動化を防ぐ。

## 1. 提案トリガー
- T1: 同種の手戻りが2回以上発生したとき
- T2: テンプレート不足で REPORT に未解決論点が残ったとき
- T3: 品質ゲート（lint/typecheck/test/build）で再発エラーが発生したとき
- T4: Web調査で高信頼の改善手法が確認されたとき

## 2. リスク区分と承認
- L1（低リスク）: ドキュメント追記・テンプレート文言改善
  - 承認: 実行者セルフ承認可（REPORT記録必須）
- L2（中リスク）: 運用ルール改訂（AGENTS/PROJECT_CONTEXT/テンプレート構造変更）
  - 承認: ユーザー承認必須
- L3（高リスク）: 実行権限・sandbox・approval挙動に影響する変更
  - 承認: ユーザー明示承認 + ロールバック手順先行定義

## 3. 差し戻し条件
- 期待効果が DoD/KPI に紐付かない
- 変更影響範囲が不明
- 検証手順が不足
- 既存安全制約に抵触

## 4. ロールバック方針
- 変更前状態を `git diff` と REPORT に記録してから適用する。
- 問題発生時は該当ファイルを元に戻す修正コミット（または逆パッチ）を優先する。
- ロールバック後に原因と再発防止を REPORT へ記録する。

## 5. 提案ログ必須項目
- Proposal ID
- Trigger (T1-T4)
- Risk Level (L1-L3)
- Proposed Change
- Expected Impact
- Approval (Approver / Timestamp / Decision)
- Validation Plan
- Rollback Plan
- Result
