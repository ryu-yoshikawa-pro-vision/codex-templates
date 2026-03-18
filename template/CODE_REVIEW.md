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
