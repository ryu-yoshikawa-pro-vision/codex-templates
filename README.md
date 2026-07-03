# codex-templates

Safety-first Codex repository template for planning, review, execution logs, and controlled agent workflows.

## Project summary

This repository provides a structured template and safety harness for running [Codex CLI](https://github.com/openai/codex) agents with controlled execution modes, defense-in-depth guardrails, and cross-platform support (Bash and PowerShell).

## What this repository provides

- A structured template for running [Codex CLI](https://github.com/openai/codex) agents with safety guardrails
- Wrappers (`codex-safe`, `codex-task`, `codex-sandbox`) for controlled execution modes
- Execpolicy rules for restricting dangerous operations
- Pre- and post-tool-use hooks for defense-in-depth
- Planning, review, and reporting workflow templates
- Cross-platform support (Bash and PowerShell)
- Validation scripts to verify template integrity

## Who should use this

- Developers using Codex CLI who want safety guardrails out of the box
- Teams standardizing agent workflows across repositories
- Anyone evaluating coding agent templates with safety constraints

## What this does not guarantee

- This is **not** a full sandbox or security boundary
- Hooks, wrappers, and execpolicy rules are **defense-in-depth**, not a complete protection layer
- Always review agent-generated changes before applying them
- You are responsible for your own repository's permissions, secrets, CI/CD, external communication, and billing risks

## Quickstart

The recommended way to use this template is to copy the contents of `template/` into your consumer repository:

```bash
# Copy template contents into your repo root
cp -r path/to/codex-templates/template/* your-repo/
cd your-repo

# Run validation
bash scripts/verify
# or on Windows:
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

After copying, set up your project context in `docs/PROJECT_CONTEXT.md` and point Codex CLI to `AGENTS.md`.

> **Note:** Fork this repository only if you plan to contribute changes back to the source. For consumer installation, copying `template/` is the intended path.

### Existing consumer repository

If you already have a Codex-enabled repository, see the [consumer update guide](template/docs/guides/consumer-update.md) for safe migration steps.

## Repository layout

| Path | Purpose |
| --- | --- |
| `template/` | Consumer-facing distribution surface — copy this into your repo |
| `maintainers/` | Source repository maintenance context, ADRs, plans, reports |
| `spec/` | Single source of truth for template behavior contracts |
| `tools/` | Maintainer helper scripts (sync-template, validate-spec) |
| `tests/` | Integration and smoke tests for the source repository |
| `examples/` | Sample runs and reference consumer repository layouts |
| `docs/` | Additional documentation |
| `inputs/` | Planning and research input documents |

## Execution modes

The wrapper (`codex-safe` / `codex-task`) supports three presets:

### `safe` (default)
- Approval required for workspace writes
- Network disabled
- Restricted command set
- Use for: general development, file editing, code review

### `readonly`
- No workspace writes allowed
- Network disabled
- Use for: code review, research, investigation

### `auto-net`
- Network enabled
- Approval never (unattended)
- Restricted command set (no delete, no git mutation)
- Use only when explicitly specified for dependency resolution or external API calls

Do not use `danger-full-access`, raw `--full-auto`, or `--dangerously-bypass-approvals-and-sandbox` in normal operation.

## New repository vs existing consumer repository

- **New repository**: Copy `template/` contents into the root, run `scripts/init-project.*`, update `docs/PROJECT_CONTEXT.md`, and verify.
- **Existing consumer repository**: Use `tools/plan-consumer-update.*` first to review changes, then sync with `--exclude-protected` to preserve custom content. See the [consumer update guide](template/docs/guides/consumer-update.md).

## Template copy vs fork

| Approach | When to use |
| --- | --- |
| Copy `template/` contents | You want to use this template in your own repository (recommended) |
| Fork the repository | You want to contribute changes back to this source repository |

Forking is **not** the primary consumer installation method. Copy `template/` instead.

## Safety model

- Multi-layer defense: execpolicy rules limit dangerous commands, hooks provide pre-flight checks, wrappers enforce presets
- No single layer is a complete security boundary
- Run artifacts and logs should not contain secrets or credentials
- Always review changes before committing, especially in `auto-net` mode
- `auto-net` still forbids deletion, git mutation, and remote script piping

## Do not use this for

- Bypassing sandbox or approval mechanisms
- Running unreviewed commands on production repositories
- Storing secrets in run artifacts or logs
- Delegating broad destructive changes to unattended agents
- Treating hooks, wrappers, or execpolicy rules as a complete security boundary

## Known limitations

- Local shell differences may affect wrapper behavior (Bash vs PowerShell)
- Unofficial Codex providers or non-standard configurations are best-effort only
- No SLA for issue response or PR review
- Template does not automatically configure GitHub settings or branch protection
- `codex-sandbox` (Docker) mode requires explicit `CODEX_DOCKER_IMAGE` environment variable

## Validation

After any change, run the validation suite:

```bash
bash template/scripts/verify
bash template/scripts/verify --strict-harness
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1
powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness
```

Additional validation:

```bash
bash tools/validate-spec.sh
```

### Cleanup

Generated run artifacts can be cleaned up with `scripts/cleanup-runs.sh` or `scripts/cleanup-runs.ps1`. Always use `--dry-run` / `-DryRun` first to preview candidates.

## Versioning

Template versions follow `Major.Minor.Patch`:

- Major: Breaking changes to consumer repo layout or workflow
- Minor: Additions to consumer-facing files, workflows, safety rules
- Patch: Fixes, documentation clarifications, non-breaking maintenance

See [CHANGELOG.md](CHANGELOG.md) for version history and [MIGRATION.md](MIGRATION.md) for migration guidance.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## Support

See [SUPPORT.md](SUPPORT.md) for support channels.

## License

Apache License 2.0. See [LICENSE](LICENSE).
