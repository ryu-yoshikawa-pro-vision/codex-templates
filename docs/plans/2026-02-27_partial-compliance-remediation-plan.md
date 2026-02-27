# 部分適合解消 実装計画（2026-02-27）

## 0. 依頼概要
- 依頼内容:
  - 監査結果で「部分適合」と判定した項目を解消するための実装計画を作成する。
- 背景:
  - `docs/reports/2026-02-27_ai-agent-baseline-readiness-audit.md` で、以下4点が部分適合だった。
    - 不確実性対応（REPORTテンプレート整合）
    - 安全制約（PowerShell依存の実行ムラ）
    - 品質ゲート（verify導線不足）
    - 汎用性（運用の重さ・進捗ノイズ）
- 期待成果:
  - 優先度付き（P0/P1/P2）で、実装ファイル・検証方法・完了基準まで含む実装計画を確定する。

## 1. ゴール / 完了条件
- ゴール:
  - 部分適合4項目を、実装可能なタスク群に落とし込んだ実装計画を策定する。
- 完了条件（DoD）:
  - P0（テンプレート整合）完了後、新規run作成時に `Open Issues` / `Next Action` が初期状態で利用できる。
  - P0完了後、`TASKS.md` 初期状態で進捗計算の分母に不要項目が入らない。
  - P1（実行基盤）完了後、PowerShell と bash の両wrapperで主要ブロック要件が再現される。
  - P1完了後、`scripts/verify` 1コマンドで利用可能な品質ゲートを実行できる。
  - P2（運用軽量化）完了後、`AGENTS.md` に軽量モードの適用条件・必須証跡・禁止事項が明示される。

## 2. スコープ
- In Scope:
  - `.codex/templates/REPORT.md` の証跡項目整合
  - `.codex/templates/TASKS.md` の初期チェックボックス改善
  - `scripts/codex-safe.ps1` と等価方針の `scripts/codex-safe.sh` 追加
  - `scripts/verify` による品質ゲート実行導線の統一
  - `AGENTS.md` への軽量モード追記
  - 関連ドキュメント更新（`docs/PROJECT_CONTEXT.md`, `docs/agent/codex-safety-harness.md`）
- Out of Scope:
  - プロダクト本体の機能実装
  - 組織全体のCI/CD再設計
  - 外部規格（ISO等）への正式準拠監査

## 2.1 前提条件
- `codex` コマンドが bash / PowerShell の双方から解決可能であること。
- bash実行環境で `scripts/codex-safe.sh` をテストできること（WSL/CI Linux runner等）。
- L2/L3作業は Gate-A の承認取得後にのみ着手すること。

## 3. 承認ゲート
- Gate-A（着手前）:
  - `AGENTS.md` 改定、wrapper追加、実行制約に関わる変更は L2/L3 としてユーザー承認を取得してから実装する。
- Gate-B（P0完了時）:
  - テンプレート変更の差分レビューを行い、進捗計算と既存runへの影響を確認する。
- Gate-C（P1完了時）:
  - wrapper と verify のスモークテスト結果を提示し、P2着手可否を確認する。

## 4. 実行タスク
- [ ] 1. T01 (P0/L1): `.codex/templates/REPORT.md` に `Open Issues` / `Next Action` を追加する
- [ ] 2. T02 (P0/L1): `.codex/templates/TASKS.md` の初期 `D1`/`B1` を非チェックボックス表記へ変更する
- [ ] 3. T03 (P0/L1): 新規runを1回作成し、進捗算出とEvidence記録が崩れないことを確認する
- [ ] 4. T04 (P1/L3): `scripts/codex-safe.sh` を追加し、危険引数拒否・preflight・ログ出力を実装する
- [ ] 5. T05 (P1/L2): bash版wrapperのスモークテストを追加し、PowerShell版と共通ケースで照合する
- [ ] 6. T06 (P1/L2): `scripts/verify` を追加し、存在する品質ゲートのみを順次実行する
- [ ] 7. T07 (P2/L2): `AGENTS.md` に軽量モード（適用条件・最小証跡・省略可否）を追加する
- [ ] 8. T08 (P2/L1): `docs/PROJECT_CONTEXT.md` と `docs/reports/2026-02-27_partial-compliance-remediation-log.md` を更新する

