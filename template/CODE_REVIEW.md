# Code Review Entry Point

## 適用条件
- ユーザーがレビューを依頼した場合
- `/review` を使う場合
- 実装完了前の自己レビュー

## 使い方
1. `AGENTS.md` を確認する。
2. `.agents/skills/code-review/SKILL.md` を読む。
3. 必要に応じて `.agents/skills/code-review/references/review-workflow.md` を読む。

## Review objective
1. correctness
2. security
3. behavioral regression
4. missing tests
5. maintainability
6. performance
7. developer experience

## What to report
- 差分に起因する問題だけを報告する。
- 根拠が弱い論点は finding にせず `Open questions` に回す。
- 単なる好みや既存問題を差分起因として扱わない。
- レビュー結果は原則チャット返答のみとし、明示的な調査・保存依頼がない限り `docs/reports/` に report file を作らない。

## Required review format
- findings-first
- severity 順
- Severity
- Title
- Location
- Why it matters
- Evidence
- Suggested fix
- Open questions
- Verdict
- confidence

## Report file 生成ルール
- Allowed: ユーザーが「レポートとして保存」「調査レポートを作成」など保存を明示した場合、計画 DoD に report file が明記されている場合、複数ソース調査・監査・検証結果を後で参照する durable artifact として残す必要がある場合。
- Not allowed: review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価。
- 保存先: consumer repo 作業は `docs/reports/`。`.codex/runs/<run_id>/REPORT.md` は run-local log として別扱い。
- 判断に迷う場合は report file を作らず、チャット返答と run-local `REPORT.md` に留める。
