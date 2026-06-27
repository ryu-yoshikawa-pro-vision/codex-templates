---
name: harness-improvement
description: Use when converting run results, evaluation findings, repair-loop outcomes, or repeated failures into harness improvement candidates.
---

1. `AGENTS.md`、`docs/reference/harness-improvement-loop.md`、`docs/reference/evaluation.md`、`docs/reference/failure-taxonomy.md` を読む。
2. `references/improvement-workflow.md` を読み、candidate作成基準と禁止事項を確認する。
3. `evaluation.json`、run manifest、validation results、hook observations、subagent-run records、review comments を evidence として集める。
4. improvement candidate を `target`、`failure_category`、`evidence`、`expected_impact`、`risk`、`recommended_change`、`strictness` つきで作る。
5. 通常実装の修正と harness improvement を混ぜない。
6. safety layer / hooks / execpolicy / codex-safe / codex-task / spec を変更する提案は strict workflow 扱いにする。
7. candidate は自動適用せず、reviewable plan / docs / issue / follow-up PR として扱う。
