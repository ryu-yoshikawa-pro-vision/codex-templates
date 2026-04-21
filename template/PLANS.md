# Planning Entry Point

## 適用条件
- 複雑な依頼
- 複数ファイルや複数段階にまたがる依頼
- 要件が曖昧な依頼
- 副作用境界、公開インターフェース、移行、検証方針の整理が必要な依頼
- ユーザーが明示的に計画作成を求めた依頼
- Plan Mode で扱う依頼

## 使い方
1. `AGENTS.md` を確認する。
2. `.agents/skills/feature-plan/SKILL.md` を読む。
3. 必要に応じて `.agents/skills/feature-plan/references/planning-workflow.md` を読む。
4. 実装へ進む前に、合意した計画を `docs/plans/TEMPLATE.md` ベースで `docs/plans/` に保存する。

## Planning rules
- 既存 code / test / config / docs を読む前に設計を確定しない。
- `Current understanding` には確認できた事実だけを書く。
- `Assumptions` には崩れたら計画を見直す前提だけを書く。
- `Non-goals` を明示し、ついでの改善を混ぜない。
- `Validation plan` が書けない変更は完成した計画とみなさない。
- 保存用計画書は `docs/plans/TEMPLATE.md` に落とし込む。

## Ambiguity handling
- Contract marker: `mandatory-question`
- Plan Mode では、AI が判断し切れない不透明点を推測で埋めてはいけない。
- 目的、成功条件、非目標、変更スコープ、対象ユーザー、DoD、検証方法、完了判定が曖昧な場合は必ず質問する。
- 破壊的変更、移行、削除、セキュリティ、外部連携、費用、運用負荷に影響する不透明点は必ず質問する。
- ユーザーの好みや優先順位で結論が変わる場合は必ず質問する。
- 既存 repo の明確な convention に従える局所実装、後から容易に修正できる細部、成果物の方向性を変えない安全側 default は、仮定として記録してよい。
- 質問は重要度順にまとめ、なぜ必要かと回答により何が変わるかを添える。
- 未回答の重要質問が残る場合、実装には進まず `Open questions` に残す。ユーザーが「仮定して進めてよい」と明示した場合のみ、仮定を計画に記録して進める。

## Required plan output format
1. Goal
2. Current understanding
3. Assumptions
4. Non-goals
5. Impacted areas
6. Files to inspect
7. Change strategy
8. Validation plan
9. Risks
10. Open questions
