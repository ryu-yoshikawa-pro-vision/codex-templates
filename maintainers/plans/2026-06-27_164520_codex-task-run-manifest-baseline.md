# TASK-006A codex-task run manifest baseline 実装計画

作成日時: 2026-06-27 16:45:20 JST  
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`  
対象ブランチ: `feature/codex-task-run-manifest-baseline`

## 1. `spec/` 影響

あり。`spec/run-manifest.schema.json` の `runtime` enum を `host | docker-sandbox | sdk` に揃え、wrapper 実装と validator を整合させる。

## 2. Goal

`codex-task` が `--task-type`、`--workflow-level`、`--record-run-manifest` を受け付け、`--run-id` 指定時に `.codex/runs/<run_id>/run.json` を Bash / PowerShell 同等で生成できるようにする。

## 3. Current understanding

- `spec/run-manifest.schema.json` と `template/.codex/templates/RUN_MANIFEST.json` は既に存在するが、wrapper はまだ manifest を生成しない。
- 現状 wrapper は `codex-task-*.report.json` を低レベル report として生成し、run-local path へ集約する。
- `runtime` enum は schema / validator が `docker` を前提にしており、wrapper 実装の `docker-sandbox` とずれている。
- `tests/integration/test-codex-task-harness.sh` と `tests/integration/Test-CodexTaskHarness.ps1` が `codex-task` 本体の success / failure / schema / docker smoke を持っている。
- `CHANGELOG.md` は Unreleased に harness contract 追加まで記録済みで、consumer-facing behavior 追加分はまだ反映されていない。

## 4. Assumptions

- `run.json` の `repo` と `base_branch` は今回 `null` 固定でよい。
- `changed_files` は今回空配列固定でよい。
- `codex_task_reports` は repo root 相対 path を優先し、困難なケースのみ既存 absolute path を残す。
- `run.json` は `status=running` で先に作成し、終了時に更新する。
- `template/codex-project.toml` は minor bump として `0.5.0` へ更新する。

## 5. Source-repo changes

- `.codex/runs/20260627-164341-JST/` に run artifact を作成し、進捗と evidence を残す。
- `maintainers/plans/2026-06-27_164520_codex-task-run-manifest-baseline.md` に本計画を保存する。

## 6. Consumer-facing changes

- `template/scripts/codex-task.sh`
  - 新規 option parse / default / validation を追加する。
  - manifest state を保持し、run start / codex fail / schema fail / verify skipped / verify fail / success で `run.json` を更新する。
- `template/scripts/codex-task.ps1`
  - Bash と同等の option / default / manifest write を追加する。
- `spec/run-manifest.schema.json`
  - `runtime` enum を `docker-sandbox` へ揃える。
- `template/.codex/templates/RUN_MANIFEST.json`
  - default が schema と一致していることを維持する。
- `tools/validate-spec.sh` / `tools/validate-spec.ps1`
  - `runtime` 期待値を `host | docker-sandbox | sdk` に更新する。
- `tests/integration/test-codex-task-harness.sh` / `tests/integration/Test-CodexTaskHarness.ps1`
  - manifest success / invalid args / default metadata / verify status を追加検証する。
- `CHANGELOG.md`
  - 新規 option、run manifest 生成、aggregate manifest 責務、runtime enum 整合を追記する。
- `template/codex-project.toml`
  - consumer-facing change として `template_version = "0.5.0"` を検討し、今回上げる。

## 7. Validation plan

実装後に以下を実行する。

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
bash tests/integration/test-codex-safety-harness.sh
bash tests/integration/test-codex-task-harness.sh
```

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1
```

実行不能な項目があれば、run report とユーザー向け返答へ理由を残す。

## 8. Migration / rollback

- Migration:
  - consumer repo が wrapper 更新を取り込む場合、`scripts/codex-task.*`、`.codex/templates/RUN_MANIFEST.json`、`codex-project.toml`、必要な test / docs を同期する。
- Rollback:
  - 追加 option と manifest write を `codex-task.*` から外し、schema / validator / test / changelog / version を前状態へ戻すことでロールバック可能。

## 9. Risks / open issues

- report status と run manifest status の意味を混ぜると `completed` が task success に見える危険があるため、write helper で明示的に写像する。
- PowerShell の `--long-option` と native named parameter の両方を維持しながら validation を揃える必要がある。
- Bash / PowerShell で path 相対化がずれる可能性があるため、共通で repo root 相対 path を優先する。

## 10. 保存先

`maintainers/plans/2026-06-27_164520_codex-task-run-manifest-baseline.md`
