# Codex自律運用 実装ログ（2026-02-27）

## 0. 目的
- 計画書 `docs/plans/2026-02-27_codex-autonomy-research-loop-plan.md` に基づき、実装と検証の証跡を一元記録する。

## 1. 現状分析（D4）
### 1.1 観測対象
- `AGENTS.md`
- `.codex/templates/PLAN.md`
- `.codex/templates/TASKS.md`
- `.codex/templates/REPORT.md`
- `docs/PROJECT_CONTEXT.md`

### 1.2 現状
- PLAN/TASKS/REPORT の運用規律（run初期化、進捗計算、ログ追記）は定義済み。
- 安全運用（`execpolicy` + wrapper）関連の手順は存在。
- 一方で、反復Web調査の進め方（検索ラウンド、仮説更新、終了条件）がテンプレート化されていない。
- 改善提案の承認/差し戻し/ロールバックの運用ルールが `AGENTS.md` に明示されていない。
- 用途別エージェント（Planner/Researcher/Executor/Reviewer）の入力・出力仕様が未定義。

### 1.3 ギャップ
- G1: 検索ログと仮説評価ログの標準フォーマットがない。
- G2: `PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` の状態遷移がテンプレートに反映されていない。
- G3: 自己改善提案のガードレール（承認境界・差し戻し条件）が未整備。
- G4: スキル探索・導入の実行手順（`skill-installer` 活用）が運用文書に未統合。
- G5: 役割別エージェントの思考テンプレートが未提供。

## 2. 仮説・検証ログ
### 2.1 仮説（H1-H5）
- H1: `AGENTS.md` に「検索ラウンド運用」と「終了条件」を明示すれば、Web調査の抜け漏れが減る。
  - 検証観点: 1つの依頼で Round1/2 の検索ログと採否理由が REPORT に残るか。
- H2: 役割別エージェント（Planner/Researcher/Executor/Reviewer）を定義すれば、PLAN/TASKS/REPORT の責務分離が明確になる。
  - 検証観点: 役割ごとの入力/出力テンプレートが存在し、パイロットで再利用できるか。
- H3: `skill-installer` を運用フローへ統合すれば、必要スキルの探索と導入判断を標準化できる。
  - 検証観点: スキル候補の列挙コマンド、採用基準、導入判断ログが残るか。
- H4: 改善提案ガードレール（承認/差し戻し/ロールバック）を明記すれば、過剰自動化リスクを抑えられる。
  - 検証観点: パイロットで提案1件以上に対し採用可否と理由が記録されるか。
- H5: PLAN/TASKS/REPORT テンプレートに仮説・証跡欄を追加すれば、思考と実行のトレーサビリティが上がる。
  - 検証観点: 新規runでテンプレート項目のみで実行ログが閉じるか。

### 2.2 証跡フォーマット（検索/仮説評価共通）
- Record ID: `EVID-YYYYMMDD-<seq>`
- Round: `R1` / `R2` / `R3...`
- Query: 実行検索クエリ
- Source: URL（一次情報を優先）
- Collected At: JST timestamp
- Claim: 取得した事実（要約）
- Supports / Refutes: 対象仮説ID（H1-H5）
- Confidence: `High` / `Medium` / `Low`
- Decision: `Adopt` / `Hold` / `Reject`
- Rationale: 採否理由
- Open Issues: 未解決論点
- Next Action: 次の検索または実装タスク

## 3. Web調査ログ
### 3.1 Round 1（D6）
#### クエリ
- Q1: `site:developers.openai.com codex AGENTS.md`
- Q2: `site:developers.openai.com codex skills`
- Q3: `site:developers.openai.com codex multi-agent`
- Q4: `site:developers.openai.com codex config reference approval_policy sandbox_mode`
- Q5: `site:developers.openai.com codex security sandbox and approvals`

#### エビデンス
- EVID-20260227-001
  - Round: R1
  - Source: https://developers.openai.com/codex/guides/agents-md
  - Claim: Codex は instruction chain を構築し、global -> project path の順で `AGENTS.override.md` / `AGENTS.md` を読み、近い階層ほど後勝ちで上書きされる。
  - Supports / Refutes: Supports H1
  - Confidence: High
  - Decision: Adopt
  - Rationale: 既存運用の「overridesファイル任意読込」方針と整合。
