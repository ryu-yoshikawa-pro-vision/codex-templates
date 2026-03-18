# Planning Entry Point for the Source Repository

## 適用条件
- source repo の構造変更
- consumer-facing 契約変更
- spec / validation / migration に影響する変更
- ユーザーが計画作成を明示した依頼
- Plan Mode で扱う source-repo タスク

## 必須動作
1. source repo 変更と consumer-facing 変更を分けて書く。
2. `spec/` 変更の有無を最初に明示する。
3. 事実として確認できた内容と仮定を分けて書く。
4. 変更対象、検証方法、移行影響、rollback 観点を具体化する。
5. 実装者が追加判断なしで進められる粒度まで決め切る。
6. 実装前に `maintainers/plans/` へ計画を保存する。

## 参照先
- planning skill: `template/.agents/skills/feature-plan/SKILL.md`
- planning reference: `template/.agents/skills/feature-plan/references/planning-workflow.md`
- source-repo plan storage: `maintainers/plans/`

## 計画ルール
- 実装案を決める前に、関連する code / test / config / spec を確認する。
- source repo 側の変更と consumer-facing 側の変更を混ぜて書かない。
- spec 変更と wording-only 修正を同列に扱わない。
- 仕様変更とリファクタリングは別タスクとして分離する。
- validation plan が書けない変更は計画不足とみなす。

## 必須出力
1. `spec/` 影響の有無
2. Goal
3. Current understanding
4. Assumptions
5. Source-repo changes
6. Consumer-facing changes
7. Validation plan
8. Migration / rollback
9. Risks / open issues
10. 保存先となる `maintainers/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md`
