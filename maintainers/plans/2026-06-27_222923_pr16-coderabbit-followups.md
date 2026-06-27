# Plan: PR #16 CodeRabbit follow-ups

## Objective
- PR #16 の CodeRabbit review comments で指摘された 3 件を、既存 runner / validator contract を変えずに是正する。

## Scope
- In:
  - `template/scripts/codex-task.sh`
  - `template/scripts/codex-task.ps1`
  - `tools/validate-spec.ps1`
  - `tests/integration/test-codex-task-harness.sh`
  - `tests/integration/Test-CodexTaskHarness.ps1`
- Out:
  - schema / docs / changelog / version の変更
  - option 追加
  - clean git check の仕様拡張

## Changes To Make
- Bash:
  - `--max-iterations ""` を invalid_args にするため、指定有無を別フラグで管理する。
  - `--require-clean-git` を `wrapper_start` log 書き込み前に実行する。
- PowerShell:
  - `max_iterations` の未指定と空文字指定を区別し、空文字を invalid_args にする。
  - `wrapper_start` log 書き込みを clean git precondition の後へ移動する。
- Validator:
  - `tools/validate-spec.ps1` で evaluation schema sync を property order 非依存の canonical 比較へ置き換える。
- Tests:
  - Bash / PowerShell integration test に `max-iterations ""` ケースを追加する。
  - `require-clean-git` clean case が run id なしでも自己生成 `.codex/logs` で失敗しないことを確認する。

## Definition of Done
- 指示された 5 ファイルの変更だけで review comment 3 件を解消する。
- 指定検証:
  - `bash tools/validate-spec.sh`
  - `bash template/scripts/verify`
  - `bash tests/integration/test-codex-task-harness.sh`
  - 可能なら safety / PowerShell tests も成功する。
