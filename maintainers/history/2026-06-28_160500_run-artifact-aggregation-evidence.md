# PROJECT_CONTEXT 更新履歴

## 2026-06-28 16:05 JST

- `run.json` が `collect-run-artifacts.*` により report / hook / subagent / evaluation summary を集約する前提へ更新した。
- hook observation JSONL と `subagent-run.json` は引き続き evidence artifact であり、source of truth は `evaluation.json` のまま維持することを明文化した。
- `evaluation.schema.json` が optional `evidence_refs` を持ち、structured evidence 参照を扱える前提を追記した。
- run artifact aggregation 用 integration test の存在を PROJECT_CONTEXT に反映した。
