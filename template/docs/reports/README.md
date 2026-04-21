# docs/reports Usage

## Purpose
- Store durable investigation, audit, verification, and analysis reports in a consistent format.
- Do not create files here for review-only answers, plan-only work, status updates, lightweight checks, routine evidence command output, or run progress logs.
- Use `.codex/runs/<run_id>/REPORT.md` and `.codex/runs/<run_id>/logs/` for run-local progress and command evidence.

## Naming Rule
- Create report files as: `{yyyy-mm-dd}_{HHMMSS}_{report_name}.md`
- Use JST (`Asia/Tokyo`) for the date/time portion.
- Use short kebab-case English for `report_name` when possible (for example: `release-audit`, `migration-log`).

## Example
- `docs/reports/2026-03-03_201530_release-audit.md`
