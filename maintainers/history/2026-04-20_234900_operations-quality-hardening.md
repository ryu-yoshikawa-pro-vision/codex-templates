# PROJECT_CONTEXT Update: operations quality hardening

## Summary
- `reports/` の生成条件を durable な調査・監査・検証結果に限定した。
- `codex-safe.*` / `codex-task.*` の run-first 出力方針を明記した。
- command-based deletion 禁止と `apply_patch` 許可の境界を source repo context に追加した。
- `template/.codex/config.toml` の safe baseline と `codex-project.toml` / `init-project.*` の存在を反映した。

## Notes
- review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録では `maintainers/reports/` / `docs/reports/` に report file を作らない。
- tracked runtime artifact の配布除外は index-only migration として扱い、物理ファイルは削除しない。

## 2026-04-22 Addendum
- Plan Mode の ambiguity handling を source / consumer の `PLANS.md`、planning workflow reference、plan templates、spec / validation に追加した。
- AI が判断し切れない不透明点を推測で埋めず、目的・成功条件・非目標・スコープ・DoD・検証方法・破壊的変更・移行・削除・セキュリティ・外部連携・費用・運用負荷・ユーザー優先順位に影響する曖昧さを必ず質問する方針を明記した。
