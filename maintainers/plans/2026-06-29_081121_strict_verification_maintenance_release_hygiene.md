# Strict Verification, Safe Maintenance & Release Hygiene

## spec/ 影響
- あり。strict harness verify、cleanup、consumer update planning、version hygiene を `spec/` と `template/` の整合性前提で追加・検証する。

## Goal
- maintainer 向け strict harness verification を通常 verify から分離し、generated run artifact cleanup、consumer repo 更新計画、version/changelog/migration 整合性を安全に運用できる状態へする。

## Current understanding
- `template/scripts/verify` と `verify.ps1` はすでに広い template contract を検証しているが、consumer repo でも走る通常 verify と source repo 向け strict verification の境界が未分離である。
- `tools/validate-spec.*` は spec/template/docs/schema の同期確認を担っているが、template version と `CHANGELOG.md` / `MIGRATION.md` の整合性まではまだ固定していない。
- `tools/sync-template.*` は dry-run と destructive overwrite 確認を持つが、consumer repo 更新前に差分確認と protected path を機械的に示す planning helper は存在しない。
- generated run artifact は `.codex/runs/<run_id>/`、`.codex/logs/`、run-local report/logs/subagents に分散しているが、安全な cleanup 導線は未整備である。
- 現在の `template_version` は `0.10.0` で、今回の追加は consumer-facing workflow と maintenance command の拡張なので minor 更新が妥当である。

## Assumptions
- 今回は source repo 側で strict verify と CI を強化するが、consumer repo 向け通常 `scripts/verify` の負荷は大きく増やさない。
- cleanup script は既知の generated artifact だけを候補化し、デフォルトでは削除しない。
- protected path は docs/history 系、`.codex/runs/`、`.env*`、`.git/` を minimum set とし、sync/plan 両方で同じ基準を使う。
- `schema_version: 1` は維持し、`artifact_summary` / `hook_observations` / `subagents` の top-level required 化は行わない。

## Source-repo changes
- `maintainers/plans/` に本計画を保存する。
- `.codex/runs/20260629-081121-JST/` の PLAN/TASKS/REPORT/run.json を strict workflow 前提で更新する。
- 必要なら `maintainers/PROJECT_CONTEXT.md` と history を、strict verify / cleanup / consumer update planning の追加に合わせて更新する。
- 重要な恒久判断が増えた場合は ADR 追加を検討する。

## Consumer-facing changes
- verification:
  - `template/scripts/verify` に `--strict-harness` を追加する。
  - `template/scripts/verify.ps1` に `-StrictHarness` を追加する。
  - strict 時のみ source/spec/template/docs/tests/version 整合性を追加検証する。
- cleanup:
  - `template/scripts/cleanup-runs.sh` / `cleanup-runs.ps1` を追加する。
  - dry-run default、confirm flag 必須、run_id pattern 限定、repo root escape / symlink 拒否を実装する。
- consumer update support:
  - `tools/plan-consumer-update.sh` / `plan-consumer-update.ps1` を追加する。
  - human-readable / JSON 出力、protected path、candidate updates、recommended commands を提供する。
  - `tools/sync-template.*` は protected path awareness と plan-only/dry-run 誘導を最小限追加する。
- release hygiene:
  - `template/codex-project.toml` を `0.11.0` へ更新する。
  - `CHANGELOG.md`、`MIGRATION.md`、`README.md` に versioning / migration / strict verify / cleanup / consumer update の説明を加える。
  - `tools/validate-spec.*` で semver と version entry 整合性を確認する。
- tests/CI:
  - cleanup と consumer update planning の Bash / PowerShell parity tests を追加する。
  - `.github/workflows/validate-template.yml` に strict verify と新 integration tests を追加する。

## Validation plan
- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash template/scripts/verify --strict-harness`
- `bash tests/integration/test-new-run.sh`
- `bash tests/integration/test-codex-task-harness.sh`
- `bash tests/integration/test-run-artifact-aggregation.sh`
- `bash tests/integration/test-cleanup-runs.sh`
- `bash tests/integration/test-plan-consumer-update.sh`
- `powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
- `powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
- `powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-NewRun.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-RunArtifactAggregation.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-CleanupRuns.ps1`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-PlanConsumerUpdate.ps1`

## Migration / rollback
- migration:
  - 既存 consumer repo は通常 `scripts/verify` を継続利用できる。
  - maintainer は template 配布前に strict harness verify を追加実行する。
  - cleanup / consumer update planning は opt-in command とし、導入しなくても既存運用は継続できる。
- rollback:
  - strict verify 追加分は flag-gated にするため、必要なら追加 checks と docs を戻せば通常 verify contract を保ったまま rollback できる。
  - cleanup / update planning は独立 script と test に寄せ、問題時は個別に巻き戻せるようにする。
  - version 更新は consumer-facing 変更一式と同時 rollback を前提に扱う。

## Risks / open issues
- strict verify に通常 verify と同じ重さを持ち込むと consumer repo 向けの手軽さを損なうため、flag-gated 境界を明確に保つ必要がある。
- cleanup は command-based deletion policy と緊張関係があるため、既知 generated artifact 限定、confirm 必須、symlink/repo escape 拒否を tests で固定する必要がある。
- Bash / PowerShell の path 正規化差分で cleanup / consumer update planning の parity が崩れやすい。
- version entry 検証は `CHANGELOG.md` / `MIGRATION.md` の記法に依存するため、validator 側に brittle な文字列判定だけを増やしすぎないようにする。
