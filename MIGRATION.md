# codex-templates v1 -> v2 Migration

## 方針
- v2 は破壊的変更です。旧パス互換は提供しません。
- consumer-facing の公開面は `template/` 配下のみです。

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
2. もしくは `tools/sync-template.ps1 -Force` / `tools/sync-template.sh --force` を使って同期する。
3. 展開先 repo では `template/` プレフィックスを外した状態で運用する。

## Source repo の確認ポイント
- root `AGENTS.md` は source repo メンテナンス用に変わっています。
- consumer-facing 変更時は `spec/` と `template/` を両方更新してください。
- consumer-facing では `template/docs/agent/` を前提にしません。`template/AGENTS.md` と `template/.agents/skills/*` が正本です。
- historical docs 内の旧パス参照は当時の記録として残っています。
