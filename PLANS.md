# Planning Entry Point

## 適用条件
- 複雑な依頼
- 複数ファイルや複数段階にまたがる依頼
- 要件が曖昧な依頼
- 副作用境界、公開インターフェース、移行、検証方針の整理が必要な依頼
- ユーザーが明示的に計画作成を求めた依頼
- Plan Mode で扱う依頼

## 必須動作
1. 目的、スコープ、完了条件を最初に固定する。
2. 未確定事項は仮説と未解決論点として切り出す。
3. 純粋ロジックと副作用境界を分けて考える。
4. 実装前に、変更対象、検証方法、ロールバック観点を明示する。
5. 複雑タスクでは実装者が追加判断なしで進められる粒度まで具体化する。
6. 実装へ進む前に、合意した計画内容を `docs/plans/` へ保存する。

## 参照先
- ベーステンプレート: `docs/agent/templates/planner-template.md`
- 役割定義: `docs/agent/agent-role-design.md` の Planner 節
- ユーザー向け計画書が必要な場合: `docs/plans/TEMPLATE.md` と `AGENTS.md` §9

## 最低限含める内容
- Objective / Scope / Definition of Done
- Hypotheses / Open Issues / Exit Criteria
- 変更対象のファイルまたは責務
- 副作用境界とリスク
- 検証手順

## 出力方針
- 実装前提の計画では、あいまいな一般論ではなく実行順と判定条件を書く。
- 役割ベースで考える場合は Planner の責務に沿って整理する。
- 計画だけでなく、必要なら `.codex/runs/<run_id>/PLAN.md` と `TASKS.md` に落とし込む。
- Plan Mode やチャットで固めた計画から実装へ移る場合は、最初に `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md` へ保存する。
