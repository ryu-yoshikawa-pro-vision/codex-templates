# PROJECT_CONTEXT 更新履歴

## 2026-03-14 16:22:10 (JST)
- `PLANS.md` を計画系の入口として追加し、複雑タスクや Plan Mode で参照する構成に更新した。
- `CODE_REVIEW.md` をレビュー系の入口として追加し、review 要求や `/review` の参照先を明確化した。
- `docs/agent/` は正本のまま維持し、repo ローカルの反復ワークフローは `.agents/skills/` に分離する三層構成を追記した。

## 2026-03-14 16:36:31 (JST)
- Plan Mode やチャットで合意した計画から実装へ移る場合、先に `docs/plans/` へ計画を保存する handoff ルールを追加した。
- `AGENTS.md`、`PLANS.md`、`docs/agent/overrides.md`、planning skill に同ルールを追記した。
- 今回の mode 入口構成の計画内容を `docs/plans/2026-03-14_163631_plan-review-routing.md` として保存した。

## 2026-03-14 17:08:04 (JST)
- review 系入口の命名を `CODE_REVIEW.md` に統一し、関連参照と検証ログの表記を更新した。
