# ADR 0002: 自律調査ループと自己改善ガバナンスの導入

## Status
- Accepted

## Context
- 従来運用では PLAN/TASKS/REPORT は存在するが、Web調査ラウンドと仮説更新の標準手順が不足していた。
- スキル探索導入と自己改善提案の承認境界が曖昧で、過剰自動化リスクがあった。

## Decision
- 標準実行プロトコルを `PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` に統一する。
- `.codex/templates/{PLAN,TASKS,REPORT}.md` に仮説・検索ラウンド・証跡記録欄を追加する。
- 役割別エージェント（Planner/Researcher/Executor/Reviewer）の設計とテンプレートを `docs/agent/` 配下に導入する。
- 改善提案に対して L1/L2/L3 の承認境界とロールバック方針を定義する。
- スキル探索・導入は `skill-installer` と `docs/agent/skill-discovery-workflow.md` を標準手順とする。

## Consequences
- 調査と実行のトレーサビリティが向上し、再現性の高い運用が可能になる。
- 運用ドキュメントとログ記述が増え、初期実行コストは上がる。
- L2/L3変更でユーザー承認が必須になり、変更速度より安全性を優先する。
