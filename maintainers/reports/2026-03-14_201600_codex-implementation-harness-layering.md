# Codex 実装ハーネス多層化 実装ログ

## Summary
- `codex-safe` / `codex-task` / `codex-sandbox` の 3 層ハーネスを consumer-facing template に追加した。
- `codex-task` に output file、schema validate、verify、report JSON を追加した。
- spec、docs、tests、ADR、PROJECT_CONTEXT history を新契約へ追従させた。

## Main Changes
- wrapper:
  - `template/scripts/codex-task.ps1|sh`
  - `template/scripts/codex-sandbox.ps1|sh`
  - `template/scripts/validate-output-schema.py`
- docs / contract:
  - `template/docs/reference/codex-implementation-harness.md`
  - `template/AGENTS.md`
  - `spec/routing.yaml`
  - `spec/workflow.yaml`
  - `spec/safety-policy.yaml`
- tests:
  - `tests/integration/Test-CodexTaskHarness.ps1`
  - `tests/integration/test-codex-task-harness.sh`
  - `tests/fixtures/fake-codex.*`
  - `tests/fixtures/fake-docker.*`

## Validation
- Success:
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-SyncTemplate.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`
- Environment-limited:
  - `bash tools/validate-spec.sh`
  - `bash template/scripts/verify`
  - `bash tests/integration/test-codex-safety-harness.sh`
  - `bash tests/integration/test-codex-task-harness.sh`
  - すべて `Bash/WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED` により未実行

## Notes
- Docker runtime は `CODEX_DOCKER_IMAGE` 必須の opt-in experimental path。
- `codex-task` の report JSON は `runtime`, `preset`, `prompt_source`, `output_file`, `output_schema`, `log_path`, `codex_exit_code`, `verify_exit_code`, `status` を必須キーとする。
