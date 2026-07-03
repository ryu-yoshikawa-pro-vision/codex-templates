# Security

## Reporting vulnerabilities

**Do not** report security vulnerabilities through public GitHub issues.

If you find a security issue, please use one of the following methods:

1. **GitHub Private Vulnerability Reporting** (if enabled): Navigate to the repository's "Security" tab and use the "Report a vulnerability" button.
2. **If Private Vulnerability Reporting is not enabled**: Open a minimal public issue asking for a private reporting channel. Do not include exploit details, secrets, or reproduction steps in the public issue.

## What to report

- Dangerous execution paths in wrappers, hooks, or execpolicy rules
- Sandbox or approval bypass findings
- Potential secret leaks through run artifacts or logs
- Destructive operation gaps in safety guardrails
- Any other behavior that could lead to unauthorized or destructive operations

## Defense-in-depth

Hooks, wrappers, and execpolicy rules in this repository are **defense-in-depth** mechanisms. They are designed to reduce risk, not to serve as a complete security boundary. Always:

- Review agent-generated changes before applying them
- Use the safest execution mode (`safe` or `readonly`) for your task
- Keep secrets out of run artifacts and logs
- Configure repository-level protections (branch rules, secret scanning) independently

## Supported versions

Security updates are provided on a best-effort basis for the latest version of the template. Older versions may not receive patches.

## Maintainer response

Maintainer response to security reports is best effort. There is no stated SLA unless explicitly agreed. If you do not receive a response within a reasonable time, you may follow up on the public issue (without sensitive details).
