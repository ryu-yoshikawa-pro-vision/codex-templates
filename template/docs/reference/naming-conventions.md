# Naming Conventions

- run ID: `YYYYMMDD-HHMMSS-JST`
- 計画書: `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md`
- レポート: `docs/reports/{yyyy-mm-dd}_{HHMMSS}_{report_name}.md`
- PROJECT_CONTEXT 履歴: `docs/history/YYYY-MM-DD_HHMMSS_<summary>.md`
- run artifact: `.codex/runs/<run_id>/artifacts/`
- run report JSON: `.codex/runs/<run_id>/reports/`
- run log: `.codex/runs/<run_id>/logs/`

すべて JST (`Asia/Tokyo`) を使う。

`docs/reports/` は durable な調査・監査・検証結果だけに使う。review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価では report file を作らない。
