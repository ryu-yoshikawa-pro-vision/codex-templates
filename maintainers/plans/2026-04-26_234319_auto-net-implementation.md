# auto-net 実装計画

## spec/ 影響
- あり。`spec/safety-policy.yaml` と `spec/workflow.yaml` に `auto-net` preset、safe default、削除禁止、preset別 rules の契約を反映する。

## Goal
- `inputs/2026-04-26/codex_templates_full_auto_network_revision_plan.md` に沿って、危険な full access ではなく、明示指定された `auto-net` preset で workspace-write、approval never、network access true、削除禁止を実現する。

## Current understanding
- top-level project config は safe baseline のまま維持する。
- `codex-safe.*` と `codex-task.*` の既定 preset は `safe` のまま維持する。
- `auto-net` は `repo_auto_net` profile と preset 別 rules で有効化する。
- global rules は safe 寄りに維持し、auto-net 専用 rules は別ディレクトリで追加する。

## Assumptions
- Phase 1 と Phase 2 の hook 追加までを今回実装する。
- hook config は experimental として文書化し、consumer-facing required contract にはしない。
- examples / migration の大規模拡張は、主要 contract・wrapper・tests・docs の完了後に必要最小限とする。

## Source-repo changes
- run artifact を実装タスク用に更新する。
- 必要なら `maintainers/adr/` に auto-net preset の設計判断を追加する。
- `maintainers/PROJECT_CONTEXT.md` は構造理解が変わった場合のみ更新する。

## Consumer-facing changes
- `template/.codex/config.toml` に `repo_auto_net` profile を追加する。
- `template/.codex/rules-auto-net/` を追加し、auto-net 専用 allow / forbidden rules を分離する。
- `template/.codex/rules/30-destructive-forbidden.rules` を強化する。
- `template/scripts/codex-safe.*` と `template/scripts/codex-task.*` に `auto-net` preset、profile 注入、preset別 preflight / rule resolution を追加する。
- `template/.codex/hooks/pre_tool_use_policy.py` を追加し、削除・破壊操作の補助検出を実装する。
- `template/AGENTS.md`、`template/README.md`、reference docs を更新する。

## Validation plan
- `bash tools/validate-spec.sh`
- `bash template/scripts/verify`
- `bash tests/smoke/test-template-layout.sh`
- `bash tests/integration/test-codex-safety-harness.sh`
- `bash tests/integration/test-codex-task-harness.sh`
- 可能なら PowerShell 系検証も実行する。

## Migration / rollback
- `auto-net` は明示 preset なので、rollback は `repo_auto_net` profile、rules-auto-net、wrapper の auto-net branch、docs/spec の該当記述を戻す。
- top-level safe baseline は維持するため、通常起動の挙動変更は最小化される。

## Risks / open issues
- Codex CLI hooks の matcher / config 読み込みはバージョン依存の可能性がある。hook は補助ガードとして扱う。
- `approval_policy = never` では prompt decision が運用上曖昧なため、auto-net 専用 preflight では allow / forbidden に寄せる。
