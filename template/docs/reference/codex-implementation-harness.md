# Codex実装ハーネス運用ガイド

## 目的
- Codex の実行経路を `manual interactive` / `non-interactive task` / `docker sandbox` に分け、用途ごとに安全性と再現性を揃える。

## 使い分け
- `scripts/codex-safe.ps1|sh`
  - 手動対話用の安全 wrapper。
  - preflight、危険引数拒否、sandbox/approval 固定、JSONL ログを提供する。
- `scripts/codex-task.ps1|sh`
  - 非対話 `codex exec` 用 wrapper。
  - 実行順は `preflight -> codex exec -> output/schema check -> verify -> report`。
  - `output-last-message` と machine-readable report JSON を必ず残す。
  - `--run-id` 指定時は `.codex/runs/<run_id>/artifacts|reports|logs` に既定出力を集約する。
- `scripts/codex-sandbox.ps1|sh`
  - `codex-task --runtime docker-sandbox` の薄い互換 wrapper。
  - Docker image と認証が明示設定されている場合だけ使う experimental path。

## `codex-task` の主な引数
- `--preset safe|readonly|auto-net`
- `--runtime host|docker-sandbox`
- `--prompt-file <path>` または末尾 prompt
- `--output-file <path>`
- `--output-schema <path>`
- `--report-path <path>`
- `--run-id <run_id>`
- `--verify-command <cmd>`
- `--allow-search`
- `--skip-preflight`
- `--skip-verify`

### `--verify-command` の扱い
- PowerShell wrapper:
  - 実在する `.ps1` / `.cmd` / `.bat` / `.sh` / 実行ファイル path は拡張子に応じて直接実行する。
  - それ以外は PowerShell command として実行する。
- bash wrapper:
  - `bash -lc "<cmd>"` として実行する。

## 成果物
- output file:
  - `codex exec --output-last-message` の最終出力
  - 既定: `.codex/artifacts/codex-task-YYYYMMDD-HHMMSS.json`
  - `--run-id` 指定時: `.codex/runs/<run_id>/artifacts/codex-task-YYYYMMDD-HHMMSS.json`
- report JSON:
  - 既定: `.codex/reports/codex-task-YYYYMMDD-HHMMSS.report.json`
  - `--run-id` 指定時: `.codex/runs/<run_id>/reports/codex-task-YYYYMMDD-HHMMSS.report.json`
  - 必須キーは `runtime`, `preset`, `prompt_source`, `output_file`, `output_schema`, `log_path`, `codex_exit_code`, `verify_exit_code`, `status`, `run_id`, `git_branch`, `git_dirty`, `cwd`, `mode`
- JSONL log:
  - wrapper start、preflight、codex exec、schema check、verify のイベントを追記する
  - 既定: `.codex/logs/codex-task-YYYYMMDD-HHMMSS.jsonl`
  - `--run-id` 指定時: `.codex/runs/<run_id>/logs/codex-task-YYYYMMDD-HHMMSS.jsonl`

## `--output-schema` の対応範囲
- repo-local validator が対応するのは、`type`, `enum`, `required`, `properties`, `items`, `additionalProperties` とメタデータ系キーのみ。
- `oneOf`, `anyOf`, `allOf`, `const`, `pattern`, `minimum` など未対応の keyword を含む schema は `invalid_output` ではなく「unsupported schema keyword」として失敗させる。

## Docker sandbox
- 既定では無効。`CODEX_DOCKER_IMAGE` を設定しない限り `docker-sandbox` runtime は失敗する。
- repo root を `/workspace` に mount し、必要なら `~/.codex` と `OPENAI_API_KEY` を container へ渡す。
- host fallback はしない。Docker 実行に必要な前提が足りない場合は明示エラーで止める。

## Subagent 実装フロー
- 実装前の調査は `code_researcher` / `implementation_researcher` / `test_investigator` に委譲できる。
- `implementation_worker` は、親 agent が計画、対象ファイル、変更範囲、禁止事項を確定した後にだけ使う。
- `implementation_worker` は小さく限定された実装を行う workspace-write subagent であり、親 agent が指定した対象ファイルだけを最小差分で編集する。
- writable subagent は原則 1 タスクにつき 1 つだけ使う。
- `implementation_worker` の実装後は、親 agent が diff、仕様判断、未検証点、検証結果を確認する。
- `implementation_worker` は削除、rename、移動、git mutation、delete / rename を含む patch operation、スコープ外リファクタリングを行わない。

## 推奨フロー
- 手動で探索・相談しながら進める:
  - `codex-safe`
- 生成物をファイルで残す自動実装・CI 補助:
  - `codex-task --run-id <run_id>`
- 外部隔離環境を明示的に用意できる:
  - `codex-sandbox`

## auto-net preset
- `codex-safe` と `codex-task` の既定 preset は `safe` のままです。
- network access つきで workspace 内の自律実装が必要なときだけ `--preset auto-net` を明示する。
- `auto-net` は `repo_auto_net` profile、`workspace-write` sandbox、`approval_policy = "never"`、workspace network enabled を使う。
- `codex-task` は非対話 harness なので、safe / readonly / auto-net のいずれでも Codex CLI には `--ask-for-approval never` を渡す。preset は profile、sandbox、preflight rules の選択に使う。
- raw `--full-auto`、`danger-full-access`、`--dangerously-bypass-approvals-and-sandbox` は使わない。
- `codex-task` の preflight は指定 preset を `codex-safe` に渡すため、safe と auto-net の期待値は分離される。

## 関連資料
- `docs/reference/codex-safety-harness.md`
- `docs/reference/repository-layout.md`
