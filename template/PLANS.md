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