- EVID-20260227-002
  - Round: R1
  - Source: https://developers.openai.com/codex/skills
  - Claim: Skill は `SKILL.md` 必須、metadata 先読みの progressive disclosure、explicit/implicit の2起動方式。
  - Supports / Refutes: Supports H2, H3
  - Confidence: High
  - Decision: Adopt
  - Rationale: スキル探索導入をテンプレート化する根拠になる。
- EVID-20260227-003
  - Round: R1
  - Source: https://developers.openai.com/codex/multi-agent
  - Claim: multi-agent は実験機能。専門化エージェントを並列起動し、統合応答を返せる。
  - Supports / Refutes: Supports H2
  - Confidence: Medium
  - Decision: Hold
  - Rationale: 本実装では機能を必須化せず、役割設計のみ採用する方が安全。
- EVID-20260227-004
  - Round: R1
  - Source: https://developers.openai.com/codex/config-basic
  - Claim: `approval_policy` と `sandbox_mode` が主要設定で、`on-request`/`workspace-write` が代表例として提示される。
  - Supports / Refutes: Supports H4
  - Confidence: High
  - Decision: Adopt
  - Rationale: 改善提案ガードレールの承認境界定義に直結。
- EVID-20260227-005
  - Round: R1
  - Source: https://developers.openai.com/codex/config-reference
  - Claim: project-scoped `.codex/config.toml` は trust 状態でのみ読み込まれ、`project_doc_fallback_filenames` 等で instruction discovery を拡張できる。
  - Supports / Refutes: Supports H1, H5
  - Confidence: High
  - Decision: Adopt
  - Rationale: `docs/agent/overrides.md` の読み込み運用を補強できる。
- EVID-20260227-006
  - Round: R1
  - Source: https://developers.openai.com/codex/security
  - Claim: 既定はネットワーク無効。sandbox mode と approval policy の2層で制御し、web search は cached/live/disabled を選べる。
  - Supports / Refutes: Supports H4
  - Confidence: High
  - Decision: Adopt
  - Rationale: 「Web検索を使うが無制限実行はしない」運用要件に一致。

### 3.2 Round 1 レビュー（D7）
#### 未解決論点
- OI-1: 長時間タスク向けに「計画文書を生きた設計書として更新する」実践パターンを補強したい。
- OI-2: `skill-installer` の導入手順と `.system` / curated / experimental の扱いを一次情報で固定したい。
- OI-3: 検索モード（cached vs live）の運用基準を具体化したい。

#### 追加クエリ
- Q6: `site:cookbook.openai.com codex exec plans`
- Q7: `site:github.com/openai/skills Installing a skill`
- Q8: `site:developers.openai.com codex config-reference web_search cached live`

### 3.3 Round 2（D8）
#### エビデンス
- EVID-20260227-007
  - Round: R2
  - Source: https://github.com/openai/skills
  - Claim: `.system` skills は最新 Codex で自動導入され、curated/experimental は `$skill-installer` で導入し、導入後は再起動が必要。
  - Supports / Refutes: Supports H3
  - Confidence: High
  - Decision: Adopt
  - Rationale: 「スキルを見つけるスキル」導入の実運用手順を確定できる。
- EVID-20260227-008
  - Round: R2
  - Source: https://cookbook.openai.com/articles/codex_exec_plans/
  - Claim: 長時間タスクでは計画文書（PLANS/ExecPlan）を living document として運用し、意思決定と検証証跡を継続更新することが有効。
  - Supports / Refutes: Supports H1, H5
  - Confidence: Medium
  - Decision: Adopt
  - Rationale: 本リポジトリの PLAN/TASKS/REPORT 運用と親和性が高い。
- EVID-20260227-009
  - Round: R2
  - Source: https://developers.openai.com/codex/config-reference
  - Claim: `web_search` は `disabled | cached | live` を選択可能で、既定は cached。full access 系では live が既定化される条件がある。
  - Supports / Refutes: Supports H4
  - Confidence: High
  - Decision: Adopt
  - Rationale: 検索モード運用基準（通常 cached、必要時のみ live）をルール化できる。

#### 終了条件チェック
- 主要仮説 H1-H5 について支持エビデンスを最低1件確保: 達成。
- 未解決論点 OI-1〜OI-3 の次アクション定義: 達成（D9-D13で実装反映）。

