# Codex SDK runner contract checklist

## Safety

- [ ] Supports a safe mode equivalent to `codex-task --preset safe`.
- [ ] Supports a read-only mode equivalent to `codex-task --preset readonly`.
- [ ] Supports explicit network opt-in equivalent to `--preset auto-net`.
- [ ] Does not require dangerous bypass.
- [ ] Can block or prevent delete / rename / git mutation paths.
- [ ] Does not weaken existing hook / execpolicy / wrapper safety layering.

## Artifacts

- [ ] Captures an output file equivalent to `--output-last-message`.
- [ ] Emits a low-level report artifact equivalent to `codex-task` report JSON.
- [ ] Emits structured event logs equivalent to JSONL log coverage.
- [ ] Can update or feed a `run.json` manifest without changing its ownership model.
- [ ] Preserves `evaluation.json` as the source of truth for failure interpretation.
- [ ] Can record validation commands, changed files, scope violation state, and `primary_failure_category` parity.

## Validation

- [ ] Supports output schema validation with comparable failure reporting.
- [ ] Supports evaluation schema validation and `run_id` consistency checks.
- [ ] Supports verify-command execution and result recording.
- [ ] Supports `require-evaluation` behavior.
- [ ] Supports `require-clean-git` behavior, including `.codex/runs/` exclusion.
- [ ] Supports `require-run-id` without silently generating a replacement ID.

## Scope control

- [ ] Evaluates `allowed_files` as an upper bound, not as a wish list.
- [ ] Evaluates `expected_changed_files` as required touched files.
- [ ] Includes untracked files in scope evaluation.
- [ ] Includes deleted files in scope evaluation.
- [ ] Includes renamed files with both old and new paths in scope evaluation.
- [ ] Excludes generated files under `.codex/runs/` from source scope checks.
- [ ] Normalizes paths to repo-relative POSIX paths across platforms.

## Portability

- [ ] Works on Windows PowerShell with the same contract.
- [ ] Works on WSL with the same contract.
- [ ] Works on Linux bash with the same contract.
- [ ] Can be validated on GitHub Actions Ubuntu runners.
- [ ] Does not require consumer repos to install heavy or fragile dependencies by default.

## Consumer distribution

- [ ] Can remain source-repo-only until adoption conditions are met.
- [ ] Has a clear reason to exist beyond duplicating `codex-task`.
- [ ] Has an acceptable dependency and version-drift story for consumer repos.
- [ ] Has a documented fallback path back to `codex-task`.
- [ ] Can be explained without changing `template/` before adoption is approved.

## Decision

- [ ] Adopt into core template
- [ ] Keep source-repo-only experimental
- [ ] Reject for now
- [ ] Needs more evidence
