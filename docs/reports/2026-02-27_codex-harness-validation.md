# Codex 安全ハーネス実装・検証レポート

- 作成日: 2026-02-27 (JST)
- 対象実装:
  - `.codex/rules/*.rules`（execpolicy ルール）
  - `scripts/codex-safe.ps1`（安全起動 wrapper）
  - `.codex/config.toml`（project profile）
  - `.codex/requirements.toml`（補助的な要件ドキュメント）
  - `scripts/tests/Test-CodexSafetyHarness.ps1`（検証スクリプト）

## 1. 実装概要

- 多層防御構成を実装した:
  - `AGENTS.md`: 運用ルール（ソフト制御）
  - `.codex/rules/*.rules`: `execpolicy` による allow/prompt/forbidden
  - `scripts/codex-safe.ps1`: 危険 CLI 引数拒否 + `sandbox/approval` 固定 + preflight
  - `scripts/tests/Test-CodexSafetyHarness.ps1`: ルール・wrapper の自動スモークテスト
- wrapper はユーザー指定の `-c/--config`, `--add-dir`, `-C/--cd`, `--sandbox`, `--ask-for-approval`, `--profile`, `--dangerously-bypass-approvals-and-sandbox` などを拒否する。
- wrapper は JSONL ログ（`.codex/logs/`）に開始/ブロック/preflight/起動イベントを記録できる（既定ON、`-NoLog` で無効化可能）。

## 2. 前提確認（実測）

- `codex --version` => `codex-cli 0.104.0-alpha.1`
- `codex execpolicy --help` / `codex execpolicy check --help` => 利用可能
- `codex sandbox --help` => Windows sandbox サブコマンドあり
- `codex features list` => 現行機能一覧を確認（`execpolicy` 自体は CLI サブコマンドで提供）

## 3. 主要検証結果

### execpolicy ルール判定

- `codex execpolicy check ... -- git reset --hard HEAD~1` => `forbidden`
- `codex execpolicy check ... -- docker ps` => `prompt`
- `scripts/tests/Test-CodexSafetyHarness.ps1` 内の判定:
  - `git status` => `allow`
  - `git add .` => `prompt`
  - `terraform destroy -auto-approve` => `forbidden`

### wrapper（`scripts/codex-safe.ps1`）

- `-PreflightOnly` => PASS（ルールスモークテスト成功）
- `-PrintCommand exec --help` => `--sandbox workspace-write` / `--ask-for-approval untrusted` が注入されることを確認
- `-PrintCommand -LogPath <temp>` => ログファイルに `wrapper_start`, `preflight_ok`, `print_command` が記録されることを確認
- `-PrintCommand -Preset readonly exec --help` => read-only preset をプレビュー可能
- `-PrintCommand --dangerously-bypass-approvals-and-sandbox` => ブロック（期待どおり）
- `-PrintCommand --config sandbox_mode="danger-full-access"` => ブロック（期待どおり）
- `-PrintCommand --config=sandbox_mode="danger-full-access"` / `-c ...` => ブロック（期待どおり）
- `-PrintCommand --add-dir ...` / `-C ...` => ブロック（期待どおり）
- `-PrintCommand -a never` / `-s danger-full-access` => 短縮パラメータ解釈経由でもブロック（期待どおり）
- `-PrintCommand --search` => ブロック（デフォルト）
- `-PrintCommand -AllowSearch exec --help` => `--search` が追加されることを確認
- `-PrintCommand exec 'special ; | && backtick ` test'` => 特殊文字を含む引数でも wrapper が正常に処理できることを確認
- `-PrintCommand exec 'wildcard *.md and envvar $env:USERPROFILE text'` => ワイルドカード/環境変数風文字列でも wrapper が破綻しないことを確認

### 自動検証スクリプト

- `powershell -ExecutionPolicy Bypass -File scripts/tests/Test-CodexSafetyHarness.ps1` => `PASS: Codex safety harness rules and wrapper checks`

## 4. 残留事項 / 制限

- `.rules` の「Codex 実行時の自動読込」については、今回の検証では `codex execpolicy check` による静的検証を主に実施した。
  - 対策: wrapper の preflight に `codex execpolicy check` を組み込み、ルール破損や主要判定の崩れを起動前に検知する。
- `.codex/requirements.toml` の実際の強制適用は、Codex の利用形態（managed policy / feature 設定 / 管理配布）に依存する。
  - 対策: このリポジトリでは wrapper + rules を主軸にし、`requirements.toml` は補助的に配置。
- `execpolicy` は prefix ベースであり、複雑な PowerShell 構文の完全解析はできない。
  - 対策: wrapper 側の引数制御、`approval_policy=untrusted`、sandbox を併用する。
- wrapper テストは PowerShell の `Start-Process` ベースで実施しているため、対話シェル固有の stop-parsing 演算子（`--%`）の挙動を完全再現するものではない。
  - 対策: 実運用では wrapper 自体で危険オプション値を拒否し、対話実行時も `scripts/codex-safe.ps1` 経由に統一する。

## 5. 次の実装候補（任意）

- チーム配布用に `codex-safe.ps1` のインストール手順（PowerShell profile alias 設定）を `docs/agent/` に追加する
