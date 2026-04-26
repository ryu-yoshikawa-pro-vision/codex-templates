# Migration Notes

## auto-net preset
This template keeps the project-level default conservative. Existing users should not see `approval_policy = "never"` or workspace network access unless they explicitly use the managed `auto-net` preset.

To adopt the new mode:

1. Copy `.codex/config.toml`, `.codex/rules-auto-net/`, and `.codex/hooks/` from the updated template.
2. Update `scripts/codex-safe.*` and `scripts/codex-task.*` together; the preset and preflight behavior is shared.
3. Keep `.codex/rules/20-risky-prompt.rules` as the safe-mode prompt rule set.
4. Use `--preset auto-net` only when autonomous workspace work with network access is required.

Do not migrate by enabling `danger-full-access`, raw `--full-auto`, or `--dangerously-bypass-approvals-and-sandbox`.

## Deletion policy
Codex must not delete files or directories in this template. When cleanup is needed, add candidates to `.codex/runs/<run_id>/REPORT.md` under `Deletion candidates` and let the user delete them after review.

## Verification
After migration, run:

```bash
bash scripts/verify
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```
