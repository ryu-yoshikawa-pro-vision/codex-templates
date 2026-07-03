# OSS readiness plan

作成日: 2026-07-03 JST
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`
作業ブランチ: `docs/oss-readiness-plan`

## 1. 背景

`codex-templates` はすでに GitHub 上で public repository として見えている。したがって本計画の目的は、visibility を public に切り替えることではなく、外部ユーザーが安心して利用・理解・貢献できる OSS としての体裁、説明責任、安全性、運用ルールを整えることである。

このリポジトリは通常のライブラリではなく、Codex / coding agent の作業ルール、テンプレート、wrapper、execpolicy、hook、検証、run artifact 運用を扱う。公開時の主なリスクは、秘密情報の混入だけではなく、利用者が安全境界を誤解して危険な agent 実行を行うことにもある。

## 2. ゴール

- 外部ユーザーがこのリポジトリの目的、対象、使い方、安全上の制約を README だけで理解できる。
- 他者が合法的に利用・複製・変更・再配布できる LICENSE を追加する。
- Issue / PR / security report / support の入口を整備する。
- public repository として残してよい情報だけが repository surface に残っている状態を確認する。
- 初回 OSS release として `v0.1.0` を切れる状態にする。

## 3. 非ゴール

- Codex wrapper、execpolicy、hook、subagent、validator の挙動変更は行わない。
- `template_version` の変更は、この計画単体では行わない。
- Git history rewrite はこの計画では行わない。秘密情報が見つかった場合は、まず credential rotation と影響範囲整理を優先し、history rewrite は別途明示判断する。
- OSS 公開に合わせて過度に production-ready を主張しない。
- GitHub repository settings、topics、release 作成など UI / 設定作業は PR ではなく手動作業として扱う。
- 公開不可情報の削除、移動、履歴修正、credential rotation は本計画の PR には含めない。問題が見つかった場合は別 PR / 別対応へ切り出す。

## 4. 基本方針

### 4.1 License

`Apache-2.0` を採用する。

理由:
- 業務利用・企業利用で説明しやすい。
- テンプレート、wrapper、docs、safety harness を含む repository に対して、権利関係を明確にしやすい。
- 将来的に外部 contributor が増えた場合も、OSS としての利用条件を説明しやすい。

MIT は採用しない。理由は、軽量さよりも企業・業務利用時の説明しやすさ、特許許諾を含む明確性、safety harness を含む repository としての保守性を優先するためである。

License copyright holder:
- AI agent must not invent the copyright holder.
- Use the repository owner / maintainer-approved holder only.
- Default proposal: `Copyright 2026 ryu-yoshikawa-pro-vision`.
- If maintainer prefers personal attribution, replace with maintainer-approved legal name before merging.

### 4.2 Public-facing surface

外部ユーザー向けの入口は以下に集約する。

- `README.md`
- `LICENSE`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `SUPPORT.md`
- `CODE_OF_CONDUCT.md`
- `.github/ISSUE_TEMPLATE/*`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `template/README.md`
- `template/docs/guides/quickstart.md`
- `template/docs/reference/*`

`maintainers/` は source repository の保守文脈を残す場所とする。ただし public repository に置く以上、内部事情、個人情報、非公開 repository 名、token、API key、顧客情報、業務上の秘密にあたる記述がないかを精査する。

### 4.3 Safety messaging

README / SECURITY / SUPPORT では、以下を明示する。

- この repository は安全な agent 運用を補助する template であり、完全な sandbox や完全な防御境界ではない。
- hook / wrapper / execpolicy は多層防御の一部であり、単独で破壊的操作を完全に防げるとは主張しない。
- `danger-full-access`、raw `--full-auto`、`--dangerously-bypass-approvals-and-sandbox` を通常運用では推奨しない。
- `auto-net` は明示指定時のみ使う。通常は safe / readonly を優先する。
- 利用者は各 consumer repository の権限、秘密情報、CI/CD、外部通信、課金リスクを自分で確認する必要がある。

### 4.4 Documentation roles

文書の役割を以下のように分ける。

- `maintainers/plans/*_oss_readiness_plan.md`: OSS readiness の方針、判断理由、PR 分割、非ゴールを記録する。
- `docs/oss-readiness-checklist.md`: 実際に公開前・release 前に使うチェックシートを置く。
- `maintainers/reports/*public_surface_audit*.md`: public surface audit の実施結果、確認対象、発見事項、未確認事項を記録する。
- `README.md`: 外部ユーザー向けの入口として、目的、quickstart、安全制約、貢献方法への導線を提供する。

### 4.5 Maintenance policy

OSS 化後の運用負荷を無制限に増やさないため、以下を前提にする。

- Issue / PR の対応 SLA は設けない。
- 個別環境依存の Codex 設定、非公式 provider、課金・quota 問題は best effort support とする。
- security issue は通常 Issue では扱わず、`SECURITY.md` の方針に従う。
- 破壊的操作、sandbox bypass、approval bypass、危険な unattended execution を促す提案は受け付けない。
- maintainer の運用負荷を大きく増やす機能追加は、実装前に Issue / Discussion で必要性と保守コストを確認する。

### 4.6 Versioning rule

GitHub release version と template version を混同しない。

- GitHub release `v0.1.0` は、repository が OSS-ready になった初回 GitHub release を表す。
- `template/codex-project.toml` の `template_version` は、consumer-facing template contract を表す。
- README / LICENSE / community files / audit reports だけの変更では `template_version` を更新しない。
- `template/` 配下の consumer-facing behavior、contract、workflow、safety rule、distribution content を変える場合は、`template_version` 更新要否を明示判断する。
- `template_version` を更新しない場合、PR 2 の本文または release note draft に「なぜ更新しないか」を明記する。

### 4.7 Manual checks handling

AI エージェントが確認できない GitHub UI 作業は完了扱いしない。

- AI エージェントは manual check を `done` にしてはならない。
- AI エージェントは PR 本文に `Manual checks required` セクションを作り、GitHub UI で確認すべき項目を列挙する。
- maintainer が GitHub UI で確認した後に、PR コメントまたは checklist 上で完了を記録する。
- manual check が release を妨げる場合、PR 2 の release note draft または PR 本文に `Release status: blocked` と明記する。

## 5. Audit 基準

### 5.1 Quick audit の範囲

Quick audit は、公開継続に対する即時リスクの有無だけを確認する。

確認対象:
- root files
- top-level directory
- tracked `.codex/` / `.vscode/` / `inputs/`
- obvious secrets
- obvious private URLs
- obvious customer / personal / internal-only information

Root files include:
- `README.md`
- `AGENTS.md`
- `CODE_REVIEW.md`
- `MIGRATION.md`
- `PLANS.md`
- root-level config / md / yml / yaml / json / toml / sh / ps1 files

実施方法:
- file name / directory name / representative file の確認
- 5.6 の minimum keyword set による危険語句確認
- 全履歴や全ファイルの深掘りはしない

Representative file rule:
- Check all root files matching the root files rule.
- Check all file names under each target directory.
- Check all files directly under each target directory root.
- For nested directories, check README / AGENTS / config / toml / json / yaml / yml / md / sh / ps1 files up to depth 2.
- Do not inspect binary files unless file name indicates secret, credential, log, artifact, trace, recording, archive, or customer data.

完了判定:
- すぐに公開停止、credential rotation、release 保留が必要そうな疑いがあるかを分類できていること。
- manual check が必要な項目を `Manual checks required` として列挙できていること。

### 5.2 Detailed audit の範囲

Detailed audit は、初回 release 前に public repository として残す妥当性を確認する。

確認対象:
- root files の残置理由
- top-level directory の残置理由
- `maintainers/` 配下の履歴文書
- `examples/` 配下の実データ性
- `inputs/` 配下の非公開情報
- `.github/` workflow / template / logs に出る可能性のある情報
- `.gitignore` と tracked runtime artifact の整合

Detailed audit additional areas:
- `template/`: consumer-facing distribution surface
- `tools/`: maintainer / validation scripts
- `tests/`: test fixtures and expected outputs
- `spec/`: source of truth for template behavior

実施方法:
- directory ごとの残置理由を明記する。
- suspicious item があれば severity / release impact / required action を分類する。
- 削除・履歴修正は行わず、別 PR / 別対応に切り出す。

完了判定:
- public に残すもの、別対応にするもの、manual check に残すものが分類されていること。
- `v0.1.0` release 可否が `can-release` / `blocked` / `manual-check-required` のいずれかで明記されていること。

### 5.3 Severity

Audit finding の severity は以下に固定する。

- `blocker`
  - token / API key / password / credential の可能性がある。
  - 顧客名、顧客環境、非公開 repository、個人情報が含まれる可能性がある。
  - Actions logs / artifacts に secret が出た可能性がある。
  - release を保留する。
- `warning`
  - private URL らしき文字列がある。
  - 内部運用前提の記述があり、外部ユーザーに誤解を与える可能性がある。
  - safety harness を過信させる表現がある。
  - release 前に maintainer 判断が必要である。
- `info`
  - 公開してよいが、残置理由を記録すべきもの。
  - `examples/` / `maintainers/` / `inputs/` など、説明が必要な公開物。

### 5.4 Audit report format

Quick audit / detailed audit の report は、以下の形式を使う。

Allowed values:
- Audit summary Result: `pass` / `pass-with-manual-checks` / `blocked`
- Scope Result: `pass` / `warning` / `blocker` / `not-applicable`
- Finding Severity: `info` / `warning` / `blocker`
- Release impact: `none` / `manual-check-required` / `requires-separate-pr` / `hold-release`

```markdown
# Public surface audit report

## Audit summary

- Audit type: quick | detailed
- Date:
- Branch:
- Auditor: AI agent
- Result: pass | pass-with-manual-checks | blocked
- Release impact: none | manual-check-required | requires-separate-pr | hold-release

## Scope

| Area | Checked | Method | Result | Notes |
| --- | --- | --- | --- | --- |
| `root files` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `.codex/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `.vscode/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `inputs/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `examples/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `maintainers/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `.github/` | yes/no | file listing + keyword search | pass/warning/blocker | |
| `template/` | yes/no/not-applicable | file listing + keyword search | pass/warning/blocker/not-applicable | detailed audit required |
| `tools/` | yes/no/not-applicable | file listing + keyword search | pass/warning/blocker/not-applicable | detailed audit required |
| `tests/` | yes/no/not-applicable | file listing + keyword search | pass/warning/blocker/not-applicable | detailed audit required |
| `spec/` | yes/no/not-applicable | file listing + keyword search | pass/warning/blocker/not-applicable | detailed audit required |

## Findings

| ID | Severity | Path | Finding | Required action | Release impact |
| --- | --- | --- | --- | --- | --- |
| F-001 | info/warning/blocker | path | description | none/manual/separate-pr/rotate | none/hold-release |

## Manual checks required

| ID | Check | Reason | Owner |
| --- | --- | --- | --- |
| M-001 | Secret scanning alerts | GitHub UI required | maintainer |

## Decision

- Can continue to next PR: yes/no
- Can create v0.1.0 release: yes/no/not-yet
- Separate PR required: yes/no
```

### 5.5 `.gitignore` と tracked file の扱い

- 新規に runtime artifact / local-only file を除外するだけの `.gitignore` 追記は PR 2 で実施してよい。
- 既に tracked されているファイルの削除、`git rm --cached`、履歴修正は PR 2 では実施しない。
- tracked file を除外すべきと判断した場合は、別 PR の修正指示に切り出す。
- `.gitignore` に追加しただけで tracked file が非公開になるとは扱わない。

### 5.6 Minimum keyword set for audit

Audit では、少なくとも以下の keyword を検索する。

Keyword search rule:
- Keyword search must be case-insensitive.
- Snake case, kebab case, and camel case variants should be treated as equivalent where practical.
- If the tool cannot perform equivalent matching, record the limitation in the audit report.

Secrets / credentials:
- `token`
- `secret`
- `password`
- `passwd`
- `api_key`
- `apikey`
- `access_key`
- `private_key`
- `refresh_token`
- `client_secret`
- `bearer`
- `authorization`

Private / internal:
- `private`
- `internal`
- `confidential`
- `customer`
- `client`
- `prod`
- `production`
- `staging`
- `localhost`
- `ngrok`
- `slack webhook`
- `incoming webhook`

Repository / service hints:
- `github.com/`
- `raw.githubusercontent.com`
- `api.github.com`
- `hooks.slack.com`
- `docs.google.com`
- `drive.google.com`

## 6. Documentation / template 要件

### 6.1 README required structure

`README.md` は以下の構成にする。

1. Project summary
2. What this repository provides
3. Who should use this
4. What this does not guarantee
5. Quickstart
6. Repository layout
7. Execution modes
   - safe
   - readonly
   - auto-net
8. New repository vs existing consumer repository
9. Template copy vs fork
10. Safety model
11. Do not use this for
12. Known limitations
13. Validation
14. Contributing
15. Security
16. Support
17. License

README に必ず含めること:
- Codex CLI 向けを主対象にしつつ、coding agent workflow template として再利用できること。
- 対象 OS / shell の範囲。Bash と PowerShell の両方を扱うこと。
- 新規 repository に導入する場合と、既存 consumer repository に導入する場合の違い。
- `template/` をコピーして使うのか、repository を fork して使うのかの使い分け。
- `safe` / `readonly` / `auto-net` の使い分け。
- SECURITY / CONTRIBUTING / SUPPORT への導線。

Quickstart must include:
- recommended path: copy `template/` contents into a consumer repository.
- validation command after copy.
- note that fork is for contributing to this source repository, not the primary consumer installation method.

README に書く非推奨ユースケース:
- sandbox or approval mechanism を bypass する目的で使うこと。
- production repository に対して未レビューの command を実行すること。
- run artifact や logs に secrets を保存すること。
- 広範囲で破壊的な変更を unattended agent に委任すること。
- hook / wrapper / execpolicy を完全な security boundary とみなすこと。

### 6.2 Community files minimum requirements

`CONTRIBUTING.md` must include:
- 大きな変更は issue または discussion で先に相談すること。
- PR scope rule。1 PR に無関係な変更を混ぜないこと。
- validation commands。
- issues / PRs / logs に secrets を含めないこと。
- consumer-facing changes は `template/` と `spec/` の整合が必要であること。
- wrapper / execpolicy behavior change は明示 scope なしに行わないこと。

`SECURITY.md` must include:
- vulnerabilities を public issues に書かないこと。
- dangerous execution paths、sandbox / approval bypass、secret leaks、destructive operation gaps を報告対象に含めること。
- hooks / wrappers / execpolicy は defense-in-depth であり、完全な security boundary ではないこと。
- supported versions / best effort statement。
- maintainer response は best effort であり、明示しない限り SLA はないこと。
- Preferred reporting channel is GitHub Private Vulnerability Reporting if enabled。
- If private vulnerability reporting is not enabled, do not open a public issue with sensitive details. Open a minimal issue asking for a private reporting channel, without exploit details, secrets, or reproduction steps。
- Do not invent a maintainer email address。

`SUPPORT.md` must include:
- supported: template usage、docs、validation、safe workflow questions。
- best effort: local shell differences、Codex provider config、unofficial models。
- not supported: bypassing approvals/sandbox、production destructive automation、billing/quota troubleshooting。
- security issues should go to `SECURITY.md`。

`CODE_OF_CONDUCT.md` must include:
- expected behavior。
- unacceptable behavior。
- enforcement by maintainer。
- no guarantee of real-time moderation。

### 6.3 Issue / PR template requirements

`bug_report.yml` must include:
- Summary
- Environment
  - OS
  - shell
  - Codex version
  - template version if known
- Command / workflow used
- Expected behavior
- Actual behavior
- Logs / artifacts, with reminder to redact secrets
- Safety impact
  - none / warning / potential dangerous execution / potential secret exposure

`feature_request.yml` must include:
- Problem
- Proposed change
- Target user
- Affected area
  - docs / template / scripts / hooks / rules / tests
- Safety impact
- Maintenance cost
- Alternatives considered

`PULL_REQUEST_TEMPLATE.md` must include:
- Summary
- Scope
- Non-goals
- Safety impact
- Validation
- Documentation updates
- Checklist
  - no secrets
  - no unrelated changes
  - no behavior change unless stated
  - README / SECURITY / SUPPORT updated if needed

### 6.4 `docs/oss-readiness-checklist.md` required structure

`docs/oss-readiness-checklist.md` は以下の構成にする。

1. Purpose
2. How to use this checklist
3. Status legend
   - todo
   - done
   - blocked
   - manual
   - not-applicable
4. Automated checks
5. Manual GitHub UI checks
6. Maintainer decisions
7. Release prerequisites
8. Open blockers
9. Last reviewed date

## 7. PR 分割

OSS readiness は 2 PR にまとめる。1 PR に全てまとめると、community files、public surface audit、release readiness のレビュー観点が混ざりすぎる。4 PR に分けると安全寄りだが、ほとんどが docs / report / checklist のため分割が細かすぎる。したがって、以下の 2 PR を標準とする。

### PR 1: OSS readiness baseline

ブランチ案: `chore/oss-readiness-baseline`

目的:
- すでに public で見えている repository surface の quick audit を行う。
- LICENSE / README / community files / templates / checklist をまとめて整備する。
- 外部ユーザーが安全制約を誤解せず、利用・貢献・報告の入口に到達できる状態にする。

Execution order:
1. Run quick audit first.
2. If blocker is found, create only the quick audit report and stop.
3. Do not add LICENSE / README / community files until blocker handling is separated.
4. If no blocker is found, continue with OSS community files and README updates.

含める内容:
- Public surface quick audit report を作成する。
- `LICENSE` を追加する。ライセンスは `Apache-2.0` とする。
- `README.md` を外部ユーザー向けに再構成する。
- `CONTRIBUTING.md` を追加する。
- `SECURITY.md` を追加する。
- `SUPPORT.md` を追加する。
- `CODE_OF_CONDUCT.md` を追加する。
- `.github/ISSUE_TEMPLATE/bug_report.yml` を追加する。
- `.github/ISSUE_TEMPLATE/feature_request.yml` を追加する。
- `.github/PULL_REQUEST_TEMPLATE.md` を追加する。
- `docs/oss-readiness-checklist.md` を追加する。

実施しないこと:
- wrapper / hook / execpolicy の挙動変更。
- `template_version` 更新。
- release 作成。
- GitHub repository settings 変更。
- ファイル削除。
- Git history rewrite。
- credential rotation の代行。
- tracked file の除外や `git rm --cached`。

完了条件:
- Quick audit が 5.1 / 5.3 / 5.4 / 5.6 の基準で実施されている。
- Public surface quick audit report が作成されている。
- blocker finding がある場合、PR 1 は完了扱いにせず、別対応が必要と明記している。
- AI エージェントでは確認できない項目が、未確認のまま完了扱いされていない。
- README が 6.1 の required structure を満たしている。
- Community files が 6.2 の minimum requirements を満たしている。
- Issue / PR templates が 6.3 の requirements を満たしている。
- `docs/oss-readiness-checklist.md` が 6.4 の required structure を満たしている。
- `bash tools/validate-spec.sh` と `bash template/scripts/verify --strict-harness` が成功する、または実行不可理由が PR 本文に明記されている。
- PR 本文に `Manual checks required` セクションがある。

### PR 2: OSS release readiness

ブランチ案: `chore/oss-release-readiness`

目的:
- PR 1 で整備した OSS baseline を前提に、初回 release 直前の詳細監査と release note を整える。
- `v0.1.0` を手動作成できる状態にする。

含める内容:
- Public surface detailed audit report を作成する。
- `CHANGELOG.md` に OSS 初回公開用の entry を追加する。
- `MIGRATION.md` 更新要否を判断し、必要であれば「既存 consumer repo への影響なし」を明記する。
- `template/codex-project.toml` の `template_version` を変更するかどうかを判断する。
- release note draft を `docs/releases/v0.1.0.md` または `maintainers/plans/` に保存する。
- release 前提条件を `docs/oss-readiness-checklist.md` と照合する。

実施しないこと:
- GitHub release の作成自体。
- npm / package publish などの配布作業。
- Git history rewrite。
- credential rotation の代行。
- 大量削除。
- 設計変更。
- 問題が見つかった場合の公開不可情報の削除・移動・履歴修正。
- tracked file の除外や `git rm --cached`。

問題が見つかった場合:
- release readiness と混ぜず、別 PR / 別対応として扱う。
- 対象、理由、影響範囲、必要な rotation、削除・移動・history rewrite 要否を report に記録する。
- `v0.1.0` release は保留する。

完了条件:
- Detailed audit が 5.2 / 5.3 / 5.4 / 5.6 の基準で実施されている。
- Public surface detailed audit report が作成されている。
- public に残してよい directory / file と、残す理由が説明されている。
- `template_version` を更新するかどうかの判断理由が明記されている。
- `MIGRATION.md` 更新要否の判断理由が明記されている。
- release note draft が作成されている。
- blocker finding がある場合、`Release status: blocked` と明記されている。
- `.gitignore` の不足があれば、5.5 のルールに従って扱われている。
- AI エージェントが確認できない GitHub UI 項目が manual check として残っている。
- `v0.1.0` release を手動作成できる説明が揃っている。
- README / CHANGELOG / MIGRATION / template_version の整合判断が明記されている。
- release 前提条件の未完了項目が明記されている。

## 8. 手動で実施する GitHub 設定

PR ではなく repository settings で実施する。

- About description を設定する。
  - 案: `Safety-first Codex repository template for planning, review, execution logs, and controlled agent workflows.`
- Topics を設定する。
  - `codex`
  - `ai-agent`
  - `coding-agent`
  - `developer-tools`
  - `repository-template`
  - `agent-workflow`
  - `automation`
  - `safety-harness`
- Issues を有効化する。
- Discussions は必要になってから有効化する。
- Branch protection / ruleset を設定する。
  - main 直 push 抑止。
  - PR 必須。
  - CI 必須化は、安定している workflow のみに限定する。
- Security and analysis を確認する。
  - Secret scanning alerts。
  - Dependabot alerts。
  - Code scanning が必要か。
  - GitHub Private Vulnerability Reporting を有効化するか。
- GitHub Actions logs に秘密情報が出ていないか確認する。
- 初回 release `v0.1.0` を作成する。

## 9. 公開前チェックリスト

### 9.1 Automated / PR で確認可能

- [ ] LICENSE がある。
- [ ] README が外部ユーザー向けになっている。
- [ ] `CONTRIBUTING.md` がある。
- [ ] `SECURITY.md` がある。
- [ ] `SUPPORT.md` がある。
- [ ] `CODE_OF_CONDUCT.md` がある。
- [ ] Issue template がある。
- [ ] PR template がある。
- [ ] README から quickstart / security / contribution に到達できる。
- [ ] README に対象環境、利用パターン、非推奨ユースケース、既知の制約がある。
- [ ] public surface quick audit report がある。
- [ ] public surface detailed audit report がある。
- [ ] root files の確認結果が audit report に記録されている。
- [ ] public repository に残す directory の理由が説明できる。
- [ ] `.codex/` 配下に runtime log / run artifact / secret が残っていない。
- [ ] `inputs/` 配下に非公開情報がない。
- [ ] `maintainers/` 配下に公開不可情報がない。
- [ ] `template/` / `tools/` / `tests/` / `spec/` の detailed audit 結果が記録されている。
- [ ] `bash tools/validate-spec.sh` が成功する、または実行不可理由がある。
- [ ] `bash template/scripts/verify --strict-harness` が成功する、または実行不可理由がある。

### 9.2 Manual / GitHub UI で確認

- [ ] GitHub Actions logs に秘密情報がない。
- [ ] Secret scanning alerts を確認した。
- [ ] Dependabot alerts を確認した。
- [ ] About description / topics を設定した。
- [ ] main branch protection / ruleset を設定した。
- [ ] Issues の有効化状態を確認した。
- [ ] GitHub Private Vulnerability Reporting の有効化要否を確認した。
- [ ] 初回 release `v0.1.0` を作成した。

### 9.3 Maintainer decision required

- [ ] `template_version` を更新するか判断した。
- [ ] `MIGRATION.md` 更新要否を判断した。
- [ ] Discussions を有効化するか判断した。
- [ ] Code scanning を有効化するか判断した。
- [ ] GitHub Private Vulnerability Reporting を有効化するか判断した。
- [ ] history rewrite が必要な事象がないか判断した。
- [ ] detailed audit で問題が見つかった場合、release を保留するか判断した。

## 10. v0.1.0 release 前提条件

`v0.1.0` release を作成する前に、最低限以下を満たす。

- [ ] `LICENSE` が存在する。
- [ ] `README.md` が外部ユーザー向けに更新済み。
- [ ] `SECURITY.md` が存在する。
- [ ] `CONTRIBUTING.md` が存在する。
- [ ] `SUPPORT.md` が存在する。
- [ ] Public surface quick audit が完了している。
- [ ] Public surface detailed audit が完了している。
- [ ] root files の audit が完了している。
- [ ] `template/` / `tools/` / `tests/` / `spec/` の detailed audit が完了している。
- [ ] Secret scanning alerts を確認済み。
- [ ] GitHub Actions logs の秘密情報確認が完了している。
- [ ] `bash tools/validate-spec.sh` が成功、または実行不可理由が明記されている。
- [ ] `bash template/scripts/verify --strict-harness` が成功、または実行不可理由が明記されている。
- [ ] release note draft が作成済み。
- [ ] detailed audit で公開不可情報の疑いが残っていない。

## 11. 検証コマンド

最低限:

```bash
bash tools/validate-spec.sh
bash template/scripts/verify --strict-harness
```

PowerShell 環境がある場合:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness
```

README / docs 変更時の追加確認:

- README 内リンクが存在すること。
- `.github` templates が YAML として壊れていないこと。
- SECURITY / SUPPORT / CONTRIBUTING で互いの誘導が循環不全になっていないこと。

## 12. リスクと対策

### リスク 1: Public であることを軽く見て、内部文脈を残しすぎる

対策:
- PR 1 に Public surface quick audit を含める。
- PR 2 に Public surface detailed audit を含める。
- `maintainers/` は残してよいが、公開前提の監査を必須にする。
- root files も audit 対象に含める。
- 迷う情報は削除ではなく、まず audit report に分類する。

### リスク 2: Safety harness を過信させる

対策:
- README / SECURITY / SUPPORT で、補助防御であって完全防御ではないことを明記する。
- 危険な mode を convenience として推奨しない。
- 非推奨ユースケースを README に明記する。

### リスク 3: OSS 化に合わせて機能変更まで混ぜる

対策:
- PR 1 は quick audit、community files、README、checklist に絞る。
- PR 2 は detailed audit、release note、CHANGELOG、version / migration 判断に絞る。
- wrapper / validator / execpolicy の変更は別タスクに分ける。

### リスク 4: ライセンス判断を曖昧にする

対策:
- `Apache-2.0` として固定する。
- LICENSE なしの状態を継続しない。
- copyright holder を AI エージェントが推測しない。

### リスク 5: AI エージェントが GitHub UI 確認を完了扱いする

対策:
- チェックリストを automated / manual / maintainer decision に分類する。
- GitHub UI でしか確認できない項目は `Manual / GitHub UI で確認` に残す。
- PR 完了条件では、未確認項目を未確認として明記できていることを成功条件にする。

### リスク 6: 問題が見つかったのに release readiness まで進める

対策:
- PR 2 の detailed audit で公開不可情報や secret 疑いが見つかった場合、release readiness を完了扱いしない。
- 対応は別 PR / 別タスクに切り出す。
- `v0.1.0` release は保留する。

### リスク 7: Audit が自由作文になり、完了判定が主観化する

対策:
- Audit report format を固定する。
- severity / release impact / required action を必須項目にする。
- allowed values を固定する。
- keyword search は case-insensitive にする。
- `blocker` がある場合は release を保留する。

### リスク 8: PR 1 で blocker があるのに community files 整備まで進める

対策:
- PR 1 は quick audit を最初に実施する。
- blocker が見つかった場合は quick audit report のみ作成して停止する。
- LICENSE / README / community files は blocker 対応を別対応に切り出した後に進める。

## 13. 推奨する次アクション

1. この計画書をレビューする。
2. 問題なければ PR 1 `chore/oss-readiness-baseline` の実装指示を作成する。
3. PR 1 では quick audit、docs、community files、checklist のみを扱い、機能変更を混ぜない。
4. PR 1 マージ後に PR 2 `chore/oss-release-readiness` の実装指示を作成する。
5. PR 2 の detailed audit で問題がなければ、manual check を完了したうえで `v0.1.0` release を作成する。
6. detailed audit で問題が見つかった場合は、release を保留し、別PRで対応する。
