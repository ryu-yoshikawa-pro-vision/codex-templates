# 追加運用指示（自律調査ループ）

## 適用目的
- 依頼に不確実性がある場合、`PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` を強制的に通す。

## 実行ルール
1. PLAN で仮説（H1..）と終了条件を明示する。
2. Web検索はラウンド制で行い、各ラウンドで証跡（採否理由・信頼度）を残す。
3. 調査結果は TASKS に具体タスクとして反映する。
4. 実行中の判断はすべて REPORT に追記する。
5. 未解決論点は `Next Action` 付きで残す。

## 役割テンプレート
- Planner: `docs/agent/templates/planner-template.md`
- Researcher: `docs/agent/templates/researcher-template.md`
- Executor: `docs/agent/templates/executor-template.md`
- Reviewer: `docs/agent/templates/reviewer-template.md`
- Improvement Proposal: `docs/agent/templates/improvement-proposal-template.md`

## 改善提案の安全条件
- L1: 自己承認可（ログ必須）
- L2/L3: ユーザー承認が出るまで実行しない
- すべての提案にロールバック方針を事前定義する
