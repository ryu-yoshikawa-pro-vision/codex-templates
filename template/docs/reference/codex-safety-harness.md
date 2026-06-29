# Codex安全ハーネス運用ガイド

## 目的
- リポジトリ内で Codex を使う際に、危険な実行オプションやコマンドを減らすための実務的なガードレールを提供する。
- `AGENTS.md` のルールに加え、`execpolicy` ルールと wrapper で技術的制御を追加する。

## 構成
- `scripts/codex-safe.ps1`
  - Codex 起動 wrapper
  - 危険 CLI 引数（`--dangerously-bypass-approvals-and-sandbox`, `-c/--config`, `--add-dir` など）を拒否
  - 安全デフォルト（`--sandbox`, `--ask-for-approval`）を固定注入
  - 起動前に `codex execpolicy check` でルールのスモークテストを実施（preflight）
  - JSONL ログ（既定: `.codex/logs/codex-safe-YYYYMMDD.jsonl`、`--run-id` 指定時: `.codex/runs/<run_id>/logs/codex-safe-YYYYMMDD.jsonl`）に開始/ブロック/preflight/起動イベントを追記
- `scripts/codex-safe.sh`
  - bash 向け Codex 起動 wrapper（PowerShell 版と同方針）
  - 危険 CLI 引数の拒否、`--sandbox` / `--ask-for-approval` 固定注入、preflight を実施
  - `--print-command` / `--preflight-only` / `--allow-search` / `--run-id` / `--log-path` をサポート
- `.codex/agents/*.toml`
  - project-scoped custom agents の定義
  - `code_researcher` / `implementation_researcher` / `test_investigator` は read-only 調査 agent
  - `implementation_worker` は親 agent が承認した小さく限定された実装だけを扱う workspace-write agent
  - writable subagent は原則 1 タスクにつき 1 つだけ使い、削除、rename、git mutation、スコープ外編集をしない
- `.codex/rules/*.rules`
  - `execpolicy` ルール
  - 読み取り系の allow、広い prompt、破壊系の forbidden を定義
- `.codex/rules-auto-net/*.rules`
  - `--preset auto-net` 指定時だけ追加で読み込む execpolicy ルール
  - network / package manager / build / test 系を allow に寄せ、shell wrapper 系は hook 検証後まで forbidden にする
- `.codex/config.toml`
  - project-scoped default: `sandbox_mode = "workspace-write"`, `approval_policy = "untrusted"`, `web_search = "cached"`
  - workspace-write sandbox は `network_access = false`, `writable_roots = []`
  - login shell は `allow_login_shell = false`
  - project profile: `repo_safe`, `repo_auto_net`, `repo_readonly`
  - PreToolUse hook: `.codex/hooks/pre_tool_use_policy.ps1`
- `.codex/requirements.toml`
  - 管理配布/機能有効化時に使う補助的な最小要件定義
- `scripts/verify`
  - 品質ゲート実行の統一エントリポイント
  - execpolicy 判定、bash wrapper preflight、bash/PowerShell テスト（可能環境のみ）を実行
  - source repo maintainer は配布前に `--strict-harness` / `-StrictHarness` を追加実行し、spec / version / CI / update-planning contract も確認する
- `scripts/cleanup-runs.sh` / `scripts/cleanup-runs.ps1`
  - generated run artifact cleanup の preview / confirm entry point
  - デフォルトで削除せず、明示 confirm がある場合だけ既知 artifact を削除する

関連する上位ガイド:
- `docs/reference/codex-implementation-harness.md`
  - `codex-safe` / `codex-task` / `codex-sandbox` の使い分け

## 推奨起動方法
PowerShell から実行:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1
```

非対話実行の例:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 exec "作業内容..."
```

read-only preset:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -Preset readonly
```

auto-net preset:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -Preset auto-net
```

