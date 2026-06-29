# codex-templates v1 -> v2 Migration

## 方針
- v2 は破壊的変更です。旧パス互換は提供しません。
- consumer-facing の公開面は `template/` 配下のみです。

## 0.11.0 - 2026-06-29

- Existing consumer repos can keep using normal `scripts/verify`.
- Maintainers should run `bash template/scripts/verify --strict-harness` または `powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness` before distributing template updates.
- Use `bash scripts/cleanup-runs.sh --dry-run` または `powershell -ExecutionPolicy Bypass -File scripts/cleanup-runs.ps1 -DryRun` first. cleanup は明示確認なしでは削除しない。
- Use `tools/plan-consumer-update.*` before direct `sync-template`.
- No required manual migration unless the consumer repo wants to adopt cleanup / strict verification / update planning commands.
- Do not overwrite protected paths such as `docs/PROJECT_CONTEXT.md`, `docs/adr/`, `docs/plans/`, `docs/reports/`, `docs/history/`, `.codex/runs/`, `.env*`.

## 主な移行
| 旧パス | 新パス | 用途 |
| --- | --- | --- |
| `AGENTS.md` | `template/AGENTS.md` | consumer repo へ配布する入口 |
| `PLANS.md` | `template/PLANS.md` | consumer repo の planning 入口 |
| `CODE_REVIEW.md` | `template/CODE_REVIEW.md` | consumer repo の review 入口 |
| `.codex/templates/*` | `template/.codex/templates/*` | consumer repo の run テンプレート |
| `.codex/rules/*` | `template/.codex/rules/*` | consumer repo の execpolicy ルール |
| `.agents/skills/*` | `template/.agents/skills/*` | consumer repo の repo-local skills |
| `docs/agent/overrides.md` | `template/AGENTS.md` | consumer repo の常設 instruction surface |
| `docs/agent/agent-role-design.md`, `docs/agent/templates/*` | `template/.agents/skills/*/references/*` | skill ごとの詳細 workflow |
| `docs/agent/codex-safety-harness.md` | `template/docs/reference/codex-safety-harness.md` | operator 向け安全ハーネス案内 |
| `docs/agent/improvement-guardrails.md` | `template/AGENTS.md` | 改善提案の承認境界 |
| `docs/agent/skill-discovery-workflow.md` | 廃止 | 常設 instruction から外し、consumer template には含めない |
| `docs/plans/*` | `template/docs/plans/*` と `maintainers/plans/*` | consumer 雛形と source repo 計画書を分離 |
| `docs/reports/*` | `template/docs/reports/*` と `maintainers/reports/*` | consumer 雛形と source repo レポートを分離 |
| `docs/PROJECT_CONTEXT.md` | `template/docs/PROJECT_CONTEXT.md` と `maintainers/PROJECT_CONTEXT.md` | consumer 雛形と source repo 文脈を分離 |
| `docs/adr/*` | `maintainers/adr/*` | source repo の ADR |
| `docs/history/*` | `maintainers/history/*` | source repo の履歴 |
| `scripts/codex-safe.*` | `template/scripts/codex-safe.*` | consumer-facing wrapper |
| `scripts/verify` | `template/scripts/verify` | consumer-facing verify |
| `scripts/tests/*` | `tests/integration/*` | source repo integration tests |
| `docs/*` の運用正本 | `spec/*` | source repo の contract 定義 |

## Consumer repo の作り方
1. `template/` の中身を新規 repo のルートへ展開する。
2. 既存 repo へ同期する場合は、まず dry-run で削除対象を確認する。
   - Bash: `tools/sync-template.sh --dry-run --force <destination>`
   - PowerShell: `powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination <destination> -Force -DryRun`
3. dry-run の削除対象が想定通りの場合だけ、明示確認フラグ付きで同期する。
   - Bash: `tools/sync-template.sh --force --confirm-destructive-overwrite <destination>`
   - PowerShell: `powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination <destination> -Force -ConfirmDestructiveOverwrite`
4. 展開先 repo では `template/` プレフィックスを外した状態で運用する。
5. `docs/PROJECT_CONTEXT.md`、`docs/adr/`、`docs/plans/`、`docs/reports/`、`.codex/runs/` など consumer 固有情報は機械的に上書きしない。

## Source repo の確認ポイント
- root `AGENTS.md` は source repo メンテナンス用に変わっています。
- consumer-facing 変更時は `spec/` と `template/` を両方更新してください。
- consumer-facing では `template/docs/agent/` を前提にしません。`template/AGENTS.md` と `template/.agents/skills/*` が正本です。
- historical docs 内の旧パス参照は当時の記録として残っています。

## Harness usability update の取り込み

- `scripts/new-run.sh` と `scripts/new-run.ps1` を追加し、run 初期化は手動コピーより script 利用を推奨する。
- `scripts/codex-task.sh` と `scripts/codex-task.ps1` は `allowed-dirs`、`allowed-globs`、`expected-missing warn|fail` をサポートする。
- `.codex/templates/RUN_MANIFEST.json` と `spec/run-manifest.schema.json` は `validation.warnings` と `passed_with_warnings` を扱う。
- `AGENTS.md`、`PLANS.md`、`docs/reference/codex-implementation-harness.md`、`docs/reference/change-scope-policy.md`、`docs/guides/quickstart.md` も一緒に同期する。
