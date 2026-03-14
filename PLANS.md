# Planning Entry Point for the Source Repository

## 適用条件
- source repo の構造変更
- consumer-facing 契約変更
- spec / validation / migration に影響する変更
- ユーザーが計画作成を明示した依頼

## 必須動作
1. source repo 変更と consumer-facing 変更を分けて書く。
2. `spec/` 変更の有無を最初に明示する。
3. 変更対象、検証方法、移行影響を具体化する。
4. 実装前に `maintainers/plans/` へ計画を保存する。

## 参照先
- planning skill: `template/.agents/skills/feature-plan/SKILL.md`
- planning reference: `template/.agents/skills/feature-plan/references/planning-workflow.md`
- source-repo plan storage: `maintainers/plans/`

## 最低限含める内容
- Objective / Scope / DoD
- spec 影響
- consumer-facing 影響
- validation 手順
- migration / rollback 観点
