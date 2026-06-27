# TASK-006B codex-task change scope baseline plan

作成日時: 2026-06-27 19:06:07 JST

## spec/ 影響

- あり。既存 `spec/change-scope-policy.json` と `spec/run-manifest.schema.json` の contract に沿って runner enforcement を実装する。
- 原則 schema 構造変更はしない。実装上どうしても必要な場合のみ最小変更に留める。

## Goal

`codex-task.sh` / `codex-task.ps1` に `--allowed-files` と `--expected-changed-files` の baseline enforcement を追加し、Codex 実行後の source changes を `run.json.changed_files` に記録しつつ、`.codex/runs/` generated artifact を scope check から除外する。

## Current understanding

- `run.json` は既に aggregate manifest として生成されるが、`changed_files` は空配列、`safety.scope_violation` は固定 `false` である。
- `spec/change-scope-policy.json` は path normalization、changed file kinds、`.codex/runs/` exclusion、exact path match を定義済みで、runner enforcement だけが deferred で残っている。
- `spec/run-manifest.schema.json` は `validation.status` / `validation.commands[].status` に `blocked` を許可している。
- Bash / PowerShell runner は引数解析、manifest 書き出し、schema validation、verify 実行の構造がほぼ対称である。

## Assumptions

- changed files の収集は `git status --porcelain=v1 -z --untracked-files=all` を用い、rename は old/new、copy は new を含める。
- path-list の repeatable option は split 結果を結合し、重複除去して扱う。
- `.codex/runs/` 配下の run artifact は source changes ではないため `changed_files` に混ぜない。

## Source-repo changes

- `maintainers/plans/2026-06-27_190607_codex-task-change-scope-baseline.md` を追加する。
- `.codex/runs/20260627-190607-JST/` に作業記録を残す。

## Consumer-facing changes

- `template/scripts/codex-task.sh`
- `template/scripts/codex-task.ps1`
- `template/scripts/verify`
- `template/docs/reference/change-scope-policy.md`
- `template/codex-project.toml`
- `CHANGELOG.md`
- `tests/integration/test-codex-task-harness.sh`
- `tests/integration/Test-CodexTaskHarness.ps1`
- 必要なら `tools/validate-spec.sh` / `tools/validate-spec.ps1`

## 参照ファイル

- `maintainers/plans/2026-06-27_103240_codex-harness-strengthening.md`
- `spec/change-scope-policy.json`
- `template/docs/reference/change-scope-policy.md`
- `spec/run-manifest.schema.json`
- `template/scripts/codex-task.sh`
- `template/scripts/codex-task.ps1`
- `tools/validate-spec.sh`
- `tools/validate-spec.ps1`
- `template/scripts/verify`
- `tests/integration/test-codex-task-harness.sh`
- `tests/integration/Test-CodexTaskHarness.ps1`
- `tests/integration/test-codex-safety-harness.sh`
- `tests/integration/Test-CodexSafetyHarness.ps1`
- `CHANGELOG.md`
- `template/codex-project.toml`

## 実装対象

- runner option parsing
- path-list normalization
- git changed files collection
- run manifest changed_files / safety update
- allowed-files / expected-changed-files 判定
- verify 前 failure short-circuit
- docs / verify / tests / version / changelog

## やること

1. Bash / PowerShell に `--allowed-files` / `--expected-changed-files` を追加する。
2. path-list を repo-relative POSIX path に正規化し、absolute path / repo escape / glob / empty を `invalid_args` にする。
3. scope options 使用時は `--run-id` と `--record-run-manifest` を必須にする。
4. Codex 実行後に changed files を収集し、`.codex/runs/` を除外した昇順・重複除去済み配列として `run.json.changed_files` に記録する。
5. allowed-files violation を最優先で `scope_violation` として失敗させる。
6. expected-changed-files missing を次順位で失敗させる。
7. verify / validator / integration tests / docs / changelog / version を同期する。

## やらないこと

- glob support
- pattern matching
- directory wildcard support
- evaluation / repair / hooks / subagent logging 拡張
- `.codex/runs/` 以外の generated artifact exclusion 追加
- run manifest への `allowed_files` / `expected_changed_files` 新規 field 追加

## path normalization 方針

- option value は comma-separated list として扱う。
- option repeatable とし、各指定値を flat に結合する。
- `\` を `/` に変換し、`.` / `..` を正規化する。
- 絶対 path、空値、glob 記号 `* ? [ ]` を含む値、repo root 外へ逃げる値は `invalid_args`。
- 正規化結果は repo-relative POSIX path の exact match 比較に使う。

## changed files collection 方針

- `git status --porcelain=v1 -z --untracked-files=all` を基準にする。
- tracked modified / added / untracked / deleted / renamed old path / renamed new path / copied new path を含める。
- `.codex/runs/` prefix は collection 後に除外する。
- 重複除去し、昇順ソートして `run.json.changed_files` に記録する。
- Codex 自体が失敗した場合も可能な範囲で収集する。

## Bash / PowerShell parity

- option contract、path validation、scope failure order、manifest update timing、changed file semantics を揃える。
- Bash は Python helper 併用可、PowerShell は native parsing を優先する。
- integration tests は Bash / PowerShell 両方へ同等ケースを追加する。

## Validation plan

- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash tests/integration/test-codex-safety-harness.sh`
- `bash tests/integration/test-codex-task-harness.sh`
- `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`

## Migration / rollback

- consumer-facing runner behavior changeのため `template/codex-project.toml` を `0.6.0` に bump する。
- rollback は今回の runner / test / docs / version 変更を単位で戻す。schema contract には極力手を入れないため巻き戻し範囲を限定できる。

## Risks / open issues

- Git porcelain parsingの片系バグで Bash / PowerShell 挙動差が出る可能性がある。
- `.codex/runs/` 除外が漏れると run artifact による false positive が出る。
- verify short-circuit 条件を誤ると `validation.status` / `report.status` の contract を壊す。

## rollback plan

- 失敗時は `codex-task` scope enforcement 関連差分のみを戻し、manifest baseline と既存 verify flow を維持する。
- schema 変更を入れた場合は validator と template を必ず同時 rollback する。

## 後続PRでやること

- glob / pattern matching support
- `.codex/runs/` 以外の generated artifact policy 拡張
- evaluation / failure taxonomy と連動した richer failure summaries
- `--require-clean-git` など周辺 enforcement の追加検討
