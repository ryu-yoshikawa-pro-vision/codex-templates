---
name: feature-plan
description: Use when a task needs planning, an explicit plan, or Plan Mode in this repository.
---

1. `AGENTS.md` と `PLANS.md` を読む。
2. `references/planning-workflow.md` を読み、必須項目と判断順を固定する。
3. まず repo mapping を行い、entry points、existing tests、safe change surface、unknowns を確認する。
4. 次に change planning を行い、Goal、Assumptions、Non-goals、Validation plan、Open questions を整理する。
5. 純粋ロジックと副作用境界、consumer-facing 変更と内部変更を分けて計画する。
6. 実装者が追加判断なしで進められる粒度まで、変更対象・検証方法・移行影響を具体化する。
7. 実装へ進む前に、合意した計画を `docs/plans/TEMPLATE.md` ベースで `docs/plans/` に保存する。
