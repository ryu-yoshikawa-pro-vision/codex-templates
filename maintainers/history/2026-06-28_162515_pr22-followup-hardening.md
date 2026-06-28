# 2026-06-28 16:25 JST - PR #22 follow-up hardening

## Summary
- `evaluation.schema.json` の `evidence_refs` を `$defs.evidence_ref` に集約し、runtime validator も internal `$ref` を解決する契約へ更新した。
- `codex-task.ps1` は `--record-run-manifest` 時に collector 実行を必須化し、`python` / `python3` / `py` 探索へ揃えた。
- `collect-run-artifacts.py` は relative `--base-manifest` を repo root 基準で解決し、PowerShell/Bash integration test で固定した。
- `run-manifest.schema.json` の `subagents.records` enum を `subagent-run.schema.json` と同期し、validator / tests の粒度を揃えた。

## Files
- `spec/evaluation.schema.json`
- `spec/run-manifest.schema.json`
- `template/scripts/codex-task.ps1`
- `template/scripts/collect-run-artifacts.py`
- `tools/validate-spec.sh`
- `tools/validate-spec.ps1`
- `tests/integration/test-run-artifact-aggregation.sh`
- `tests/integration/Test-RunArtifactAggregation.ps1`
