# Changelog

このファイルは、consumer repo へ配布する template の変更履歴を記録します。

## Version policy

`template/codex-project.toml` の `template_version` は、consumer-facing contract の変更に合わせて更新します。

- Major: 既存 consumer repo の運用、配置、必須ファイル、migration 手順に破壊的変更がある。
- Minor: consumer-facing file、workflow、safety rule、guide、配布手順を追加・拡張する。
- Patch: 誤字、説明補足、validator の非破壊的修正、source repo 内部の保守。

## Unreleased

### Added

- consumer repo 更新の詳細手順を `template/docs/guides/consumer-update.md` に追加。
- `.codex/runs/<run_id>/` の運用例として standard implementation、PR review、auto-net investigation の examples を追加。
- `examples/runs/README.md` に run examples の入口を追加。
- Codex harness の契約整理として `spec/artifact-responsibility.json`、`spec/failure-taxonomy.json`、`template/docs/reference/run-artifacts.md`、`template/docs/reference/failure-taxonomy.md`、`template/docs/reference/evaluation.md`、`template/docs/reference/change-scope-policy.md` を追加。
- Codex harness の schema validation support として `spec/evaluation.schema.json`、`spec/run-manifest.schema.json`、`template/.codex/templates/RUN_MANIFEST.json`、`template/.codex/templates/EVALUATION.md` を追加。
- `codex-task` に `--task-type`、`--workflow-level`、`--record-run-manifest` を追加。
- `codex-task --record-run-manifest --run-id <run_id>` で `.codex/runs/<run_id>/run.json` を生成する baseline support を追加。
- `spec/change-scope-policy.json` を追加し、`--allowed-files` / `--expected-changed-files` 実装前の変更範囲ポリシーを機械検証できるようにした。
- `codex-task` に `--allowed-files` / `--expected-changed-files` の baseline enforcement を追加。
- `run.json.changed_files` と `run.json.safety.scope_violation` を runner が記録するように更新。
- `.codex/runs/` 配下の generated artifact を scope check 対象外として扱うようにした。

### Changed

- `template/docs/reference/codex-safety-harness.md` に `apply_patch` の operation policy 表を追加。
- `template/docs/guides/quickstart.md` から consumer update guide へ誘導するように更新。
- `tools/validate-spec.sh`、`tools/validate-spec.ps1`、`template/scripts/verify` を拡張し、新規 schema / template / static catalog / reference docs の整合性を検証するように更新。
- `template/docs/reference/change-scope-policy.md` を更新し、Markdown contract と JSON catalog の責務を明確化した。
- `run.json` を low-level `codex-task-*.report.json` の置き換えではなく aggregate manifest として扱うように `codex-task` wrapper と integration test を更新。
- `spec/run-manifest.schema.json`、validator、wrapper runtime record を `host | docker-sandbox | sdk` に揃えた。

### Migration notes

- 既存 consumer repo が更新後の `template/scripts/verify` を取り込む場合は、`.codex/templates/RUN_MANIFEST.json`、`.codex/templates/EVALUATION.md`、`docs/reference/run-artifacts.md`、`docs/reference/failure-taxonomy.md`、`docs/reference/evaluation.md`、`docs/reference/change-scope-policy.md` も同期対象に含める。
- 既存 consumer repo が `codex-task` 更新を取り込む場合は、`scripts/codex-task.sh`、`scripts/codex-task.ps1`、`.codex/templates/RUN_MANIFEST.json`、`codex-project.toml` を合わせて同期する。

## 0.3.0 - 2026-06-27

### Changed

- `spec/*.yaml` を、実体に合わせて `spec/*.json` へリネーム。
- `tools/validate-spec.ps1` と `tools/validate-spec.sh` の spec 読み込み先を `.json` へ更新。
- README に最短導入手順、できること / できないこと、既存 consumer repo 更新手順、`auto-net` 利用条件、version policy を追加。
- consumer quickstart に新規導入手順、既存 repo 更新手順、mode 選択の目安を追加。
- `template/codex-project.toml` の patch operation policy を明確化。
- PowerShell validator に subagent spec validation を追加し、bash validator と検証観点を近づける。
- PRレビュー依頼テンプレートと GitHub Actions validation workflow を追加。
- Integration test の shell fixture 呼び出しを `bash` 経由に統一し、CI 上の実行権限差分を避ける。
- `tools/sync-template.sh` と `tools/sync-template.ps1` に dry-run と destructive overwrite の明示確認を追加。
- PowerShell sync で `.codex` など hidden entries も同期対象に含めるように修正。
- README と MIGRATION に安全な template sync 手順を追加。

### Migration notes

- `spec/*.yaml` を参照している source repo 側の手順やスクリプトがある場合は、`spec/*.json` へ参照を更新する。
- 既存 consumer repo へ template 更新を反映する場合は、まず dry-run で削除対象を確認する。
- `sync-template` で既存 destination を上書きする場合は、`--force` / `-Force` に加えて明示確認フラグを指定する。
- consumer repo へ template 更新を反映する場合は、`docs/PROJECT_CONTEXT.md` など consumer 固有ファイルを機械的に上書きしない。
