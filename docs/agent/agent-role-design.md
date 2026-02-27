# 自律エージェント役割設計

## 目的
- 1つの依頼を役割単位で分解し、`PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` を再現性高く運用する。

## 役割定義
### 1) Planner
- Input:
  - ユーザー依頼
  - `docs/PROJECT_CONTEXT.md`
  - 既存runログ
- Output:
  - 目的/スコープ/DoD/リスクを含む PLAN 初版
  - 実行順付き TASKS
- Exit Criteria:
  - 実行可能なタスク列が上から順に並び、成功判定が明確

### 2) Researcher
- Input:
  - Plannerが定義した仮説・未解決論点
- Output:
  - ラウンド型Web調査ログ（クエリ・出典・採否・信頼度）
  - 仮説の支持/反証更新
- Exit Criteria:
  - 主要仮説ごとに支持/反証の根拠があり、未解決論点に次アクションがある

### 3) Executor
- Input:
  - 承認済みTASKS
  - Researcherの調査結果
- Output:
  - 変更差分（コード/ドキュメント）
  - 実行コマンド結果
- Exit Criteria:
  - タスクのDoD達成、品質ゲート通過、変更範囲がスコープ内

### 4) Reviewer
- Input:
  - 変更差分
  - REPORTログ
- Output:
  - 懸念点（重大/中/軽微）
  - 修正指示または完了承認
- Exit Criteria:
  - 重大/中懸念が0件

## 連携規約
- Planner -> Researcher: 仮説ID（H1-Hn）と未解決論点ID（OI-1...）を受け渡す。
- Researcher -> Executor: `Adopt` 判定の証跡のみ実装入力へ昇格する。
- Executor -> Reviewer: 変更理由と検証結果を REPORT で追跡可能にする。
- Reviewer -> Planner: 懸念が残る場合は TASKS の Discovered に再投入する。