preflight のみ:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly
```

bash から実行:

```bash
bash scripts/codex-safe.sh
```

auto-net preset:

```bash
bash scripts/codex-safe.sh --preset auto-net
```

`auto-net` は明示指定時だけ有効です。wrapper default は `safe` のままです。

## 何をブロックするか（例）
- `--dangerously-bypass-approvals-and-sandbox`
- `-c` / `--config`
- `--add-dir`
- `-C` / `--cd`
- `-s` / `--sandbox`
- `-a` / `--ask-for-approval`
- `-p` / `--profile`
- `--enable` / `--disable`
- raw `--full-auto`

## 削除禁止
- プロジェクト配下の読み取りとファイル作成・編集は、通常の作業では承認なしで行ってよい。
- shell / PowerShell / git command による削除は禁止する。対象例は `rm`, `del`, `erase`, `Remove-Item`, `rmdir`, `unlink`, 通常の `git rm`。
- `cleanup-runs` は generated run artifact の限定 cleanup 用例外 command だが、preview-only default、confirm 必須、repo root 外 / symlink candidate 拒否を満たす前提でのみ使う。
- `auto-net` では `git add`, `git commit`, `git push`, `git rm`, `git reset`, `git clean` も forbidden にする。
- `auto-net` では delete / rename を含む patch operation も禁止する。不要に見えるファイルは削除候補として `REPORT.md` に記録する。
- `implementation_worker` も削除、rename、移動、git mutation、delete / rename を含む patch operation を行わない。
- 追跡済み runtime artifact を配布対象から外す migration では、明示された対象に限って `git rm --cached -- <path>` を使ってよい。物理ファイルは削除しない。

## apply_patch operation policy

`apply_patch` は通常のファイル編集には使ってよい。ただし delete / rename / move は、意図が見えづらく影響が大きいため、通常編集とは分けて扱う。

| 操作 | readonly | safe | auto-net |
| --- | --- | --- | --- |
| 既存ファイルの内容変更 | 不可 | 可 | 可 |
| 新規ファイル作成 | 不可 | 可 | 可 |
| ファイル削除 | 不可 | 原則不可。明示された対象とレビュー可能な理由がある場合のみ候補化 | 不可 |
| rename / move | 不可 | 要レビュー。必要性、影響、migration を説明する | 不可 |
| 削除候補の `REPORT.md` 記録 | 可 | 可 | 可 |

判断に迷う場合は、delete / rename / move を実行せず、`REPORT.md` に削除候補または移動候補として記録する。

## Hook guard
- `.codex/hooks/pre_tool_use_policy.ps1` は destructive command、remote script piping、delete / rename patch を補助的に検出する。
- `.codex/hooks/pre_tool_use_policy.py` は Python が標準化された環境向けの同等 hook 実装として残す。
- `.codex/config.toml` は PreToolUse hook を `pwsh` 経由で有効化する。`pwsh` がない環境や hooks 非対応の Codex CLI では hook が実行されない可能性があるため、execpolicy rules と shell wrapper 禁止を併用する。
- Phase 1 では shell wrapper 系の `bash -lc`, `sh -c`, `pwsh -Command`, `cmd /c` は auto-net rules 側で forbidden 寄りに扱う。

## Report file generation policy
- `docs/reports/` は durable な調査・監査・検証結果の置き場であり、通常のレビュー返答、進捗報告、軽い確認結果、run 内ログの既定保存先ではない。
- Report file を生成してよいのは、ユーザーが保存を明示した場合、計画 DoD に report file がある場合、複数ソース調査・監査・検証結果を後で参照する必要がある場合のみ。
- review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価では `docs/reports/` にファイルを作らない。
- 判断に迷う場合は report file を作らず、チャット返答と `.codex/runs/<run_id>/REPORT.md` に留める。

## 運用メモ
- ルール変更後は `-PreflightOnly` と `codex execpolicy check` で確認する。
- 破壊系ルールの追加時は検証を行い、保存依頼または DoD がある場合だけ `docs/reports/` に durable report を残す。
- consumer repo では `bash scripts/verify` を最初の確認コマンドとして使う。
- 非対話実行では `codex-safe` ではなく `codex-task` を使い、`--run-id` で run-local artifact に集約する。
