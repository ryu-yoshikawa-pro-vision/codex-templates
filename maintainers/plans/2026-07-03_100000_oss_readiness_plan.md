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

## 4. 基本方針

### 4.1 License

初期案として `Apache-2.0` を採用する。

理由:
- 業務利用・企業利用で説明しやすい。
- テンプレート、wrapper、docs、safety harness を含む repository に対して、MIT よりも権利関係を明確にしやすい。
- 将来的に外部 contributor が増えた場合も、OSS としての利用条件を説明しやすい。

ただし、より軽量な再利用性を最優先する場合は `MIT` も選択肢として残す。最終判断は LICENSE 追加 PR で固定する。

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

## 5. PR 分割

### PR 1: OSS community files と README 整備

ブランチ案: `chore/oss-readiness`

実施すること:
- `LICENSE` を追加する。
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

完了条件:
- README から、目的・対象ユーザー・quickstart・安全制約・貢献方法・サポート範囲へ到達できる。
- OSS community files が root に揃っている。
- Issue / PR template に秘密情報を貼らない注意がある。
- SECURITY.md に公開 Issue へ脆弱性詳細を書かない指示がある。
- `bash tools/validate-spec.sh` と `bash template/scripts/verify --strict-harness` が成功する、または実行不可理由が PR 本文に明記されている。

### PR 2: Public surface audit と不要情報の整理

ブランチ案: `chore/public-surface-audit`

実施すること:
- public repository に残る top-level directory を棚卸しする。
- `.codex/`, `.vscode/`, `inputs/`, `examples/`, `maintainers/`, `.github/` を重点確認する。
- token / secret / private URL / private repo 名 / 顧客情報 / 個人情報 / 内部運用だけの記述を確認する。
- 問題がなければ `maintainers/reports/` または `docs/oss-readiness-checklist.md` に監査結果を記録する。
- 問題があれば削除ではなく、まず影響範囲・必要な rotation・移動方針を report に整理する。

実施しないこと:
- Git history rewrite。
- credential rotation の代行。
- 大量削除。
- 設計変更。

完了条件:
- public に残してよい directory / file と、残す理由が説明されている。
- 秘密情報の疑いがある場合、対応方針が明記されている。
- `.gitignore` の不足があれば補正案が出ている。

### PR 3: 初回 release readiness

ブランチ案: `chore/v0.1.0-release-readiness`

実施すること:
- `CHANGELOG.md` に OSS 初回公開用の entry を追加する。
- 必要であれば `MIGRATION.md` に「既存 consumer repo への影響なし」を明記する。
- `template/codex-project.toml` の `template_version` を変更するかどうかを判断する。
  - consumer-facing contract を変更しない場合は更新しない。
  - README / community files のみなら version 更新は不要。
  - template 配布内容に影響する場合のみ patch / minor を検討する。
- release note draft を `docs/releases/v0.1.0.md` または `maintainers/plans/` に保存する。

実施しないこと:
- GitHub release の作成自体。
- npm / package publish などの配布作業。

完了条件:
- `v0.1.0` release を手動作成できる説明が揃っている。
- README / CHANGELOG / MIGRATION / template_version の整合判断が明記されている。

## 6. 手動で実施する GitHub 設定

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
- 初回 release `v0.1.0` を作成する。

## 7. 公開前チェックリスト

- [ ] LICENSE がある。
- [ ] README が外部ユーザー向けになっている。
- [ ] `CONTRIBUTING.md` がある。
- [ ] `SECURITY.md` がある。
- [ ] `SUPPORT.md` がある。
- [ ] `CODE_OF_CONDUCT.md` がある。
- [ ] Issue template がある。
- [ ] PR template がある。
- [ ] README から quickstart / security / contribution に到達できる。
- [ ] public repository に残す directory の理由が説明できる。
- [ ] `.codex/` 配下に runtime log / run artifact / secret が残っていない。
- [ ] `inputs/` 配下に非公開情報がない。
- [ ] `maintainers/` 配下に公開不可情報がない。
- [ ] GitHub Actions logs に秘密情報がない。
- [ ] Secret scanning alerts を確認した。
- [ ] About description / topics を設定した。
- [ ] main branch protection / ruleset を設定した。
- [ ] `v0.1.0` release note を用意した。

## 8. 検証コマンド

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

## 9. リスクと対策

### リスク 1: Public であることを軽く見て、内部文脈を残しすぎる

対策:
- `maintainers/` は残してよいが、公開前提の監査を必須にする。
- 迷う情報は削除ではなく、まず audit report に分類する。

### リスク 2: Safety harness を過信させる

対策:
- README / SECURITY / SUPPORT で、補助防御であって完全防御ではないことを明記する。
- 危険な mode を convenience として推奨しない。

### リスク 3: OSS 化に合わせて機能変更まで混ぜる

対策:
- PR 1 は community files と README のみに絞る。
- wrapper / validator / execpolicy の変更は別タスクに分ける。

### リスク 4: ライセンス判断を曖昧にする

対策:
- 初期案は `Apache-2.0` として固定し、異論がある場合だけ MIT に切り替える。
- LICENSE なしの状態を継続しない。

## 10. 推奨する次アクション

1. この計画書をレビューする。
2. 問題なければ PR 1 `chore/oss-readiness` の実装指示を作成する。
3. PR 1 では docs / community files のみを追加し、機能変更を混ぜない。
4. PR 1 マージ後に public surface audit を行う。
5. audit 完了後に `v0.1.0` release readiness を整える。