## 4. 設計・実装ログ
### 4.1 D9 スキル探索・導入設計
- 実施:
  - `skill-installer` の標準スクリプトで curated 一覧を取得。
  - `openai-docs` を導入（`install-skill-from-github.py`）。
  - `docs/agent/skill-discovery-workflow.md` を作成し、運用手順を文書化。
- 結果:
  - `openai-docs` は `installed: true` を確認。
  - 「候補列挙 -> 評価 -> 導入 -> 再起動確認」を定義し、H3を支持。

### 4.2 D10 役割別エージェントと思考テンプレート
- 実施:
  - `docs/agent/agent-role-design.md` を新規作成。
  - Planner / Researcher / Executor / Reviewer の責務・入出力・終了条件を定義。
  - `docs/agent/templates/*.md` に役割別テンプレートを追加。
- 結果:
  - H2（責務分離）を実装レベルで反映。
  - 依頼ごとの再利用テンプレートを提供し、運用の再現性を強化。

### 4.3 D11 実行プロトコルのテンプレート反映
- 実施:
  - `.codex/templates/PLAN.md` に `Hypotheses` / `Research Plan` / 標準フローを追加。
  - `.codex/templates/TASKS.md` をプロトコル前提の初期5タスクへ更新。
  - `.codex/templates/REPORT.md` に Evidence Record セクションを追加。
- 結果:
  - H1/H5をテンプレートレベルで実装。
  - 新規run開始時から検索ラウンドと仮説検証が運用に組み込まれる。

### 4.4 D12 改善提案ガードレール
- 実施:
  - `docs/agent/improvement-guardrails.md` を追加。
  - 提案トリガー（T1-T4）、リスク区分（L1-L3）、承認境界、差し戻し条件、ロールバック方針を定義。
  - `docs/agent/templates/improvement-proposal-template.md` を追加。
- 結果:
  - H4（改善提案の安全運用）を実装。
  - 提案ごとの承認ログを標準化できる状態になった。

### 4.5 D13 AGENTS・関連文書改訂
- 実施:
  - `AGENTS.md` に「Autonomous research loop」「Skills and self-improvement governance」を追加。
  - `docs/agent/overrides.md` を新規作成（追加運用指示）。
  - `docs/PROJECT_CONTEXT.md` に自律運用プロトコルと新規ドキュメント構成を追記。
- 結果:
  - H1/H3/H4/H5 を運用ルールへ反映。
  - 次回セッションから overrides 読込による運用拡張が有効化される。

### 4.6 D17 改善提案採用可否ログ（実データ）
- 実施:
  - `docs/reports/2026-02-27_improvement-proposal-log.md` を新規作成。
  - Proposal ID / Trigger / Risk / Approval / Scope / Rollback / Result を実データで記録。
- 結果:
  - DoD要件「採用可否判断（承認者・理由・影響範囲・ロールバック方針）の記録」を充足。
  - H4を実運用ログとして裏付け。

## 5. パイロット検証ログ
### Cycle 1: 調査駆動テンプレート反映
- 結果: PASS
- 根拠:
  - Round1/2 調査ログと仮説更新を実施済み。
  - `.codex/templates` に仮説・検索ラウンド・証跡欄を追加済み。

### Cycle 2: スキル導入 + 改善提案ガードレール
- 結果: PASS
- 根拠:
  - `openai-docs` 導入確認（installed true）。
  - `AGENTS.md` と `docs/agent/improvement-guardrails.md` で承認境界とロールバック方針を定義済み。

### 検証レポート
- `docs/reports/2026-02-27_autonomy-pilot-validation.md`

## 6. 結論
- 実装結果:
  - D4-D14 を完了し、計画書で定義した実装項目（調査ループ、スキル探索、役割設計、プロトコル、ガードレール、パイロット）を反映した。
  - 重要判断を ADR `docs/adr/0002-autonomous-research-loop-and-governance.md` として記録した。
- 仮説判定:
  - H1: 支持
  - H2: 支持
  - H3: 支持
  - H4: 支持
  - H5: 支持
- 品質確認:
  - `git diff --check` で問題なし。
  - formatter/lint/typecheck/build/test の設定ファイルは確認できず（該当なし）。
- 残課題:
  - `openai-docs` 導入後の再起動反映確認は次回セッションで継続確認する。
