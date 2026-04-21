# Codex Templates 運用品質改善計画

## 0. spec 影響
- `spec/` 影響あり。
- 影響対象:
  - `spec/workflow.yaml`: run-first artifact、TASKS 調査順、required files / checks の更新
  - `spec/routing.yaml`: plan/review guidance、review report 生成抑制、Lightweight / Standard / Strict の導線更新
  - `spec/safety-policy.yaml`: `config.toml` baseline、削除禁止、blocked token、verify fallback、fake codex 検証の更新
  - `spec/naming.yaml`: run 配下 artifact / report / log の命名規則追加

## 1. Goal
- `inputs/2026-04-20/input.md` の評価で妥当だった指摘を、この source repo と consumer-facing template の改善計画へ落とし込む。
- 重点は、新しい思想追加ではなく次の運用品質を上げること。
  - 配布テンプレートを清潔に保つ
  - bash / PowerShell 検証を自己完結させる
  - ハーネス成果物を `.codex/runs/<run_id>/` 中心に集約する
  - 明示的な調査・保存依頼がないレビューで `reports/` ファイルを生成させない
  - プロジェクト配下の読み書きは実用的に許可し、削除は禁止する
  - `template/.codex/config.toml` を公式 Codex config に沿った安全な既定値へ整備する
  - 社内自動化 / テスト自動化プロジェクトの初期導入体験を改善する

## 2. Current Understanding
- `input.md` の総評は概ね妥当。
- 現行 repo で確認できた事実:
  - `template/.codex/artifacts/codex-task-*.json` が Git 追跡対象として残っている。
  - `template/.codex/logs/codex-safe-*.jsonl` と `codex-task-*.jsonl` が作業成果物として残っている。
  - `template/.gitignore` は `.codex/logs/*.jsonl` と `.codex/runs/*` だけを無視し、`.codex/artifacts/` と `.codex/reports/` を無視していない。
  - `template/.codex/requirements.toml` は consumer template 内に存在しない `docs/plans/2026-02-26_...` と `docs/reports/2026-02-26_...` を参照している。
  - `codex-task.ps1/.sh` の既定出力先は `.codex/artifacts`, `.codex/reports`, `.codex/logs` で、run artifact と分断されている。
  - `tests/integration/test-codex-safety-harness.sh` は実 `codex` に依存し、`test-codex-task-harness.sh` のように fake codex だけでは完結していない。
  - `template/.codex/templates/TASKS.md` は「不足知識を Web 検索」と固定しており、repo / docs / tickets / logs を優先する社内運用には過剰。
  - `template/AGENTS.md` は `docs/reports/` の保存先を示しているが、review だけで report file を作らない境界は明示していない。
  - `template/.codex/config.toml` は `repo_safe` と `repo_readonly` だけを定義し、delete ban、network、shell environment、login shell の方針を表していない。
  - `template/.codex/rules/30-destructive-forbidden.rules` は一部の破壊的 command を禁止するが、単純な file delete や `git rm` などの削除系を網羅していない。
