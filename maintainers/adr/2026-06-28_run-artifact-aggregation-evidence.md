# ADR: Run artifact aggregation and structured evaluation evidence

## Status

Accepted

## Date

2026-06-28

## Context

Harness runs already emit several artifact types with separate responsibilities:

- `run.json`
- codex-task report JSON
- hook observation JSONL
- subagent run JSON
- `REPORT.md`
- `evaluation.json`

PR #22 extends `run.json` as an aggregate manifest and adds structured evaluation evidence references. The implementation plan spans specs, templates, scripts, tests, and docs, so the design decision needs a durable record for future maintainers.

Run-level review previously required manually tracing scattered artifacts. That made it difficult to answer basic questions such as which reports were produced, whether hook safety events occurred, which subagents participated, and which evidence supported an evaluation finding.

At the same time, making `run.json` replace lower-level artifacts would lose detail and blur source-of-truth ownership. The same risk exists if `evaluation.json` starts copying execution facts instead of referencing them.

## Decision

Keep `run.json` as an aggregate manifest and do not replace codex-task reports, hook JSONL, subagent run JSON, `REPORT.md`, or `evaluation.json`.

Keep `evaluation.json.evidence` as the required human-readable field.

Add optional `evidence_refs` for structured references to run artifacts. Centralize the evidence reference schema in `evaluation.schema.json::$defs.evidence_ref` and reference it from all `evidence_refs` locations.

Structured evidence references may point to:

- `run_manifest`
- `codex_task_report`
- `log_event`
- `hook_observation`
- `subagent_run`
- `changed_file`
- `validation_command`
- `evaluation_note`

Keep `schema_version: 1` compatibility by leaving `artifact_summary`, `hook_observations`, and `subagents` optional in the schema while requiring generators and collectors to emit default sections.

Require `codex-task.ps1` to execute `collect-run-artifacts.ps1` whenever `--record-run-manifest` is enabled, using Python discovery order `python`, `python3`, `py`.

Keep Bash and PowerShell validator / integration-test parity for aggregate defaults, relative `--base-manifest`, subagent enum strictness, and mismatch evidence checks.

## Consequences

Existing evaluation artifacts remain valid because `evidence_refs` stays optional.

Existing `schema_version: 1` run manifests remain valid because aggregate sections are not made top-level required in this PR.

New run manifests always contain aggregate default sections, even before collector re-aggregation.

PowerShell-only or `python3`-only environments can still aggregate run artifacts.

Future automation can consume `evidence_refs` without changing the ownership of low-level artifact files.

A future schema version may choose to make the aggregate sections required, but that should be done with an explicit migration plan.

## References

- `maintainers/plans/2026-06-28_144800_run_artifact_aggregation_evidence.md`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/evaluation.md`
- `template/docs/reference/hook-observation.md`
- `template/docs/reference/subagent-observation.md`
- `spec/run-manifest.schema.json`
- `spec/evaluation.schema.json`
