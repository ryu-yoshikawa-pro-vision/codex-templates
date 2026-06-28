# Plan: PR #22 follow-up hardening

## Goal
- PR #22 の review 指摘を踏まえ、run artifact aggregation と evaluation evidence の契約不足を埋める。

## In scope
- `codex-task.ps1` の collector 必須化と `python3` 検出
- `collect-run-artifacts.py|ps1` の path / Python parity 修正
- `run-manifest.schema.json` の subagent enum 厳格化
- `evaluation.schema.json` の `$defs.evidence_ref` 集約
- `validate-output-schema.py` の `$defs` / `$ref` 対応
- Bash / PowerShell validator, verify, integration test parity 改善
- 必要なら ADR / PROJECT_CONTEXT / history 更新

## Non-goals
- schema_version 2 への移行
- repair loop 自動化
- SDK runner 実装
- subagent surface 拡張

## Validation plan
- `bash tools/validate-spec.sh`
- `powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
- `bash template/scripts/verify`
- `powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
- `bash tests/integration/test-new-run.sh`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-NewRun.ps1`
- `bash tests/integration/test-run-artifact-aggregation.sh`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-RunArtifactAggregation.ps1`
- `bash tests/integration/test-codex-task-harness.sh`
- `powershell -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`

## Notes
- `gh` CLI がこの環境にないため、thread-aware な GitHub review state は直接確認できない。添付修正指示を一次情報として扱い、public PR metadata との差分だけ後で明示する。
