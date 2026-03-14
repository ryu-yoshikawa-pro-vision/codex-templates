# 部分適合解消 実装ログ

- 作成日: 2026-02-27 (JST)
- 対象計画: `docs/plans/2026-02-27_partial-compliance-remediation-plan.md`

## 1. 実装サマリ
- P0:
  - `.codex/templates/REPORT.md` に `Open Issues` / `Next Action` を追加。
  - `.codex/templates/TASKS.md` の初期 `D1` / `B1` を非チェックボックス化。
- P1:
  - `scripts/codex-safe.sh` を追加（危険引数拒否、preflight、ログ出力、print-command）。
  - `scripts/tests/test-codex-safety-harness.sh` を追加。
  - `scripts/verify` を追加（品質ゲート一括実行）。
- P2:
  - `AGENTS.md` に Lightweight Execution Mode を追加。
  - `docs/PROJECT_CONTEXT.md`, `docs/agent/codex-safety-harness.md` を更新。

## 2. 検証結果
- 実行コマンド:
  - `bash scripts/tests/test-codex-safety-harness.sh`
  - `bash scripts/verify`
- 結果:
  - `bash scripts/tests/test-codex-safety-harness.sh` => `PASS: Bash Codex safety harness checks`
  - `bash scripts/verify` => `PASS=3 FAIL=0 SKIP=1`（PowerShell PATHに `codex` がないため PS テストは SKIP）

## 3. 再評価（部分適合 -> 適合）
- 不確実性対応:
  - 判定: 適合
  - 根拠:
    - `.codex/templates/REPORT.md` に `Open Issues` / `Next Action` を追加済み。
    - 検証run（`.codex/runs/20260227-115853-JST-verify/REPORT.md`）で初期項目反映を確認。
- 安全制約:
  - 判定: 適合（bash経路）
  - 根拠:
    - `scripts/codex-safe.sh` を追加し、危険引数拒否・preflight・ログ出力を実装。
    - `scripts/tests/test-codex-safety-harness.sh` で block/allow の共通ケースがPASS。
    - PowerShell側 `codex` PATH 未解決環境では `scripts/verify` がSKIP扱いで記録。
- 品質ゲート:
  - 判定: 適合
  - 根拠:
    - `scripts/verify` を追加し、execpolicy判定・wrapper preflight・テスト実行を1コマンド化。
    - 実行結果が PASS/FAIL/SKIP と終了コードで取得可能。
- 汎用性:
  - 判定: 適合
  - 根拠:
    - `AGENTS.md` に Lightweight Execution Mode を追加し、適用条件と禁止条件を明文化。
    - `.codex/templates/TASKS.md` の初期進捗ノイズ（`D1`/`B1`）を除去済み。

## 4. 残課題
- PowerShell 環境で `codex` が PATH 解決できない場合、PowerShellハーネステストは `scripts/verify` 上で SKIP となる。
- 運用上は bash wrapper (`scripts/codex-safe.sh`) を標準経路として利用可能。

## 5. 追加レビューでの修正
- 指摘:
  - `scripts/codex-safe.sh` は `set -e` の影響で、Codex実行失敗時に `codex_exec_exit` ログを書けないケースがあった。
- 修正:
  - Codex実行ブロックを `set +e` / `set -e` で囲み、失敗時でも終了コードを取得して `codex_exec_exit` を必ず記録するように変更。
  - `scripts/tests/test-codex-safety-harness.sh` に「Codex失敗時でも `codex_exec_exit` が出力される」検証ケースを追加。
- 再検証:
  - `bash scripts/tests/test-codex-safety-harness.sh` => PASS
  - `bash scripts/verify` => PASS=3 FAIL=0 SKIP=1
