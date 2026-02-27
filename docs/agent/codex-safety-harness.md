# Codex安全ハーネス運用ガイド

## 目的

- リポジトリ内で Codex を使う際に、危険な実行オプションやコマンドを減らすための実務的なガードレールを提供する。
- `AGENTS.md` のルール（ソフト制御）に加え、`execpolicy` ルールと wrapper で技術的制御を追加する。

## 構成

- `scripts/codex-safe.ps1`
  - Codex 起動 wrapper
  - 危険 CLI 引数（`--dangerously-bypass-approvals-and-sandbox`, `-c/--config`, `--add-dir` など）を拒否
  - 安全デフォルト（`--sandbox`, `--ask-for-approval`）を固定注入
  - 起動前に `codex execpolicy check` でルールのスモークテストを実施（preflight）
  - JSONL ログ（既定: `.codex/logs/codex-safe-YYYYMMDD.jsonl`）に開始/ブロック/preflight/起動イベントを追記
- `scripts/codex-safe.sh`
  - bash 向け Codex 起動 wrapper（PowerShell 版と同方針）
  - 危険 CLI 引数の拒否、`--sandbox` / `--ask-for-approval` 固定注入、preflight を実施
  - `--print-command` / `--preflight-only` / `--allow-search` / `--log-path` をサポート
- `.codex/rules/*.rules`
  - `execpolicy` ルール
  - 読み取り系の allow、広い prompt、破壊系の forbidden を定義
- `.codex/config.toml`
  - 任意の project profile（`repo_safe`, `repo_readonly`）
- `.codex/requirements.toml`
  - 管理配布/機能有効化時に使う補助的な最小要件定義（このリポジトリでは wrapper+rules を主軸に運用）
- `scripts/verify`
  - 品質ゲート実行の統一エントリポイント
  - execpolicy 判定、bash wrapper preflight、bash/PowerShell テスト（可能環境のみ）を実行

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

preflight のみ（ルール検証）:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly
```

bash から実行:

```bash
bash scripts/codex-safe.sh
```

bash preflight のみ:

```bash
bash scripts/codex-safe.sh --preflight-only
```

品質ゲート一括実行:

```bash
bash scripts/verify
```

## 何をブロックするか（例）

- `--dangerously-bypass-approvals-and-sandbox`
- `-c` / `--config`（ユーザー任意上書き）
- `--add-dir`
- `-C` / `--cd`
- `-s` / `--sandbox`
- `-a` / `--ask-for-approval`
- `-p` / `--profile`
- `--enable` / `--disable`

## ログ出力

- 既定で `.codex/logs/codex-safe-YYYYMMDD.jsonl` に JSONL 形式でイベントログを追記する
- 記録例:
  - `wrapper_start`
  - `wrapper_blocked_args`
  - `preflight_start` / `preflight_ok` / `preflight_failed`
  - `print_command`
  - `codex_exec_start` / `codex_exec_exit`
- ログを無効化したい場合は `-NoLog` を指定する（監査性は低下する）
- ログ出力先を変更したい場合は `-LogPath <path>` を指定する

## 制限事項（重要）

- `.rules` は prefix ベースであり、すべてのシェル構文・PowerShell 構文を完全解析するものではない。
- wrapper は Codex の「起動時オプション」を強制する。Codex 内部の各コマンド実行制御は `sandbox + approval + execpolicy` の組み合わせに依存する。
- `requirements.toml` の強制は、Codex の利用形態（管理ポリシー/設定）に依存する。未適用でも wrapper+rules で fail-closed に寄せる。
- `.codex/config.toml` の profile は補助的なプリセット定義として配置している。wrapper は環境依存の profile 解決失敗を避けるため、既定では `--profile` を注入せず `--sandbox` / `--ask-for-approval` を直接指定する。

## 運用メモ

- ルール変更後は `-PreflightOnly` と `codex execpolicy check` で確認する。
- 破壊系ルールの追加時は、`docs/reports/` に検証結果を残す。
- wrapper や検証スクリプトを変更したら `scripts/tests/Test-CodexSafetyHarness.ps1` を実行する。
- bash wrapper 変更時は `scripts/tests/test-codex-safety-harness.sh` も実行する。
