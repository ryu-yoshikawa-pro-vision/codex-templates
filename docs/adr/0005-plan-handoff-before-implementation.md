# ADR 0005: 実装前の計画書保存を必須化する

## Status
- Accepted

## Context
- Plan Mode やチャットで計画が合意されても、その内容が `docs/plans/` に保存されないまま実装へ進む可能性があった。
- 既存の `AGENTS.md` §9 は「ユーザーが計画作成を依頼した場合」のみ plan document 作成を要求しており、plan-to-implementation handoff を明示していなかった。

## Decision
- Plan Mode またはチャットで合意した計画から実装へ移る場合は、実装開始前に `docs/plans/` へ計画内容を保存する。
- 保存時は `AGENTS.md` §9 の命名規則と `docs/plans/TEMPLATE.md` を使う。
- この handoff ルールは `AGENTS.md`、`PLANS.md`、`docs/agent/overrides.md`、repo local planning skill に明記する。

## Consequences
- 実装前にユーザー合意済みの計画が `docs/plans/` に残り、後追い確認と再利用がしやすくなる。
- planning から implementation へ移るたびに plan document 作成コストが増える。
- `docs/plans/` と run の `PLAN.md` の内容差分を意識して保守する必要がある。
