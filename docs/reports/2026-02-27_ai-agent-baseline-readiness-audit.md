# AIエージェント基本開発要件 適合監査

- 作成日: 2026-02-27 (JST)
- 監査対象: `codex-templates` リポジトリ
- 監査目的: 「AIエージェントが基本的な開発を進める要件」を満たしているかを確認し、どのプロジェクトにも適用しやすい汎用性の課題を抽出する。

## 1. 判定基準（外部ベースライン）
- OpenAI Agents SDK production best practices（承認・ガードレール・構造化出力・評価）
- Anthropic: Building effective agents（シンプル構成優先、必要時のみ複雑化）
- OWASP Top 10 for LLM Applications（Prompt Injection / Excessive Agency）
- NIST AI RMF + NIST SSDF（ガバナンス、測定、安全な開発実務）

## 2. 判定サマリ

| 観点 | 判定 | 根拠（主） | コメント |
|---|---|---|---|
| 計画/実行/報告のトレーサビリティ | 適合 | `AGENTS.md` §1-§3, `.codex/templates/*`, `.codex/runs/*` | run_id運用、タスク実行順、進捗算出、追記式REPORTが定義済み。 |
| 不確実性対応（調査ラウンド・証跡） | 部分適合 | `AGENTS.md` §10, `docs/agent/overrides.md` | ループは明確だが、`REPORT`テンプレートに `Open Issues/Next Action` が未定義で運用差分が発生。 |
| 安全制約（権限・危険操作抑止） | 部分適合 | `AGENTS.md` §7.1, `.codex/rules/*.rules`, `scripts/codex-safe.ps1` | 多層防御は強い。一方で wrapper が PowerShell 前提で、環境依存（PATH/OS）による実行ムラが出る。 |
| 品質ゲート（lint/type/test/build） | 部分適合 | `AGENTS.md` §6, `scripts/tests/Test-CodexSafetyHarness.ps1` | 方針はあるが、汎用 `verify` コマンドやCIワークフローは未整備。プロジェクト追加時の導入負荷が残る。 |
| 役割分離・改善ガバナンス | 適合 | `docs/agent/agent-role-design.md`, `docs/agent/improvement-guardrails.md`, `docs/adr/0002...` | Planner/Researcher/Executor/Reviewer、L1-L3承認境界、ロールバック要件が明文化。 |
| どのプロジェクトにも適用できる汎用性 | 部分適合 | 全体 | 必須規約が強く、軽量タスクでも手順が重くなりやすい。テンプレート初期値も進捗計算を崩しうる。 |

## 3. 総合評価
- 結論: **基本的な開発要件は満たしている（運用としては有効）**。
- ただし、**汎用運用としては「部分適合」**。
- 判定内訳: 適合 2 / 部分適合 4 / 未適合 0

## 4. 優先改善（汎用化のための最小セット）

### P0（すぐ対応）
1. `.codex/templates/REPORT.md` に `Open Issues` / `Next Action` を追加し、`AGENTS.md` §10 と整合させる。
2. `.codex/templates/TASKS.md` の初期プレースホルダチェックボックス（`D1`, `B1`）を非チェックボックス化し、進捗計算のノイズを除去する。

### P1（近いうちに対応）
1. `scripts/codex-safe.ps1` と同等の bash 版 wrapper を追加し、Windows以外でも同一制約を適用可能にする。
2. `scripts/verify`（または `Makefile`）を導入し、最低限の品質ゲート実行を1コマンド化する。

### P2（運用改善）
1. `AGENTS.md` に「軽量モード（調査省略条件・最小ログ）」を定義し、小規模タスクでの運用コストを抑える。

## 5. 監査中に実行した確認（抜粋）
- `codex execpolicy check ... -- git status` => `allow`
- `codex execpolicy check ... -- git add .` => `prompt`
- `codex execpolicy check ... -- git reset --hard HEAD~1` => `forbidden`
- `powershell.exe -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly` => 実行失敗（PowerShell側で `codex` コマンドを解決できない環境依存）
