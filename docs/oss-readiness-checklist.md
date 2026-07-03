# OSS readiness checklist

## Purpose

This checklist tracks the tasks required to make `codex-templates` ready for public OSS release. It is maintained alongside the [OSS readiness plan](../maintainers/plans/2026-07-03_100000_oss_readiness_plan.md) and audit reports in [maintainers/reports/](../maintainers/reports/).

## How to use this checklist

- Automated checks are confirmed by running validation commands or by AI agent verification.
- Manual checks require GitHub UI or human decision.
- Maintainer decisions require explicit maintainer confirmation.
- Update the status and last reviewed date after each review pass.

## Status legend

- **todo**: Not yet started
- **done**: Completed and verified
- **blocked**: Cannot proceed until a dependency is resolved
- **manual**: Requires human/GitHub UI action — cannot be verified by automation
- **not-applicable**: Not relevant for this release

## Automated checks

| ID | Check | Status | Notes |
| --- | --- | --- | --- |
| A-01 | LICENSE file exists | done | Apache 2.0 |
| A-02 | README is consumer-ready | done | Restructured for external users |
| A-03 | CONTRIBUTING.md exists | done | |
| A-04 | SECURITY.md exists | done | |
| A-05 | SUPPORT.md exists | done | |
| A-06 | CODE_OF_CONDUCT.md exists | done | |
| A-07 | Bug report issue template exists | done | |
| A-08 | Feature request issue template exists | done | |
| A-09 | PR template exists | done | |
| A-10 | Quick audit report exists | done | `maintainers/reports/2026-07-03_public_surface_quick_audit.md` |
| A-11 | README links point to existing files | done | Verified in this PR |
| A-12 | Issue/PR templates are valid YAML/MD | done | Verified in this PR |
| A-13 | SECURITY/SUPPORT/CONTRIBUTING cross-reference is not circular | done | Verified in this PR |
| A-14 | No secrets in keyword-scanned files | done | Quick audit pass |
| A-15 | `bash tools/validate-spec.sh` passes | done | Passed in GitHub Actions `Validate template` run #66 |
| A-16 | `bash template/scripts/verify --strict-harness` passes | done | Passed in GitHub Actions `Validate template` run #66 |
| A-17 | `tools/validate-spec.ps1` passes | done | Passed in GitHub Actions `Validate template` run #66 |
| A-18 | `template/scripts/verify.ps1 -StrictHarness` passes | done | Passed in GitHub Actions `Validate template` run #66 |

## Manual GitHub UI checks

| ID | Check | Status | Notes |
| --- | --- | --- | --- |
| M-01 | Secret scanning alerts reviewed | manual | GitHub UI required |
| M-02 | GitHub Actions logs reviewed for secrets | manual | GitHub UI required |
| M-03 | Dependabot alerts reviewed | manual | GitHub UI required |
| M-04 | Repository About description set | manual | GitHub UI required |
| M-05 | Repository topics set | manual | GitHub UI required |
| M-06 | Issues enabled | manual | GitHub UI required |
| M-07 | Main branch protection / ruleset configured | manual | GitHub UI required |
| M-08 | GitHub Private Vulnerability Reporting decision | manual | GitHub UI required |
| M-09 | Discussions enablement decision | manual | GitHub UI required |
| M-10 | Code scanning enablement decision | manual | GitHub UI required |

## Maintainer decisions

| ID | Decision | Status | Notes |
| --- | --- | --- | --- |
| D-01 | LICENSE copyright holder confirmed | manual | Proposed: `Copyright 2026 ryu-yoshikawa-pro-vision` |
| D-02 | `template_version` update needed | not-applicable | PR 1 does not change template behavior |
| D-03 | MIGRATION.md update needed | not-applicable | PR 1 does not change template behavior |
| D-04 | History rewrite needed | not-applicable | No secrets found in quick audit |
| D-05 | Discussions enabled | manual | Decision by maintainer |
| D-06 | Code scanning enabled | manual | Decision by maintainer |
| D-07 | GitHub Private Vulnerability Reporting enabled | manual | Decision by maintainer |

## Release prerequisites

| ID | Prerequisite | Status | Notes |
| --- | --- | --- | --- |
| R-01 | PR 1 (OSS readiness baseline) merged | todo | Current PR |
| R-02 | PR 2 (OSS release readiness) with detailed audit | todo | Separate PR |
| R-03 | Detailed audit of template/ tools/ tests/ spec/ completed | todo | PR 2 scope |
| R-04 | Detailed audit report created | todo | PR 2 scope |
| R-05 | Release note draft created | todo | PR 2 scope |
| R-06 | All manual checks completed | todo | Requires maintainer |
| R-07 | All automated checks passing | todo | PR 1 validation passed; final release readiness confirmation remains PR 2 scope |
| R-08 | Versioning decision made | todo | PR 2 scope |
| R-09 | v0.1.0 release created | todo | Manual GitHub UI action |

## Open blockers

None currently.

## Last reviewed date

2026-07-03 JST
