# ADR: Run artifact aggregation and structured evaluation evidence

## Status
- Accepted

## Context
- Harness runs already emit `run.json`, codex-task reports, hook observation JSONL, subagent run JSON, `REPORT.md`, and `evaluation.json`.
- PR #22 extends `run.json` as an aggregate manifest and adds structured evidence references, but follow-up review found contract gaps in PowerShell collector parity, schema reuse, and validation coverage.

## Decision
- Keep `run.json` as an aggregate manifest and do not replace codex-task reports, hook JSONL, subagent run JSON, or `evaluation.json`.
- Keep `evaluation.json.evidence` as the required human-readable field.
- Centralize structured references in `evaluation.schema.json::$defs.evidence_ref` and reference it from all `evidence_refs` locations.
- Keep `schema_version: 1` compatibility by leaving `artifact_summary`, `hook_observations`, and `subagents` optional in schema while requiring generators and collectors to emit default sections.
- Require `codex-task.ps1` to execute `collect-run-artifacts.ps1` whenever `--record-run-manifest` is enabled, using Python discovery order `python`, `python3`, `py`.
- Keep Bash and PowerShell validator / integration-test parity for aggregate defaults, relative `--base-manifest`, subagent enum strictness, and mismatch evidence checks.

## Consequences
- Existing evaluation artifacts remain valid because `evidence_refs` stays optional.
- New run manifests always contain aggregate default sections, even before collector re-aggregation.
- PowerShell-only or `python3`-only environments can still aggregate run artifacts.
- Future automation can consume `evidence_refs` without changing the ownership of low-level artifact files.
