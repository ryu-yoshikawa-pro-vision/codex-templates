# Run Artifact Aggregation & Evaluation Evidence

## spec/ 影響
- あり。`spec/run-manifest.schema.json` と `spec/evaluation.schema.json` を互換維持で拡張する。

## Goal
- `run.json` を run 単位の aggregate manifest として実用化し、hook / subagent / evaluation evidence の参照可能性を上げる。

## Current understanding
- `run.json` は現状 `codex-task` が都度上書き生成しており、`codex_task_reports` / `changed_files` / `validation` / `evaluation_path` / `primary_failure_category` の基本 summary だけを持つ。
- hook observation と subagent run record は schema / docs / baseline があるが、run manifest への自動統合は未実装である。
- `evaluation.json` は文字列 `evidence` のみを持ち、構造化参照は未定義である。
- Bash / PowerShell ともに `codex-task` harness test、`validate-spec`、`verify` が既存 contract を固定している。

## Assumptions
- `schema_version: 1` を維持し、新規 field は optional 追加とする。
- `run.json` は低レベル artifact を置き換えず、path / summary / count の集約に留める。
- `agents_used` は string array の互換を維持し、詳細は `subagents.records` で補う。
- invalid subagent JSON / invalid hook JSONL line は warning に落とし、run 全体 failure にはしない。

## Source-repo changes
- source repo:
  - `maintainers/plans/` に本計画を保存する。
  - `maintainers/PROJECT_CONTEXT.md` と `maintainers/history/` を新 contract に合わせて更新する。
  - 必要性が高ければ run artifact 集約方針を ADR として残す。

## Consumer-facing changes
- spec:
  - `spec/run-manifest.schema.json` に optional な `artifact_summary` / `hook_observations` / `subagents` を追加する。
  - `spec/evaluation.schema.json` に reusable `evidence_refs` item schema を追加し、dimensions / findings / improvement_candidates で optional 利用可能にする。
- template:
  - `template/.codex/templates/RUN_MANIFEST.json` を新 field を含む初期値へ更新する。
  - bundled `template/.codex/templates/evaluation.schema.json` を sync する。
  - `template/.codex/templates/EVALUATION.md` と `template/docs/reference/evaluation.md` に structured evidence guidance を追記する。
  - `template/docs/reference/run-artifacts.md` / `hook-observation.md` / `subagent-observation.md` / `codex-implementation-harness.md` を統合後の contract に更新する。
  - `template/scripts/collect-run-artifacts.sh` / `collect-run-artifacts.ps1` を追加する。
  - `template/scripts/codex-task.sh` / `codex-task.ps1` を collector 連携に更新する。
- validation/tests:
  - `tools/validate-spec.sh` / `validate-spec.ps1` に新 field / new enum / template default を追加する。
  - `template/scripts/verify` / `verify.ps1` に collector script と docs wording の確認を追加する。
  - `tests/integration/test-run-artifact-aggregation.sh` / `Test-RunArtifactAggregation.ps1` を追加する。
  - 必要に応じて `test-codex-task-harness.*` と `test-new-run.*` の manifest assertion を更新する。

## Validation plan
- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash tests/integration/test-codex-safety-harness.sh`
- `bash tests/integration/test-new-run.sh`
- `bash tests/integration/test-change-scope-policy.sh`
- `bash tests/integration/test-run-artifact-aggregation.sh`
- `bash tests/integration/test-codex-task-harness.sh`
- `powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
- `powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-NewRun.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-ChangeScopePolicy.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-RunArtifactAggregation.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`

## Migration / rollback
- migration:
  - 既存 `schema_version: 1` を維持し、新 field を optional にするため既存 consumer artifact はそのまま valid とする。
  - `evidence` は required のまま維持し、旧 evaluation artifact の互換を壊さない。
- rollback:
  - collector script と docs / tests / validator をまとめて巻き戻せば旧 contract に戻せる。
  - `run.json` の追加 field は optional のため、読取側 rollback も比較的安全。

## Risks / open issues
- `codex-task` が途中で manifest を何度も書くため、既存 manifest merge を入れないと prior summary を消しやすい。
- hook event から `safety.*` を推定しすぎると source-of-truth が崩れるため、`SafetyBlocked` の count と既知 type だけに絞る必要がある。
- Bash / PowerShell の collector 実装差分が出やすいので、fixture ベースの integration test で parity を固定する。
