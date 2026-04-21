# Repository Layout

```text
.
├─ AGENTS.md
├─ PLANS.md
├─ CODE_REVIEW.md
├─ .codex/
├─ .agents/
├─ docs/
└─ scripts/
```

## 補足
- `.codex/runs/` と `.codex/logs/` は実行時に増える。
- `.agents/skills/*/references/` は task-specific workflow の詳細手順。
- `docs/reference/` は人間向けの補助文書。
- `docs/plans/` は計画書の保存先。
- `docs/reports/` は durable な調査・監査・検証レポートの保存先。review-only や run progress では作らない。
- `scripts/` には `codex-safe`、`codex-task`、`codex-sandbox`、`verify` が含まれる。
