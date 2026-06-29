# Changelog

このファイルは、consumer repo へ配布する template の変更履歴を記録します。

## Version policy

`template/codex-project.toml` の `template_version` は、consumer-facing contract の変更に合わせて更新します。

- Major: 既存 consumer repo の運用、配置、必須ファイル、migration 手順に破壊的変更がある。
- Minor: consumer-facing file、workflow、safety rule、guide、配布手順を追加・拡張する。
- Patch: 誤字、説明補足、validator の非破壊的修正、source repo 内部の保守。

## 0.11.0 - 2026-06-29

### Added

- `template/scripts/verify --strict-harness` と `template/scripts/verify.ps1 -StrictHarness` を追加し、source repo maintainer 向け strict harness verification を通常 verify から分離。
- `template/scripts/cleanup-runs.sh` と `template/scripts/cleanup-runs.ps1` を追加し、generated run artifact cleanup を dry-run default / confirm required で実行できるようにした。
- `tools/plan-consumer-update.sh` と `tools/plan-consumer-update.ps1` を追加し、consumer repo 更新前に version 差分、protected path、candidate updates、manual review を確認できるようにした。
- `scripts/new-run.sh` と `scripts/new-run.ps1` を追加し、run directory と `run.json` の初期化を自動化。
- `codex-task` に `--allowed-dirs` / `--allowed-globs` を追加し、directory 単位と limited glob の scope 指定をサポート。
- `codex-task` に `--expected-missing warn|fail` を追加し、変更不要だった expected file を warning として表現できるようにした。
- `run.json.validation.warnings` と `validation.status = passed_with_warnings` を追加し、non-fatal validation warning を機械記録できるようにした。
- Repair loop skill と reference docs を追加し、Review -> Repair -> Validate の bounded workflow を標準化。
- Harness improvement skill と reference docs を追加し、評価結果からハーネス改善候補へ変換する workflow を標準化。
- Repair loop / harness improvement の examples と validation tests を追加。
- Hook observation JSONL の schema と optional observation hook baseline を追加。
- Subagent run logging の schema と reference docs を追加。
- Observation / subagent schema の bundled template copy と validator sync check を追加。
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
- `codex-task` に `--evaluation-template` / `--require-evaluation` の baseline support を追加。
- `codex-task` に `--require-clean-git` / `--require-run-id` の runner precondition support を追加。
- `--max-iterations` の repair-loop 向け予約仕様を追加。
- `evaluation.json` の schema validation 結果を `run.json.validation.commands` に記録するようにした。
- `run.json.evaluation_path` と `run.json.primary_failure_category` を valid evaluation artifact から更新できるようにした。

### Changed

- `tools/sync-template.sh` と `tools/sync-template.ps1` に `--plan-only` / `-PlanOnly` と `--exclude-protected` / `-ExcludeProtected` を追加し、consumer 固有 path を保った safe overlay sync を選べるようにした。
- `tools/validate-spec.sh`、`tools/validate-spec.ps1`、`template/scripts/verify`、`template/scripts/verify.ps1` を更新し、version / changelog / migration 整合性と strict harness verification を固定した。
- `.github/workflows/validate-template.yml` を更新し、strict verify、cleanup、consumer update planning の Bash / PowerShell parity checks を CI に追加した。
- `README.md`、`template/docs/guides/consumer-update.md`、`template/docs/reference/run-artifacts.md`、`template/docs/reference/codex-safety-harness.md`、`template/docs/reference/codex-implementation-harness.md` を更新し、strict verify、safe cleanup、consumer update planning の運用を明文化した。
- `template/AGENTS.md`、`template/PLANS.md`、`template/docs/reference/codex-implementation-harness.md`、`template/docs/reference/change-scope-policy.md`、`template/docs/guides/quickstart.md` を更新し、lightweight / standard / strict の運用差分、run 初期化手順、Plan ambiguity 分類を明文化。
- `template/codex-project.toml` の workflow metadata を更新し、run manifest / evaluation / scope expectation の違いを明示。
- `spec/change-scope-policy.json`、`spec/run-manifest.schema.json`、`spec/workflow.json` を更新し、new-run、flexible scope、warning manifest を contract に追加。
- `template/docs/reference/codex-safety-harness.md` に `apply_patch` の operation policy 表を追加。
- `template/docs/guides/quickstart.md` から consumer update guide へ誘導するように更新。
- `tools/validate-spec.sh`、`tools/validate-spec.ps1`、`template/scripts/verify` を拡張し、新規 schema / template / static catalog / reference docs の整合性を検証するように更新。
- `template/docs/reference/change-scope-policy.md` を更新し、Markdown contract と JSON catalog の責務を明確化した。
- `run.json` を low-level `codex-task-*.report.json` の置き換えではなく aggregate manifest として扱うように `codex-task` wrapper と integration test を更新。
- `spec/run-manifest.schema.json`、validator、wrapper runtime record を `host | docker-sandbox | sdk` に揃えた。
- `template/docs/reference/run-artifacts.md` と `template/.codex/templates/EVALUATION.md` を更新し、runner completion milestone の evaluation / clean git / reserved max iterations contract を明文化した。

