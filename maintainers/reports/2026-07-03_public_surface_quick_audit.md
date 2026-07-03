# Public surface audit report

## Audit summary

- Audit type: quick
- Date: 2026-07-03 JST
- Branch: chore/oss-readiness-baseline
- Auditor: AI agent
- Result: pass-with-manual-checks
- Release impact: manual-check-required

## Scope

| Area | Checked | Method | Result | Notes |
| --- | --- | --- | --- | --- |
| `root files` | yes | file listing + keyword search | pass | No secrets or private info found. README is maintainer-focused, will be rewritten in this PR. |
| `.codex/` | yes | file listing + keyword search | pass | Tracked `.codex/runs/20260304-175105-JST/` contains operational records (PLAN/TASKS/REPORT) — no secrets found. `.codex/logs/*.jsonl` exists in working tree but is gitignored. |
| `.vscode/` | yes | file listing + keyword search | pass | Only `settings.json` with `chatgpt.openOnStartup: true`. No secrets. |
| `inputs/` | yes | file listing + keyword search | pass | Tracked planning/research documents (Japanese, technical). No secrets or private info found. |
| `examples/` | yes | file listing + keyword search | pass | Sample runs and minimal consumer repo examples. No secrets. |
| `maintainers/` | yes | file listing + keyword search | pass | ADRs, plans, history, reports — all maintainer surface. No secrets. |
| `.github/` | yes | file listing + keyword search | pass | Only workflow YAML. No issue/PR templates yet (will be added in this PR). |
| `template/` | not-applicable | file listing + keyword search | not-applicable | Detailed audit required (PR 2). No suspicious file names found. |
| `tools/` | not-applicable | file listing + keyword search | not-applicable | Detailed audit required (PR 2). No suspicious file names found. |
| `tests/` | not-applicable | file listing + keyword search | not-applicable | Detailed audit required (PR 2). No suspicious file names found. |
| `spec/` | not-applicable | file listing + keyword search | not-applicable | Detailed audit required (PR 2). No suspicious file names found. |

## Findings

| ID | Severity | Path | Finding | Required action | Release impact |
| --- | --- | --- | --- | --- | --- |
| F-001 | info | `.codex/runs/20260304-175105-JST/` | Tracked run artifact directory (3 files: PLAN.md, REPORT.md, TASKS.md). Contains operational records but no secrets. Pre-dates gitignore pattern for `.codex/runs/*`. | Maintainer should decide whether to keep tracked in public repo or remove in separate PR. | none |
| F-002 | info | `.codex/logs/codex-safe-20260227.jsonl` | JSONL log file exists in working tree but is gitignored (`.codex/logs/*.jsonl`). Not pushed to public repo. | None. | none |
| F-003 | info | `.codex/logs/codex-safe-20260314.jsonl` | Same as F-002. | None. | none |
| F-004 | info | `.vscode/settings.json` | Contains `chatgpt.openOnStartup: true`. Non-standard editor config but no secrets. | Maintainer may remove if unwanted. | none |
| F-005 | info | root files (README.md, AGENTS.md, etc.) | All root files are maintainer-focused. Current README is not consumer-oriented — will be rewritten in this PR. | README rewrite is part of this PR scope. | none |
| F-006 | info | `keywords: token` | 172 hits across schemas, scripts, docs, plans. All are safe: schema definitions, security policy blocked_tokens, env passthrough (OPENAI_API_KEY), or audit plan keyword listings. | None. | none |
| F-007 | info | `keywords: secret` | 28 hits across schemas, plans, docs. All are safe: documentation warnings, schema comments, audit plan keyword listings. | None. | none |
| F-008 | info | `keywords: github.com/` | 10 hits across run reports, plans, docs. All are public URLs: public tool references (lychee, markdownlint-cli2, openai-cookbook), own repo PRs, OpenAI company link. | None. | none |
| F-009 | info | `keywords: raw.githubusercontent.com` | 4 hits across run reports and plans. All are public tool download URLs. | None. | none |

## Manual checks required

| ID | Check | Reason | Owner |
| --- | --- | --- | --- |
| M-001 | Secret scanning alerts | GitHub UI required — verify no secrets in push history | maintainer |
| M-002 | GitHub Actions logs | GitHub UI required — verify no secrets in past workflow runs | maintainer |
| M-003 | Dependabot alerts | GitHub UI required — review and configure | maintainer |
| M-004 | Repository About description and topics | GitHub UI required — set description and topics for discoverability | maintainer |
| M-005 | Issues enablement | GitHub UI required — confirm Issues are enabled | maintainer |
| M-006 | Branch protection / ruleset | GitHub UI required — set main branch protection | maintainer |
| M-007 | GitHub Private Vulnerability Reporting | GitHub UI required — decide whether to enable | maintainer |
| M-008 | License copyright holder confirmation | Maintainer must confirm `Copyright 2026 ryu-yoshikawa-pro-vision` or provide alternative | maintainer |

## Decision

- Can continue to next PR: yes
- Can create v0.1.0 release: not-yet (PR 2 detailed audit + manual checks required)
- Separate PR required: no
