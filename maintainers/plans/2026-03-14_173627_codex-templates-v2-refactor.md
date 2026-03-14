# Source Repo 計画書

## 0. 依頼概要
- 依頼内容: `codex-templates` を v2 構造へ破壊的に再編し、consumer-facing template / maintainer assets / spec を分離する。
- 背景: 現行構成では consumer 向け配布物、source repo の運用記録、仕様の正本が同居し、導線と責務が混ざっている。
- 期待成果: `template/` を唯一の配布面とし、`maintainers/` に source repo の運用資産を集約、`spec/` と `tools/` と `tests/` に整合検証を追加する。

## 1. ゴール / 完了条件
- ゴール: consumer が `template/` をそのまま新規 repo の土台として使え、maintainer は root 側で仕様・履歴・検証を保守できる状態にする。
- 完了条件（DoD）:
  - `template/` 配下に consumer-facing の `AGENTS.md`、mode 入口、`.codex/`、`.agents/skills/`、docs、scripts が揃っている
  - `maintainers/` 配下に `PROJECT_CONTEXT.md`、ADR、plans、reports、history、architecture が移管されている
  - `spec/` に workflow / safety / routing / naming の machine-readable 定義がある
  - `tools/validate-spec.*` と `tests/` が追加され、少なくとも整合検証と smoke/integration テストが実行できる
  - root `README.md` と `MIGRATION.md` が v2 導線を説明している

## 2. スコープ
- In Scope:
  - ルート構造の再編
  - consumer-facing 文書と maintainer 文書の分離
  - wrapper / verify / rules / skills / templates の再配置
  - spec と検証ツールの導入
  - 代表例の examples 化
- Out of Scope:
  - package 化や CLI 製品化
  - 旧パス互換レイヤーの維持
  - 外部公開レジストリや CI 配布の実装

## 3. 実行タスク
- [x] 1. run 初期化と計画 handoff を完了する
- [x] 2. 既存ファイルを template / maintainers / examples / 削除対象へ分類する
- [x] 3. `template/` を新設し consumer-facing 資産を移管・整合する
- [x] 4. `maintainers/` を新設し source repo の運用履歴と文脈を移管する
- [x] 5. `spec/` と `tools/` と `tests/` を追加する
- [x] 6. root README と MIGRATION を更新し v2 の使い方を明示する
- [x] 7. 検証を実行し、関連ログと履歴を更新する

## 4. マイルストーン
- M1: 新ディレクトリ境界の確立
- M2: consumer-facing template の成立
- M3: spec / tests / migration docs の成立

## 5. リスクと対策
- リスク:
  - 既存参照パスが広く分散しており、移動漏れでリンク切れが起きる
  - PowerShell / bash 両方の wrapper テストが新構造で壊れる可能性がある
  - root `AGENTS.md` の意味が source repo 用へ変わるため、手順差分が大きい
  - 対策:
    - `rg` と spec validation で旧参照を網羅検出する
    - consumer-facing `verify` と source-repo tests を分離する
    - `MIGRATION.md` に旧→新パス対応表を記載する

## 6. 検証方法
- 実施する確認:
  - `tools/validate-spec.ps1`
  - `bash tools/validate-spec.sh`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
  - `bash tests/integration/test-codex-safety-harness.sh`
- 成功判定:
  - spec と docs/script の参照整合が取れている
  - template の verify が consumer-facing 検証として通る
  - PowerShell / bash の安全ハーネステストが通る

## 7. 成果物
- 変更ファイル:
  - `template/`, `maintainers/`, `spec/`, `tools/`, `tests/`, `examples/` 以下
  - root `README.md`, `MIGRATION.md`, `AGENTS.md`, `PLANS.md`, `CODE_REVIEW.md`, `.gitignore`
- 付随ドキュメント:
  - `maintainers/plans/2026-03-14_173627_codex-templates-v2-refactor.md`
  - run ログ（`.codex/runs/20260314-173627-JST/`）
  - `maintainers/history/` と ADR

## 8. 備考
- root は source repo、`template/` は consumer repo の仮想ルートとして扱う。
