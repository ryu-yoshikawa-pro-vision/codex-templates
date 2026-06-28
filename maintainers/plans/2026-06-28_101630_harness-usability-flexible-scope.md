# Harness usability & flexible scope plan

## `spec/` impact
- あり。`spec/workflow.json`、`spec/change-scope-policy.json`、`spec/run-manifest.schema.json` を更新する。

## Goal
- safety boundary を維持したまま、consumer-facing harness の run 初期化、scope 指定、workflow level の明文化、expected-missing の柔軟化を追加する。

## Current understanding
- 現行 `template/scripts/codex-task.*` は `--allowed-files` / `--expected-changed-files` の exact-path baseline enforcement を持つ。
- `template/docs/reference/change-scope-policy.md` と `spec/change-scope-policy.json` は exact path 前提で、glob support は deferred と明記されている。
- `template/.codex/templates/RUN_MANIFEST.json` と `spec/run-manifest.schema.json` は `validation.status` に `not_run|passed|failed|skipped|blocked` を持つが warnings は未表現である。
- `template/scripts/new-run.*` は未実装で、quickstart は run directory の手動作成を前提にしている。
- workflow level は `template/AGENTS.md` と `template/codex-project.toml` にあるが、lightweight / standard / strict の artifact / plan / scope / evaluation 差分は十分に具体化されていない。
- `template/PLANS.md` の ambiguity handling は mandatory-question 中心で、Blocking questions / Assumptions allowed / Follow-up notes の分類は未定義である。

## Assumptions
- run manifest warnings は `validation.warnings` と `validation.status = "passed_with_warnings"` で表現する。
- `new-run` は `.codex/templates/{PLAN,TASKS,REPORT}.md` と `.codex/templates/RUN_MANIFEST.json` を利用し、既存 run を上書きしない。
- Bash は comma-separated、PowerShell は `string[]` 入力を受けつつ、内部 contract は同じ repo-relative POSIX path 配列に正規化する。

## Non-goals
- run artifact aggregation
- evaluation evidence restructuring
- strict verify mode
- cleanup / delete / rename workflow
- SDK runner
- auto-net 権限拡張

## Source-repo changes
- `spec/` の contract 更新
- validator / integration tests 更新
- `CHANGELOG.md` / `MIGRATION.md` 更新
- source-repo plan と run-local artifacts 更新

## Consumer-facing changes
- `template/AGENTS.md`、`template/PLANS.md`、quickstart、reference docs の更新
- `template/codex-project.toml` の workflow metadata 更新
- `template/scripts/new-run.sh` / `template/scripts/new-run.ps1` の追加
- `template/scripts/codex-task.sh` / `template/scripts/codex-task.ps1` の option / scope / warning handling 更新
- `template/scripts/verify` / `template/scripts/verify.ps1` の contract check 更新

## Validation plan
- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash tests/integration/test-codex-task-harness.sh`
- `bash tests/integration/test-new-run.sh`
- `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-NewRun.ps1`

## Migration / rollback
- Migration:
  - consumer repo がこの更新を取り込む際は `scripts/new-run.*`、`scripts/codex-task.*`、`docs/reference/*`、`AGENTS.md`、`PLANS.md`、`.codex/templates/RUN_MANIFEST.json`、`codex-project.toml` を合わせて同期する必要がある。
- Rollback:
  - `new-run` を削除せず、必要なら呼び出し導線を差し戻す。
  - scope expansion が問題を起こした場合は `allowed_dirs` / `allowed_globs` / `expected_missing` を exact-path baseline に戻す。

## Risks
- glob matching を shell 任せにすると OS 差分が出る。
- warning status 追加で schema / validator / wrapper / tests の更新漏れが起こりやすい。
- `new-run` の force semantics を誤ると既存 run 保護 contract を壊す。

## Open questions
- なし。
