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

## Ambiguity handling
- Contract marker: `mandatory-question`
- Plan Mode では、AI が判断し切れない不透明点を推測で埋めてはいけない。
- 目的、成功条件、非目標、変更スコープ、対象ユーザー、DoD、検証方法、完了判定が曖昧な場合は必ず質問する。
- 破壊的変更、移行、削除、セキュリティ、外部連携、費用、運用負荷に影響する不透明点は必ず質問する。
- ユーザーの好みや優先順位で結論が変わる場合は必ず質問する。
- 既存 repo の明確な convention に従える局所実装、後から容易に修正できる細部、成果物の方向性を変えない安全側 default は、仮定として記録してよい。
- 質問は重要度順にまとめ、なぜ必要かと回答により何が変わるかを添える。
- 未回答の重要質問が残る場合、実装には進まず `Open questions` に残す。ユーザーが「仮定して進めてよい」と明示した場合のみ、仮定を計画に記録して進める。

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
