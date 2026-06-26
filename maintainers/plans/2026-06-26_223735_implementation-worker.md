# Add scoped implementation_worker subagent

- Created: 2026-06-26 22:37:35 JST
- Scope: source repository maintenance change for consumer-facing template
- Change level: L3 because this adds a workspace-write subagent contract

## Goal

Add an `implementation_worker` project-scoped custom agent that can handle small, parent-approved implementation tasks while keeping existing read-only investigation agents unchanged.

## Current understanding

The template currently defines read-only subagents for code research, implementation planning, and test investigation. Actual edits are performed by the parent agent. The desired change is to allow a subagent to perform implementation, but only after the parent agent has fixed the plan, target files, change scope, and prohibited operations.

## Non-goals

- Do not introduce unrestricted parallel write-heavy subagent workflows.
- Do not allow subagents to delete, rename, move files, or perform git mutations.
- Do not change wrapper default presets.
- Do not enable dangerous bypass modes.
- Do not change model defaults for existing read-only agents.

## Consumer-facing changes

- Add `template/.codex/agents/implementation_worker.toml`.
- Update `template/AGENTS.md` to describe when the writable worker may be used.
- Update `template/docs/reference/codex-safety-harness.md` and `template/docs/reference/codex-implementation-harness.md` with worker boundaries.
- Update `template/docs/PROJECT_CONTEXT.md` with subagent role separation.
- Update `template/scripts/verify` so the consumer template contract includes the new worker file and key safety strings where possible.

## Source-repo changes

- Register the worker in `spec/workflow.yaml` required files.
- Register the worker safety contract in `spec/safety-policy.yaml`.
- Register AGENTS routing expectations in `spec/routing.yaml`.
- Update `maintainers/PROJECT_CONTEXT.md` and history.
- Update both bash and PowerShell spec validators so `safety.subagents` contracts are checked consistently.

## Safety boundary

`implementation_worker` may edit only files explicitly named by the parent agent. It must use minimal diffs and return control to the parent agent when scope, design decisions, target files, or validation are unclear.

Forbidden operations:

- File deletion
- Rename or move
- Git mutation
- Scope expansion
- Unrequested refactoring
- Delete / rename patch operations
- Dependency updates unless explicitly assigned

Writable subagents should be used one at a time by default. Parallel writable subagents are only acceptable when target files are fully disjoint and the parent agent explicitly manages the conflict risk.

## Validation plan

Run these after implementation:

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
```

On Windows or PowerShell-capable environments:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1
```

Expected outcome:

- `workflow.required_files` contains `template/.codex/agents/implementation_worker.toml`.
- `safety.subagents` validates all read-only agents and the new workspace-write worker.
- `template/AGENTS.md` contains the worker routing and usage constraints.
- Worker output requires scope-compliance confirmation.

## Migration impact

This is an additive template change. Existing consumer repositories are not broken unless they rely on a strict copy of `.codex/agents/` without syncing new files. Existing read-only subagent names remain unchanged.

Consumer repositories that want the feature should sync the updated template and use prompts that explicitly instruct the parent agent to invoke `implementation_worker` only after scope approval.

## Rollback plan

If the worker proves unsafe or unsupported in the target Codex CLI environment:

1. Remove `template/.codex/agents/implementation_worker.toml`.
2. Remove `implementation_worker` references from `template/AGENTS.md`.
3. Remove worker references from `template/docs/reference/codex-safety-harness.md` and `template/docs/reference/codex-implementation-harness.md`.
4. Remove worker references from `template/docs/PROJECT_CONTEXT.md`.
5. Remove `implementation_worker` from `spec/workflow.yaml`, `spec/safety-policy.yaml`, and `spec/routing.yaml`.
6. Remove worker-specific checks from `template/scripts/verify`.
7. Re-run `bash tools/validate-spec.sh` and `bash template/scripts/verify`.

## Risks / residual risks

- Codex CLI custom agent support may differ by environment or version.
- `sandbox_mode = "workspace-write"` gives the worker edit capability, so parent-agent scoping and post-worker review are mandatory.
- Technical guardrails may not catch every unsafe edit when hooks or execpolicy are unavailable, so instructions and review remain part of the safety model.
- Parallel writable agents can create conflicts and coordination overhead; default policy must remain one writable worker per task.
