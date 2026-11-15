# Source Repo 計画書 — codex-templates GitHub Actions security-only updates

## 0. 依頼概要
- 依頼内容: 稼働中repoのT13 Actions依存監査で見つかった `actions/checkout` に対し、GitHub Actions ecosystem のDependabot security-only設定を提案する。
- 背景: root workflowはcheckout actionをfull commit SHAでpinしているが、Dependabot設定がなく、GitHub側のalerts/security updatesも無効状態。
- 期待成果: 通常version-update PRを出さずsecurity updatesを設定できるDependabot configのPRとexact-head CI evidence。

## 1. ゴール / 完了条件
- `spec/` 影響: なし。consumer-facing contractの変更なし。
- ゴール: Actions dependencyのsecurity update routeを構成ファイルで表現し、routine version updatesを抑止する。
- 完了条件（DoD）: `.github/dependabot.yml`がGitHub Actions `/`だけを対象とし、required schedule keyと`open-pull-requests-limit: 0`を含む。YAML/config validation、`git diff --check`、PR exact-head repository CIが成功。PRはOpen/unmergedのまま。GitHub settingsは変更しない。

## 2. スコープ
- In Scope: root `.github/dependabot.yml`にgithub-actions `/`, required weekly schedule key, limit 0; source repo plan; run-local evidence; feature branch; PR and exact-head CI.
- Out of Scope: npm/Python or other ecosystems; routine version updates; repo settings/permissions; merge/close; workflow/source/spec/template changes; deployment or external data operation.

## 2.1 現状理解と前提
- Current understanding: active/default `main` SHA `7ae854df14e4b824ebbb914dd8a2394d7f939830`; `.github/workflows/validate-template.yml` contains a SHA-pinned `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5`; no other `uses:` refs, package manifest/lock, custom update workflow, open PR, or Dependabot config. The workflow validates spec/template and runs repository-local tests on PR/push.
- Settings: current API reads show `automated-security-fixes.enabled=false`; vulnerability-alert endpoint is HTTP404. Do not change settings under this task; enabling awaits A-04 authorization. Config proposal alone does not enable repository security settings.
- Assumptions: user-approved repository-wide security-only policy permits a PR proposing a GitHub Actions-only Dependabot config. Weekly interval is the required schema key; `open-pull-requests-limit: 0` prevents regular version-update PRs.
- Official docs: [security-only limit 0](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-security-updates); [GitHub Actions directory `/`](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#directory).

## 3. 実行タスク
- [x] 1. Current repo state, workflow/action references, Dependabot state, and related PR state inspected.
- [x] 2. Repo AGENTS, PROJECT_CONTEXT, recent ADRs/run, README, planning requirements, and official GitHub config semantics reviewed.
- [x] 3. Security-only scope, no-setting-change boundary, and validation plan recorded.
- [ ] 4. Config + plan edits, safe local config validation, commit/push feature branch, create PR.
- [ ] 5. Exact current-head Actions CI completion and final report.

## 3.1 変更面の切り分け
- Source-repo changes: `.github/dependabot.yml`; `maintainers/plans/2026-11-16_014948_actions-security-only-codex-templates.md`.
- Consumer-facing changes: none. `template/`, `spec/`, and runtime harness are unchanged.

## 4. マイルストーン
- M1: Reconcile current repo, workflow ecosystem, security-only policy, and repo-specific instructions — complete.
- M2: Prepare config and verify its structure/security-only semantics — pending.
- M3: PR and exact-head CI result recorded; settings remain separately approval-gated — pending.

## 5. リスクと対策
- リスク: `open-pull-requests-limit: 0` may be misread as disabling all Dependabot activity.
  - 対策: restrict entry to `github-actions`; document that the limit disables version-update PRs while security PRs are separately limited. Do not set ignore rules.
- リスク: GitHub security updates are currently disabled.
  - 対策: do not imply this config activates them; track enablement separately under A-04 and await explicit admin action.
- リスク: PR workflow runs repository validation.
  - 対策: reviewed workflow is local validation only; no deployment, secrets, or external service steps.

## 6. 検証方法
- 実施する確認: parse/assert YAML; `git diff --check`; diff review ensures only Actions ecosystem and limit 0; PR checks on final head.
- 成功判定: config parse and assertions pass, diff has no routine update path, all required PR check-runs at exact final HEAD succeed. No CI/no run is not success.

## 7. 成果物
- 変更ファイル: `.github/dependabot.yml`, this plan.
- 付随ドキュメント: `.codex/runs/20261116-014948-JST/{PLAN,TASKS,REPORT}.md` (run artifacts are local/ignored).

## 7.1 移行 / rollback
- Migration: none. Settings activation requires separate explicit approval/admin operation and post-change verification.
- Rollback: if maintainers reject the proposal before merge, leave PR open for owner disposition; any future revert/removal must use a separate reviewed PR. Do not merge/close without approval.

## 8. 備考
- Work branch: `codex/t13-actions-security-only-20261116-0149`.
- Current base SHA: `7ae854df14e4b824ebbb914dd8a2394d7f939830`.