## 5. マイルストーン
- M1: T01-T03 完了（テンプレート整合と進捗ノイズ解消）
- M2: T04-T06 完了（クロスプラットフォーム安全ハーネス + verify導線）
- M3: T07-T08 完了（軽量モード導入と運用ドキュメント整備）

## 6. リスクと対策
- リスク:
  - L2/L3変更で未承認実装が混入するリスク。
  - bash版wrapperの仕様差により、PowerShell版との挙動不一致が発生するリスク。
  - `scripts/verify` が環境差で誤失敗するリスク。
- 対策:
  - Gate-Aで承認取得を必須化し、未承認時はL1作業のみ実施する。
  - allow/prompt/forbidden の共通テストケースを先に固定してから実装する。
  - `scripts/verify` は存在チェック付き fail-soft 実行とし、未導入ツールはSKIP扱いで記録する。

## 7. 検証方法
- 実施する確認:
  - `codex execpolicy check --rules .codex/rules/10-readonly-allow.rules --rules .codex/rules/20-risky-prompt.rules --rules .codex/rules/30-destructive-forbidden.rules -- git status` が `allow` を返す
  - `codex execpolicy check --rules .codex/rules/10-readonly-allow.rules --rules .codex/rules/20-risky-prompt.rules --rules .codex/rules/30-destructive-forbidden.rules -- git add .` が `prompt` を返す
  - `codex execpolicy check --rules .codex/rules/10-readonly-allow.rules --rules .codex/rules/20-risky-prompt.rules --rules .codex/rules/30-destructive-forbidden.rules -- git reset --hard HEAD~1` が `forbidden` を返す
  - `powershell.exe -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly` が成功する
  - `bash scripts/codex-safe.sh --preflight-only` が成功する
  - `bash scripts/verify` で利用可能チェックの結果と終了コードが記録される
- 成功判定:
  - 監査レポートの部分適合4項目に対して、再評価根拠を `docs/reports/2026-02-27_partial-compliance-remediation-log.md` へ追記できること

## 7.1 再評価判定マトリクス（部分適合 -> 適合）
- 不確実性対応:
  - 判定条件: `.codex/templates/REPORT.md` に `Open Issues` / `Next Action` が初期定義され、run作成直後に記録可能。
  - 証跡: テンプレート差分 + 検証runの `REPORT.md` 初期内容。
- 安全制約:
  - 判定条件: PowerShell版とbash版で危険引数拒否の共通ケースが PASS。
  - 証跡: 両wrapperのスモークテスト結果ログ。
- 品質ゲート:
  - 判定条件: `scripts/verify` 単独で利用可能チェックを実行し、PASS/FAIL/SKIPが出力される。
  - 証跡: `scripts/verify` 実行ログと終了コード。
- 汎用性:
  - 判定条件: `AGENTS.md` 軽量モード定義により、小規模タスクでの必須手順が明文化される。
  - 証跡: `AGENTS.md` 差分 + `docs/PROJECT_CONTEXT.md` 更新記録。

## 8. 成果物
- 変更ファイル:
  - `.codex/templates/REPORT.md`
  - `.codex/templates/TASKS.md`
  - `scripts/codex-safe.sh`（新規）
  - `scripts/verify`（新規）
  - `AGENTS.md`
  - `docs/PROJECT_CONTEXT.md`
  - `docs/agent/codex-safety-harness.md`
- 付随ドキュメント:
  - `docs/reports/2026-02-27_partial-compliance-remediation-log.md`

## 9. ロールバック方針
- 変更前に対象ファイルの差分を記録し、run `REPORT.md` に保存する。
- 不具合時は、影響範囲の小さい単位で逆パッチを適用し、wrapper変更とテンプレート変更を分離して戻す。
- L2/L3変更のロールバック実施時は、原因・再発防止策・未解決論点を `REPORT.md` に追記する。

## 10. 備考
- 実装順は P0 -> P1 -> P2 を厳守する。
- L2/L3変更は承認取得まで実装禁止とする。
- 既存 `scripts/codex-safe.ps1` は温存し、bash版を追加提供する。
