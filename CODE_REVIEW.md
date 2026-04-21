# Review Entry Point for the Source Repository

## 適用条件
- source repo の差分レビュー
- `/review`
- spec と consumer-facing template の整合確認

## 必須動作
1. findings first で返す。
2. severity 順に列挙する。
3. `spec/`、`template/`、`maintainers/` のどの境界を壊しているかを明示する。
4. 差分起因でない既存問題や好みは finding に含めない。
5. 懸念がなければ、その旨と残余リスクを明記する。
6. レビュー結果は原則チャット返答のみとし、明示的な調査・保存依頼がない限り `maintainers/reports/` に report file を作らない。

## 参照先
- review skill: `template/.agents/skills/code-review/SKILL.md`
- review reference: `template/.agents/skills/code-review/references/review-workflow.md`

## 優先観点
1. 契約破壊と boundary violation
2. 正常系 / 異常系の回帰
3. spec・template・maintainer 文書の不整合
4. validate / verify / smoke の不足
5. 不要な変更範囲の混入

## Finding 形式
- Severity
- Title
- Location
- Why it matters
- Evidence
- Suggested fix

## 最低限含める内容
- 契約破壊、移行漏れ、検証不足
- 根拠となるファイル参照
- Open questions
- Verdict と残余リスク

## Report file 生成ルール
- Allowed: ユーザーが「レポートとして保存」「調査レポートを作成」など保存を明示した場合、計画 DoD に report file が明記されている場合、複数ソース調査・監査・検証結果を後で参照する durable artifact として残す必要がある場合。
- Not allowed: review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価。
- 保存先: source repo 作業は `maintainers/reports/`、consumer repo 作業は `docs/reports/`。`.codex/runs/<run_id>/REPORT.md` は run-local log として別扱い。
- 判断に迷う場合は report file を作らず、チャット返答と run-local `REPORT.md` に留める。
