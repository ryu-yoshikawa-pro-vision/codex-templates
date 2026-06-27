# TASK-006 Runner completion plan

作成日時: 2026-06-27 21:06:18 JST

## spec/ 影響

- あり。既存 `spec/run-manifest.schema.json` と `spec/evaluation.schema.json` を runner 実装へ接続する。
- 原則として schema の大規模変更はしない。必要な場合でも最小変更に留める。

## Goal

`codex-task.sh` / `codex-task.ps1` に Runner completion milestone を実装し、evaluation artifact のテンプレート作成・必須化、pre-run clean git precondition、run id 必須化、`--max-iterations` の予約 contract、複数 validation command 記録を Bash / PowerShell 同等で提供する。

## Current understanding

- `--allowed-files` / `--expected-changed-files` baseline は実装済みで、`.codex/runs/` 除外付き changed files 収集も入っている。
- `run.json` schema はすでに `evaluation_path`、`primary_failure_category`、`validation.commands[]` array を持っている。
- 現行 runner は `validation.commands` を schema 上は array で書けるが、実装上は単一 command しか保持していない。
- `evaluation.schema.json` は今回要求されている skeleton を受け入れられる。
- 今回の要件は runner layer 完成が目的であり、evaluation judgement や repair loop 実装は非対象である。

## Assumptions

- `--max-iterations` は parse + validate まで実装し、runner 挙動は no-op の deferred contract とする。
- `--require-clean-git` は `git status --porcelain=v1 -z --untracked-files=all` を基準に source changes を判定し、`.codex/runs/` を除外する。
- evaluation validation は output schema / verify より後、最終 gate として扱う。

## 参照ファイル

- `maintainers/plans/2026-06-27_103240_codex-harness-strengthening.md`
- `maintainers/plans/2026-06-27_190607_codex-task-change-scope-baseline.md`
- `spec/evaluation.schema.json`
- `spec/run-manifest.schema.json`
- `spec/failure-taxonomy.json`
- `spec/change-scope-policy.json`
- `template/scripts/codex-task.sh`
- `template/scripts/codex-task.ps1`
- `template/scripts/validate-output-schema.py`
- `template/scripts/verify`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/change-scope-policy.md`
- `template/.codex/templates/EVALUATION.md`
- `tests/integration/test-codex-task-harness.sh`
- `tests/integration/Test-CodexTaskHarness.ps1`
- `tests/fixtures/fake-codex.sh`
- `tests/fixtures/fake-codex.ps1`
- `CHANGELOG.md`
- `template/codex-project.toml`

## 実装対象

- `--evaluation-template`
- `--require-evaluation`
- `--require-clean-git`
- `--require-run-id`
- `--max-iterations <n>`
- multi-command `validation.commands`
- docs / verify / tests / version bump

## やること

1. Bash / PowerShell runner に新規 option parse / validation / state を追加する。
2. validation command 記録を list 化し、schema validation・verify・evaluation validation・clean git check を共存させる。
3. evaluation template 作成、evaluation 必須 validation、manifest summary copy を実装する。
4. pre-run clean git check と require-run-id precondition を実装する。
5. `--max-iterations` の parse + integer validation + no-op deferred contract を実装する。
6. docs / verify / changelog / version を更新する。
7. Bash / PowerShell integration test を追加し、必要な fixture 補助を最小範囲で拡張する。

## やらないこと

- Hook observation
- Subagent run logging
- Repair loop skill
- Harness improvement skill
- OpenAI Agents SDK / Codex SDK integration
- prompt auto-injection
- runner による evaluation result 自動判断
- runner による failure category 推論
- `--record-evaluation`
- Codex の複数回自動実行
- unsafe / scope violation の自動 repair
- glob support
- run manifest schema の大規模変更
- failure taxonomy の新規カテゴリ追加

## evaluation gate flow

1. option parse / precondition validation
2. run path setup / initial manifest write
3. clean git check
4. evaluation template creation
5. preflight
6. Codex execution
7. changed files collection
8. allowed-files / expected-changed-files checks
9. output schema validation
10. verify
11. evaluation existence / JSON / schema / run_id match validation
12. valid evaluation の `primary_failure_category` を `run.json` summary field へ copy

## clean git precondition flow

1. `--require-clean-git` 指定時に Codex 実行前の source changes を収集する。
2. `.codex/runs/` は除外する。
3. dirty の場合は Codex を起動せず `dirty_git` で失敗する。
4. manifest 有効時は `validation.status = blocked` と `clean git check` command を記録する。

## require run id flow

1. `--require-run-id` 指定時に `--run-id` 未指定なら `invalid_args`。
2. `--run-id` 指定時は既存 format validation を使う。
3. `--record-run-manifest` の暗黙有効化はしない。

## max iterations deferred policy

- `--max-iterations <n>` は option parse 対象に含める。
- 値は整数、1 以上 10 以下のみ許可する。
- 今回の PR では repair loop を起動せず no-op とする。
- docs / verify / tests では deferred / reserved であることを明記する。

## validation.commands array policy

- runner state は validation command を配列で保持する。
- schema validation、verify、evaluation validation、clean git check は順序を保って追記する。
- short-circuit failure では 1 件のみでもよい。
- 既存 test の単一 command 前提は「該当 command を含む」確認へ更新する。

## Bash / PowerShell parity

- option contract、precondition、manifest field 更新、validation timing、failure status を揃える。
- evaluation template skeleton、evidence message、clean git exclusion、`--max-iterations` validation は同値にする。
- integration tests は同等ケースを Bash / PowerShell 両方へ追加する。

## Validation plan

- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash tests/integration/test-codex-safety-harness.sh`
- `bash tests/integration/test-codex-task-harness.sh`
- `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
- `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`

## rollback plan

- rollback は runner / docs / verify / tests / version bump をこの PR 単位で戻す。
- schema を触る場合は validator と template を同時 rollback する。
- repair loop には入らないため、多段実行制御の巻き戻しは発生しない。

## 後続PRでやること

- repair loop execution
- hook observation の構造化
- subagent logging
- evaluation authoring 補助 skill
- harness improvement skill
