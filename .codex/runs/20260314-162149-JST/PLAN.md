# Plan

## Objective
- Plan / Review の入口ファイルを追加し、`AGENTS.md` から明示ルーティングされる構成へ更新する。
- `docs/agent/` を正本として維持しつつ、repo ローカル Skill を `.agents/skills/` に追加する。

## Scope
- In:
  - `AGENTS.md`
  - `PLANS.md`
  - `CODE_REVIEW.md`
  - `.agents/skills/*`
  - `docs/agent/overrides.md`
  - `docs/PROJECT_CONTEXT.md`
  - `docs/adr/`
  - `docs/history/`
  - `.codex/runs/20260314-162149-JST/*`
- Out:
  - `docs/agent/` の全面 `.agent/` 移行
  - safety harness 本体のロジック変更
  - 既存テンプレートの大幅改修

## Assumptions
- `.agent/` には Codex 固有の自動発見上の利点がないため、今回は採用しない。
- 必須導線は Skill の暗黙起動ではなく `AGENTS.md` と入口ファイルの明示参照で担保する。

## Hypotheses
- H1: `AGENTS.md` から `PLANS.md` / `CODE_REVIEW.md` を明示参照すれば、Plan / Review 時の導線が安定する。
- H2: `.agents/skills/` に planning / review Skill を置けば、repo 内の反復ワークフローを補強できる。

## Research Plan
- Round 1 Query:
  - 既存参照箇所と mode 入口候補の整理
- Round 2 Query:
  - nested Codex による `PLANS.md` / `CODE_REVIEW.md` の参照確認
- Exit Criteria:
  - `AGENTS.md` から Plan / Review 導線が明示されている
  - `PLANS.md` / `CODE_REVIEW.md` / `.agents/skills/*` が追加されている
  - `docs/PROJECT_CONTEXT.md`、ADR、history が更新されている
  - 静的検証と実行可能な範囲の runtime 検証が記録されている

## Approach
- run を初期化し、作業ログをこの run に集約する。
- 入口ファイルと repo ローカル Skill を追加する。
- `AGENTS.md` / `docs/agent/overrides.md` / `docs/PROJECT_CONTEXT.md` / ADR / history を整合させる。
- 静的検証と nested Codex による計画・レビュー入口の参照確認を行う。

## Definition of Done
- Plan / Review の入口ファイルが追加されている。
- `AGENTS.md` から mode 別入口が明示されている。
- repo ローカル planning / review Skill が追加されている。
- living docs と ADR が今回の構成を説明している。
- 検証結果が REPORT に残っている。

## Risks / Unknowns
- nested Codex の runtime 検証は CLI 挙動やポリシー制約により不安定な可能性がある。
- `scripts/verify` は bash / WSL 依存があるため、Windows 環境では一部失敗する可能性がある。

## Thinking Log
- 思考や判断の理由はここに逐次追記する（作業中に更新）。
- 不明点の整理、選択肢比較、決定理由を簡潔に記録する。
- 2026-03-14 16:22 (JST): `.agent/` への全面移行は行わず、`docs/agent/` を正本として維持する方針で着手。
- 2026-03-14 16:24 (JST): Plan / Review の強制導線は `AGENTS.md` から `PLANS.md` / `CODE_REVIEW.md` を参照させる形に決定。
- 2026-03-14 17:08 (JST): review 系入口の命名を `CODE_REVIEW.md` に統一し、全参照更新と再検証を行う。
- 2026-03-14 16:27 (JST): repo ローカルの反復ワークフローは `.agents/skills/feature-plan` と `.agents/skills/code-review` の2件に絞って追加。
- 2026-03-14 16:31 (JST): 静的検証に加え、nested Codex で planning request / review request を read-only 実行し、入口ファイルの適用を確認。
- 2026-03-14 16:36 (JST): 計画から実装への handoff では、実装前に `docs/plans/` へ保存するルールを `AGENTS.md` と planning 入口へ追加する方針に決定。
