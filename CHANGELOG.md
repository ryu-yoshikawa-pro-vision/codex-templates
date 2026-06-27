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

### Changed

- `template/docs/reference/codex-safety-harness.md` に `apply_patch` の operation policy 表を追加。
- `template/docs/guides/quickstart.md` から consumer update guide へ誘導するように更新。
- `tools/validate-spec.sh`、`tools/validate-spec.ps1`、`template/scripts/verify` を拡張し、新規 schema / template / static catalog / reference docs の整合性を検証するように更新。

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
- 既存 consumer repo が更新後の `template/scripts/verify` を取り込む場合は、`.codex/templates/RUN_MANIFEST.json`、`.codex/templates/EVALUATION.md`、`docs/reference/run-artifacts.md`、`docs/reference/failure-taxonomy.md`、`docs/reference/evaluation.md`、`docs/reference/change-scope-policy.md` も同期対象に含める。
