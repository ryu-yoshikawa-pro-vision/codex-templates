# Contributing

Thank you for considering contributing to `codex-templates`.

## Before starting

For significant changes, open an issue or discussion first to confirm the direction. This avoids wasted effort and ensures alignment with the project's goals.

## Pull request scope

- Keep each PR focused on a single concern. Do not mix unrelated changes.
- If a change touches both source repository structure and consumer-facing files, explain the relationship in the PR description.
- Runtime behavior changes (wrapper, execpolicy, hooks, validators) must be explicitly stated in the PR scope and justified.

## Validation

Run the following before submitting a PR:

```bash
bash tools/validate-spec.sh
bash template/scripts/verify --strict-harness
```

PowerShell (if available):

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness
```

If a validation command cannot run, explain why in the PR description.

## Consumer-facing changes

- Consumer-facing changes must keep `template/` and `spec/` in sync.
- Update `spec/` first when changing behavior contracts, then verify with `tools/validate-spec.*`.
- Do not make wrapper or execpolicy behavior changes without explicit scope in the PR.

## Secrets and sensitive data

- Do not include secrets, tokens, API keys, passwords, or credentials in issues, PRs, or logs.
- Redact any sensitive information before pasting logs or configuration snippets.
- If you suspect a security issue, follow [SECURITY.md](SECURITY.md) instead of filing a public issue.

## Code of conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold its standards.
