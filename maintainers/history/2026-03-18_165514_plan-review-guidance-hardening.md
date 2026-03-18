# PROJECT_CONTEXT 更新履歴

## 2026-03-18 16:55:14 (JST)
- root `PLANS.md` と `CODE_REVIEW.md` を source repo 用 contract として強化し、source/consumer 境界、validation、rollback、finding format を明示する方針を追記した。
- consumer-facing `template/PLANS.md` と `template/CODE_REVIEW.md` は mode 入口を保ちつつ required output format を持つ構成へ更新した。
- consumer-facing planning/review workflow は 2 skills を維持し、reference で `repo mapping -> change planning` と `diff triage -> deep review` を扱う前提を記録した。
- template contract の検証は `spec/`、`template/scripts/verify*`、`tests/smoke/*` の三層で行う運用に更新した。

## 2026-03-18 17:18:00 (JST)
- planning/review reference に `使う場面 / 使わない場面`、出力セクション、観点チェック、failure modes を追加し、inputs 例に近い具体度へ拡張した。
- `SKILL.md` は薄いまま維持し、具体的 workflow は reference で担保する方針を明文化した。
- spec / verify / smoke も追加セクションを確認するよう更新し、reference の具体度低下を検知できるようにした。
