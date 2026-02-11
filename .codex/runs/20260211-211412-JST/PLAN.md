# Plan

## Objective
- Update `AGENTS.md` so it explicitly requires formatter checks (when configured by the project) before completion and reporting.
- Convert all existing Japanese text in `AGENTS.md` into English while preserving intent.

## Scope
- In:
  - `AGENTS.md`
  - Run logs under `.codex/runs/20260211-211412-JST/`
  - `docs/PROJECT_CONTEXT.md` (living documentation update)
- Out:
  - Any unrelated repository files

## Assumptions
- "formatter" means running the project's configured formatting check command (or formatter) and ensuring no errors before reporting completion.
- No new ADR is required because this is a wording/policy clarification, not a new architecture decision.

## Approach
- Inspect current `AGENTS.md` quality-gate and language sections.
- Rewrite Japanese lines into English and add explicit formatter + no-error-before-reporting wording.
- Update run TASKS/REPORT progressively.
- Run available checks relevant to this docs change.

## Definition of Done
- `AGENTS.md` explicitly mentions formatter in quality gates and requires no errors before work report.
- `AGENTS.md` contains only English text.
- Run logs are updated with progress entries.
- Changes committed and PR message created.

## Risks / Unknowns
- Need to keep the original operational meaning while translating language policy examples.

## Thinking Log
- 2026-02-11 21:14 JST: Scope is limited to policy documentation; no code behavior changes expected.
- 2026-02-11 21:14 JST: Will update PROJECT_CONTEXT with the newly clarified quality-gate expectation as part of living documentation.

- 2026-02-11 21:22 JST: 追加要望に基づき、AGENTS.mdへ「思考は英語・出力は日本語」、およびrun系ドキュメント日本語・AGENTS英語のみの方針を明文化する。
