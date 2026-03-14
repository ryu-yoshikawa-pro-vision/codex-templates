# Source Repo 計画書

## 0. 依頼概要
- 依頼内容:
  - Codex 実装ハーネスを多層化し、`codex-task` と `codex-sandbox` を template に追加する。
- 背景:
  - 既存 template は `codex-safe` による手動対話実行の安全制御はあるが、非対話 `codex exec` と Docker 隔離実行の導線がない。
- 期待成果:
  - consumer-facing template / spec / tests / maintainer docs が、新しい実装ハーネス構成を一貫して説明・検証できる。

## 1. ゴール / 完了条件
- ゴール:
  - `manual interactive`、`non-interactive task`、`docker sandbox` の 3 層を分離した Codex ハーネスを追加する。
- 完了条件（DoD）:
  - `template/scripts/codex-task.ps1|sh` と `template/scripts/codex-sandbox.ps1|sh` が動作する。
  - `template/docs/reference/codex-implementation-harness.md` と関連導線が更新される。
  - `spec`、`tests`、`maintainers/` が新契約へ追従する。

## 2. スコープ
- In Scope:
  - `template/scripts/`
  - `template/docs/reference/`
  - `template/AGENTS.md`
  - `template/README.md`
  - `template/docs/PROJECT_CONTEXT.md`
  - `template/.codex/requirements.toml`
  - `spec/`
  - `tests/`
  - `maintainers/`
- Out of Scope:
  - 既存 `codex-safe` の preset / blocked option 契約変更
  - Docker runtime の自動 fallback

## 3. 実行タスク
- [ ] 1. run artifact と source-repo plan handoff を更新する
- [ ] 2. `codex-task` / `codex-sandbox` / schema validator を実装する
- [ ] 3. docs / spec / verify / tests / maintainer docs を新ハーネスへ更新する

## 4. マイルストーン
- M1: wrapper 実装と stub ベース integration test の骨格が揃う
- M2: consumer-facing docs / spec / verify が新ハーネスを説明する
- M3: 実行可能な validation が通り、環境制約を記録する

## 5. リスクと対策
- リスク:
  - Docker runtime は認証、image、mount 制約で失敗しやすい
  - bash 系 validation は環境依存で実行不能な場合がある
  - `codex exec` の schema 出力だけに依存すると異常系検証が弱い
  - 対策:
    - Docker runtime は `CODEX_DOCKER_IMAGE` 必須の experimental 機能とする
    - bash 系は実行不可時に明示 skip として記録する
    - repo-local schema validator を追加して post-run で再検証する

## 6. 検証方法
- 実施する確認:
  - `tools/validate-spec.ps1`
  - `bash tools/validate-spec.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`
  - `bash tests/integration/test-codex-safety-harness.sh`
  - `bash tests/integration/test-codex-task-harness.sh`
- 成功判定:
  - 実行可能な PowerShell 系がすべて成功し、bash 系は成功または環境制約として説明できる

## 7. 成果物
- 変更ファイル:
  - `template/scripts/codex-task.ps1|sh`
  - `template/scripts/codex-sandbox.ps1|sh`
  - `template/scripts/validate-output-schema.py`
  - `template/docs/reference/codex-implementation-harness.md`
  - `spec/*`
  - `tests/*`
  - `maintainers/*`
- 付随ドキュメント:
  - ADR
  - PROJECT_CONTEXT / history

## 8. 備考
- Docker runtime は v1 では opt-in 実験機能として実装し、標準経路は host runtime を維持する。
