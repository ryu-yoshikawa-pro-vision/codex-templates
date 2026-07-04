# Public surface detailed audit report

## Audit summary

- Audit type: detailed
- Date: 2026-07-04 JST
- Branch: chore/oss-release-readiness
- Auditor: AI agent
- Result: pass-with-manual-checks
- Release impact: manual-check-required

## Scope

| Area | Checked | Method | Result | Public retention reason / Notes |
| --- | --- | --- | --- | --- |
| `root files` | yes | file listing + keyword search + representative content review | pass | 14 files: LICENSE, README.md, AGENTS.md, CHANGELOG.md, CODE_OF_CONDUCT.md, CODE_REVIEW.md, CONTRIBUTING.md, MIGRATION.md, PLANS.md, SECURITY.md, SUPPORT.md, .editorconfig, .gitattributes, .gitignore. All are standard OSS community/entry files. No secrets or private info. |
| `top-level directories` | yes | file listing + keyword search | pass | 13 directories: .agents/, .codex/, .github/, .vscode/, docs/, examples/, inputs/, maintainers/, scripts/, spec/, template/, tests/, tools/. All serve documented source-repo purposes. No suspicious directory names. |
| `.github/` | yes | workflow/template review + keyword search | pass | 4 files: PULL_REQUEST_TEMPLATE.md, ISSUE_TEMPLATE/bug_report.yml, ISSUE_TEMPLATE/feature_request.yml, workflows/validate-template.yml. Standard GitHub workflows and templates. No secrets. |
| `.codex/` | yes | file listing + keyword search + artifact review | pass | Tracked: .gitignore for logs/runs, .gitkeep, and one historical run directory (20260304-175105-JST, 3 PLAN/REPORT/TASKS files). JSONL logs and other run dirs are gitignored. Historical tracked run pre-dates gitignore pattern. See finding F-001 (from quick audit). |
| `.vscode/` | yes | file review + keyword search | pass | settings.json (39 bytes) with `chatgpt.openOnStartup: true`. Tracked despite `.vscode/` in .gitignore (file pre-dates ignore rule). No secrets. See finding F-004 (from quick audit). |
| `inputs/` | yes | file listing + keyword search + representative content review | pass | 5 files in tracked dir: planning/research documents (Japanese, technical). Content includes internal engineering narratives and strategy discussions. No secrets, credentials, or customer data. Retention justified as source-repo working context. |
| `examples/` | yes | file listing + keyword search + fixture review | pass | 11 tracked files: sample runs, minimal consumer repo, SDK runner, harness examples. All are consumer-facing examples with generic IDs. No secrets. |
| `maintainers/` | yes | plans/reports/history review + keyword search | pass | 67 tracked files: PROJECT_CONTEXT.md, ADRs (14), architecture notes, history files (12), plans (27+), reports (11+). All maintainer surface documentation. No secrets or private info. Appropriate for public retention as source-repo context. |
| `template/` | yes | consumer-facing contract review + keyword search | pass | 488 files. Consumer-facing distribution surface. template/.gitignore properly excludes artifacts/, reports/, logs/*.jsonl, runs/*, scripts/__pycache__/ from consumer distribution. All tracked files are intentional contract files. No secrets. |
| `tools/` | yes | maintainer script review + keyword search | pass | 6 files: validate-spec (ps1/sh), sync-template (ps1/sh), plan-consumer-update (ps1/sh). Maintainer helper scripts. No secrets. |
| `tests/` | yes | fixture/expected-output review + keyword search | pass | 27 files: fixtures (6), integration tests (14), smoke tests (3). Standard test infrastructure. Test data uses generic/placeholder values. No secrets. |
| `spec/` | yes | source-of-truth contract review + keyword search | pass | 11 JSON schema/contract files. Source of truth for template behavior. No secrets. |

## Findings

| ID | Severity | Path | Finding | Required action | Release impact |
| --- | --- | --- | --- | --- | --- |
| F-001 | info | `.codex/runs/20260304-175105-JST/` | Tracked run artifact directory (3 files: PLAN.md, REPORT.md, TASKS.md). Contains operational records but no secrets. Pre-dates gitignore pattern for `.codex/runs/*`. | Maintainer should decide whether to keep tracked in public repo or remove in separate PR. | none |
| F-002 | info | `template/.codex/artifacts/` | Gitignored task artifact files (74+ small JSON files, 12-13 bytes each). Properly excluded from distribution by template/.gitignore. | None. | none |
| F-003 | info | `template/.codex/logs/` | Gitignored JSONL runtime log files (58 files, ~300KB total). Properly excluded by template/.gitignore. | None. | none |
| F-004 | info | `template/.codex/runs/` | Gitignored test/development run directories. Only .gitkeep is tracked. Properly excluded by template/.gitignore. | None. | none |
| F-005 | info | `template/scripts/__pycache__/` | Gitignored Python bytecode cache (2 .pyc files). Properly excluded by template/.gitignore. | None. | none |
| F-006 | info | `.vscode/settings.json` | Tracked editor config file with `chatgpt.openOnStartup: true`. Pre-dates `.vscode/` in .gitignore. No secrets. | Maintainer may remove in separate PR if unwanted. | none |
| F-007 | info | `keywords: token` | 173+ hits across schemas, scripts, docs, plans. All safe: schema definitions, security policy blocked_tokens, env passthrough (OPENAI_API_KEY), audit plan keyword listings. | None. | none |
| F-008 | info | `keywords: secret` | 28+ hits across schemas, plans, docs, community files. All safe: documentation warnings, schema comments, audit plan keyword listings, security reporting guidance. | None. | none |
| F-009 | info | `keywords: private` | 36+ hits across community files, plans, reports. All safe: standard references to "private information", "private reporting", "private URL" in community files and audit keyword listings. | None. | none |
| F-010 | info | `keywords: internal` | 12+ hits across inputs, maintainer docs, plans. All safe: narrative context about "internal use" in input documents, JSON schema `$ref` context in maintainer docs. | None. | none |
| F-011 | info | `keywords: customer` | 7 hits in plans and reports. All safe: audit keyword listing context. | None. | none |
| F-012 | info | `keywords: production` | 8 hits across inputs, README, SECURITY, SUPPORT, maintainer reports. All safe: general descriptive context ("production repositories", "production destructive automation", "Production dashboard"). | None. | none |
| F-013 | info | `keywords: github.com/` | 10+ hits across run reports, plans, docs. All safe: public tool references (lychee, markdownlint-cli2, openai-cookbook), own repo PRs, OpenAI company link. | None. | none |
| F-014 | info | `keywords: raw.githubusercontent.com` | 4 hits across run reports and plans. All safe: public tool download URLs. | None. | none |
| F-015 | info | `inputs/2026-03-04/Harness engineering.md` | Internal engineering narrative document. Contains references to "internal beta", "internal daily users", "internal developer tools" — all part of a published-style anecdotal account of agent development. No actual secrets or credentials. | None. | none |

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
| M-008 | Code scanning enablement decision | GitHub UI required — decide whether to enable | maintainer |
| M-009 | Discussions enablement decision | Maintainer decision required — decide whether to enable | maintainer |
| M-010 | LICENSE copyright holder confirmation | Maintainer must confirm `Copyright 2026 ryu-yoshikawa-pro-vision` or provide alternative | maintainer |

## Release decision

- Can create v0.1.0 release: yes (after manual checks)
- Release status: manual-check-required
- Separate PR required: no
- Reason: No blocker findings. All keyword-scanned content is safe. template/ distribution surface properly excludes runtime artifacts. Manual GitHub UI checks and maintainer decisions remain before release creation.

## Consumer-facing template contract assessment

The following `template/` areas were reviewed as consumer-facing distribution surface:

| Area | Reviewed | Status | Notes |
| --- | --- | --- | --- |
| `template/AGENTS.md` | yes | pass | Codex working agreement for consumer repos |
| `template/PLANS.md` | yes | pass | Planning workflow entry point |
| `template/CODE_REVIEW.md` | yes | pass | Review workflow entry point |
| `template/MIGRATION.md` | yes | pass | Migration guide (consumer copy) |
| `template/codex-project.toml` | yes | pass | Template version 0.11.0, project config |
| `template/.codex/config.toml` | yes | pass | Codex configuration |
| `template/.codex/requirements.toml` | not found | not-applicable | File does not exist; not required by current template contract |
| `template/.codex/agents/*` | yes | pass | Agent definitions |
| `template/.codex/hooks/*` | yes | pass | Pre/post tool use hooks (ps1, py, sh) |
| `template/.codex/templates/*` | yes | pass | Run templates (PLAN, TASKS, REPORT, EVALUATION, RUN_MANIFEST, schemas) |
| `template/.codex/rules/*` | yes | pass | Execpolicy rules |
| `template/.codex/rules-auto-net/*` | yes | pass | Auto-net execution rules |
| `template/scripts/*` | yes | pass | Wrappers, verify, cleanup, init scripts |
| `template/.agents/skills/*` | yes | pass | Repo-local skills (code-review, feature-plan, repair-loop, harness-improvement) |
| `template/docs/reference/*` | yes | pass | Reference documentation |
| `template/docs/guides/*` | yes | pass | User guides (quickstart, consumer-update, pr-review-request) |
| `template/examples/*` | yes | pass | Example run patterns (harness-improvement, repair-loop) |
| `template/docs/plans/TEMPLATE.md` | yes | pass | Plan template |

All consumer-facing template contract files are present and contain no secrets, credentials, or private information.

## .gitignore assessment

- Root `.gitignore`: Covers `.vscode/`, `.codex/logs/*.jsonl`, `.codex/runs/*`, `template/.codex/logs/*.jsonl`, `template/.codex/runs/*`. Adequate for source repo.
- `template/.gitignore`: Covers `.codex/artifacts/`, `.codex/reports/`, `.codex/logs/*.jsonl`, `.codex/runs/*`, `scripts/__pycache__/`. Adequate for consumer distribution surface.
- No patterns need to be added. All runtime artifacts are properly excluded from distribution.
- `.vscode/settings.json` is a tracked file that pre-dates the `.vscode/` gitignore rule. It contains no secrets. Separate PR required if maintainer wants to stop tracking it.
