# PROJECT_CONTEXT update: observation-subagent-baseline

更新日時: 2026-06-27 23:15:30 JST

## Summary

- consumer-facing template に observation baseline と subagent run baseline の schema / docs / optional hook / tests が追加された。
- hook observation JSONL と subagent run record は evidence artifact であり、`evaluation.json` の source-of-truth 位置は変わらないことを明記した。
- observation / subagent baseline の検証経路として `tools/validate-spec.*`、`template/scripts/verify`、`tests/integration/test-observation-baseline.*` を PROJECT_CONTEXT に追記した。
