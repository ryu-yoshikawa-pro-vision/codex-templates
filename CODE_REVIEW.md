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
