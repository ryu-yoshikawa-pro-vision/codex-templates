# Review Entry Point for the Source Repository

## 適用条件
- source repo の差分レビュー
- `/review`
- spec と consumer-facing template の整合確認

## 必須動作
1. findings first で返す。
2. severity 順に列挙する。
3. `spec/`、`template/`、`maintainers/` のどの境界を壊しているかを明示する。
4. 懸念がなければ、その旨と残余リスクを明記する。

## 参照先
- review skill: `template/.agents/skills/code-review/SKILL.md`
- review reference: `template/.agents/skills/code-review/references/review-workflow.md`

## 最低限含める内容
- 契約破壊、移行漏れ、検証不足
- 根拠となるファイル参照
- 残余リスク