### Migration notes

- 既存 consumer repo は通常 `scripts/verify` を継続利用できる。template 配布前の maintainer check として strict harness verify を追加する。
- generated run artifact を整理したい場合は、まず `bash scripts/cleanup-runs.sh --dry-run` または PowerShell 版 dry-run を使う。デフォルトで削除は行わない。
- 既存 consumer repo 更新前に `tools/plan-consumer-update.*` で version 差分、protected path、manual review 項目を確認する。
- direct sync を使う場合は、まず `--plan-only` または `--dry-run` を実行し、可能なら `--exclude-protected` / `-ExcludeProtected` を使う。
- `docs/PROJECT_CONTEXT.md`、`docs/adr/`、`docs/plans/`、`docs/reports/`、`docs/history/`、`.codex/runs/`、`.env*` は上書きしない。
- no automatic repair loop execution
- no SDK runner implementation
- no destructive cleanup by default
- 既存 consumer repo がこの更新を取り込む場合は、`scripts/new-run.sh`、`scripts/new-run.ps1`、`scripts/codex-task.sh`、`scripts/codex-task.ps1`、`.codex/templates/RUN_MANIFEST.json`、`docs/reference/codex-implementation-harness.md`、`docs/reference/change-scope-policy.md`、`AGENTS.md`、`PLANS.md`、`codex-project.toml` を合わせて同期する。
- 既存 consumer repo が `expected-missing=warn` と flexible scope を使う場合は、`spec/change-scope-policy.json` に対応する reference docs と validator/verify の更新も取り込む。
- 既存 consumer repo が repair / improvement workflow を取り込む場合は、`.agents/skills/repair-loop/`、`.agents/skills/harness-improvement/`、`docs/reference/repair-loop.md`、`docs/reference/harness-improvement-loop.md`、`examples/repair-loop/`、`examples/harness-improvement/`、`scripts/verify` を同期対象に含める。
- 既存 consumer repo が更新後の `template/scripts/verify` を取り込む場合は、`.codex/templates/RUN_MANIFEST.json`、`.codex/templates/EVALUATION.md`、`docs/reference/run-artifacts.md`、`docs/reference/failure-taxonomy.md`、`docs/reference/evaluation.md`、`docs/reference/change-scope-policy.md` も同期対象に含める。
- 既存 consumer repo が `codex-task` 更新を取り込む場合は、`scripts/codex-task.sh`、`scripts/codex-task.ps1`、`.codex/templates/RUN_MANIFEST.json`、`codex-project.toml` を合わせて同期する。
- 既存 consumer repo が runner completion milestone を取り込む場合は、`docs/reference/run-artifacts.md`、`docs/reference/change-scope-policy.md`、`.codex/templates/EVALUATION.md`、`scripts/verify` も同期対象に含める。

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