- 追加で確認した事実:
  - `bash template/scripts/verify` は現環境で CRLF により失敗した。
  - `bash tests/smoke/test-template-layout.sh` は `rg` 不在により失敗した。
  - `bash tools/validate-spec.sh` と `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1` は PASS。
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1` は PASS=3 FAIL=0 SKIP=0。
  - Codex CLI 0.121.0 の help と OpenAI 公式 docs では、project `.codex/config.toml`、`sandbox_mode`, `approval_policy`, profiles, rules, workspace-write sandbox が現行の設定面として確認できる。

## 3. Assumptions
- この template は、軽い個人利用ではなく、社内自動化プロジェクトやテスト自動化プロジェクトの標準運用ベースラインとして磨く。
- 既存 ADR 0007 / 0008 の方針を維持する。
  - consumer-facing template は `AGENTS.md` + `.agents/skills/` + `.codex/` + `docs/reference/` を基本構造とする。
  - 手動対話、非対話実装、Docker 実験の 3 層ハーネスを維持する。
- `spec/*.yaml` が実質 JSON である点は違和感として妥当だが、ファイル改名は破壊的なので本計画では実施しない。
- project type overlay は価値が高いが、まずは base template の運用品質を上げた後の後続フェーズに回す。
- 新しい task mode を増やすより、既存の `safe|readonly` permission profile と `PLANS.md` / `CODE_REVIEW.md` / skills の intent routing を強化する。
- `workspace-write` は command-based deletion を防がないため、削除禁止は `AGENTS.md`、rules、wrapper preflight、tests で明示的に担保する。
- `apply_patch` は command-based deletion ではなく、差分単位で意図を確認できる編集手段なので禁止しない。
- review 結果は原則としてチャット返答に出し、明示的な調査・保存依頼がある場合だけ `docs/reports/` または `maintainers/reports/` に保存する。
- `reports/` は durable な調査・監査・実行結果の置き場であり、通常のレビュー返答、進捗報告、軽い確認結果、run 内ログの既定保存先ではない。

## 4. Source-repo Changes
- run / plan / report:
  - 実装開始時に `.codex/runs/<run_id>/` を初期化する。
  - 本計画を `maintainers/plans/2026-04-20_220233_operations-quality-hardening.md` として保持する。
  - 実装中の行動ログは `.codex/runs/<run_id>/REPORT.md` に集約する。
  - `maintainers/reports/` は、ユーザーが明示的に調査レポートや保存レポートを求めた場合だけ作成する。
- governance:
  - run-first ハーネス、template readiness、fake codex self-contained testing を ADR として記録する。
  - `maintainers/PROJECT_CONTEXT.md` と `maintainers/history/` に、今回の運用品質改善の到達点を反映する。
- tests / tools:
  - bash smoke / integration の `rg` 依存をなくし、`grep` または Python fallback を使う。
  - `tools/sync-template.sh/.ps1` は後続で `--dry-run` / marker / backup を検討するが、本フェーズでは必須化しない。

## 5. Consumer-facing Changes
- 配布テンプレート清潔化:
  - `template/.codex/artifacts/*` の tracked stub は、ファイル実体を削除せず Git 追跡対象から外して配布対象外にする。
  - `template/.codex/logs/*.jsonl` の tracked 実行ログは、ファイル実体を削除せず Git 追跡対象から外して配布対象外にする。
  - `.codex/artifacts/`, `.codex/reports/`, `.codex/logs/*.jsonl` を `template/.gitignore` に追加する。
  - 必要な空ディレクトリは `.gitkeep` だけで保持する。
  - `template/.codex/requirements.toml` の死んだ links は、`docs/reference/codex-safety-harness.md` と `docs/reference/codex-implementation-harness.md` へ差し替える。
- review / report 境界:
  - `template/CODE_REVIEW.md` と code-review skill に「レビュー結果は原則チャット返答のみ。明示的な調査・保存依頼がない限り `docs/reports/` へファイルを作らない」を追加する。
  - root `CODE_REVIEW.md` にも同じ境界を追加し、source repo 作業で `maintainers/reports/` が勝手に増えないようにする。
  - `template/AGENTS.md` の `Reports` 説明は、調査・実行レポート用であり review output の既定保存先ではないと明記する。
  - report file 生成ルールを `AGENTS.md`、`CODE_REVIEW.md`、planning / review references、`spec/routing.yaml` に明記する。
  - Allowed: ユーザーが「レポートとして保存」「調査レポートを作成」など保存を明示した場合、計画の DoD に report file が明記されている場合、複数ソース調査・監査・検証結果を後で参照する durable artifact として残す必要がある場合。
  - Not allowed: review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価では `reports/` にファイルを作らない。
  - 保存先は source repo 作業なら `maintainers/reports/`、consumer repo 作業なら `docs/reports/` とし、`.codex/runs/<run_id>/REPORT.md` は run-local log として別扱いにする。
  - 判断に迷う場合は report file を作らず、チャット返答と `.codex/runs/<run_id>/REPORT.md` に留める。
- safety / deletion ban:
  - `template/AGENTS.md` と `docs/reference/codex-safety-harness.md` に「プロジェクト配下の読み書きは許可。ただし shell / PowerShell / git などの command によるファイル削除、履歴破壊、配布対象の除去は明示承認なしに行わない」を追加する。
  - `apply_patch` は差分単位で確認できる通常の編集手段として許可し、削除禁止の対象には含めない。
  - `.codex/rules/30-destructive-forbidden.rules` に `rm <file>`, `del`, `erase`, `Remove-Item <path>`, `rmdir`, `unlink` などの deletion command を prompt ではなく forbidden として追加する。
  - `git rm` は wrapper で扱い、通常の `git rm <path>` は blocked、tracked artifact 配布除外のための `git rm --cached -- <path>` だけを一回限りの明示的 migration として許可する。
  - wrapper の unsafe argument / preflight / tests に、deletion command が block され、`git rm --cached -- <tracked artifact>` だけが migration case として扱われることを追加する。
  - tracked artifact を配布対象外にする一回限りの移行は、通常の file delete ではなく index-only untrack として扱い、作業ツリー上のファイル実体は消さない。
- line ending / shell portability:
  - `.gitattributes` に拡張子なし shell entrypoint の LF 指定を追加する。
  - `template/scripts/verify` を LF に揃える。
  - verify は `scripts/codex-safe.sh` の `-x` 判定をやめ、存在確認後に `bash scripts/codex-safe.sh ...` で実行する。
- harness self-contained testing:
  - `tests/integration/test-codex-safety-harness.sh` を `CODEX_BIN=tests/fixtures/fake-codex.sh` で動かせるようにする。
  - 実 `codex` が必要な確認は live test として opt-in に分ける。
  - `template/scripts/verify` も `CODEX_BIN` override と fake codex を前提にした検査を扱えるようにする。
- run-first harness:
  - `codex-safe.ps1/.sh` と `codex-task.ps1/.sh` に `--run-id` を追加する。
  - `--run-id` 指定時は成果物を `.codex/runs/<run_id>/artifacts`, `reports`, `logs` に集約する。
  - 明示 `--output-file`, `--report-path`, `--log-path` は後方互換として維持する。
  - task report JSON に `run_id`, `git_branch`, `git_dirty`, `cwd`, `mode` を追加する。
- `config.toml` / permission baseline:
  - `template/.codex/config.toml` は top-level 既定を `sandbox_mode = "workspace-write"` と `approval_policy = "untrusted"` にする。
  - `web_search = "cached"` を既定にし、live web search は wrapper の `--allow-search` または明示設定時だけ許可する。
  - `[sandbox_workspace_write]` では `network_access = false` と `writable_roots = []` を明示し、project root 以外の writable root を増やさない。
  - `allow_login_shell = false` とし、login shell 経由の環境差分と暗黙副作用を減らす。
  - `[shell_environment_policy]` は `inherit = "core"` を基本にし、機密値を含みやすい環境変数を追加で継承しない。
  - `[profiles.repo_safe]` は上記と同じ標準運用、`[profiles.repo_readonly]` は `sandbox_mode = "read-only"` / `approval_policy = "untrusted"` とする。
  - `safe|readonly` 以外の新 mode は本フェーズでは追加しない。planning / review / implementation の違いは `PLANS.md`, `CODE_REVIEW.md`, `.agents/skills/*` の task workflow で表現する。
- workflow:
  - `template/.codex/templates/TASKS.md` の標準調査工程を「repo / docs / tickets / logs / web」の順に変更する。
  - `Lightweight / Standard / Strict` の条件、必須 artifact、検証期待値を `template/AGENTS.md` と planning reference に明記する。
  - Standard 以上では run artifact を使うが、review-only では `docs/reports/` へ保存しない。
- onboarding:
  - `init-project.ps1/.sh` と `codex-project.toml` を追加する。
  - 初期化対象は project type、main language、verify command、quality gates、forbidden zones、docs owner、default mode、run retention とする。
  - `sync-template` はコピー、`init-project` は consumer repo 初期化として役割を分離する。

## 6. Validation Plan
- 実装後に必ず実行する検証:
  - `bash tools/validate-spec.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
  - `bash tests/smoke/test-template-layout.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1`
  - `bash tests/integration/test-codex-task-harness.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1`
  - `bash tests/integration/test-codex-safety-harness.sh`
- 追加する検証:
  - `codex execpolicy check` で deletion command が forbidden になることを bash / PowerShell の harness test で確認する。
  - wrapper test で通常の `git rm <path>` が blocked、`git rm --cached -- <tracked artifact>` が explicit migration path として扱われることを確認する。
  - `template/.codex/config.toml` が `workspace-write`, `untrusted`, `network_access = false`, `web_search = "cached"` を含むことを spec validation で確認する。
  - `template/.codex/requirements.toml` の links が `docs/reference/codex-safety-harness.md` と `docs/reference/codex-implementation-harness.md` だけを指すことを spec validation で確認する。
  - review workflow が明示的な調査・保存依頼なしに `docs/reports/` を作らないことを smoke test の sentinel phrase で確認する。
  - report file generation policy の Allowed / Not allowed / 保存先 / 迷った場合の扱いが `template/AGENTS.md`, `template/CODE_REVIEW.md`, review reference, root `CODE_REVIEW.md`, `spec/routing.yaml` に含まれることを検証する。
- 成功条件:
  - consumer template に tracked 実行成果物が残らない。
  - fake codex だけで bash / PowerShell の主要検証が通る。
  - `--run-id` 指定時、wrapper 成果物が同一 run 配下へ集約される。
  - review-only の既定動作として `docs/reports/` / `maintainers/reports/` への新規ファイル生成が要求されない。
  - `reports/` file は明示保存依頼、計画 DoD、durable 調査・監査・検証結果のいずれかに該当する場合だけ生成される contract になる。
  - project 配下の file read/write は標準運用で可能だが、deletion command は forbidden として検証される。
  - `apply_patch` は許可された編集手段として維持される。
  - `spec/`、template docs、scripts、tests が同じ contract を表す。
  - 実行できない live 検証がある場合は report とユーザー向け報告に理由を明記する。

## 7. Migration / Rollback
- Migration:
  - 既存の `.codex/artifacts`, `.codex/reports`, `.codex/logs` 出力は後方互換として残す。
  - 新規利用では `--run-id` を推奨し、docs / examples は run-first を標準にする。
  - report JSON の新キーは追加のみとし、既存キーは削除しない。
  - runtime artifact の配布対象外化は filesystem delete ではなく index-only untrack と `.gitignore` 追加で実現する。
  - review report 生成抑制は docs / skills / spec の contract 変更であり、既存の明示的な report 保存運用は残す。
  - `reports/` 生成ルールは既存の明示的な調査レポート保存を壊さず、review-only と routine progress の自動保存だけを抑制する。
- Rollback:
  - run-first 変更で問題が出た場合は、`--run-id` 未指定時の既存出力先へ戻せる。
  - `config.toml` 変更で運用に支障が出た場合は、`repo_safe` profile のみを旧値へ戻し、rules / docs の削除禁止は維持する。
  - init-project が不安定な場合は、配布テンプレ清潔化と検証 self-contained 化だけを残して init-project を延期する。

## 8. Risks / Open Issues
- `codex-task.ps1/.sh` と `codex-safe.ps1/.sh` の bash / PowerShell parity が崩れるリスクがある。
- report JSON のキー追加により、既存の downstream checker が厳格な `additionalProperties=false` を持つ場合に影響する可能性がある。
- `init-project` は設計範囲が広がりやすいため、初版では manifest と PROJECT_CONTEXT 初期化に絞る。
- `workspace-write` は command-based deletion を禁止できないため、rules / wrapper / instructions / tests の多層防御を必須にする。
- `approval_policy = "untrusted"` は file edit と実用性のバランスは良いが、完全な deletion prevention ではない。実装時は deletion command の forbidden test を必須にする。
- `apply_patch` は許可するため、レビュー時は command deletion と patch editing を混同しない。
- branch / dirty tree guard、cleanup / archive、security / data handling guide、project type overlay、output validator 拡張は有用だが、同時実装すると大きくなりすぎるため後続計画に分離する。

## 9. 保存先
- Source-repo plan:
  - `maintainers/plans/2026-04-20_220233_operations-quality-hardening.md`
- 実装時 run:
  - `.codex/runs/20260420-220233-JST/`
