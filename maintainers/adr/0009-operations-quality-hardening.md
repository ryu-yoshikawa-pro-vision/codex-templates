# ADR 0009: Operations quality hardening for reports, deletion safety, and run artifacts

## Status
Accepted

## Context
レビューだけで `reports/` にファイルを生成すると、durable な調査・監査・検証結果と一時的な会話結果が混ざる。加えて、consumer template には safe baseline の `config.toml`、command-based deletion の明確な禁止、run-local artifact への集約が不足していた。

## Decision
- `reports/` file は、明示保存依頼、計画 DoD、durable な調査・監査・検証結果のいずれかに該当する場合だけ生成する。
- review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録では `reports/` にファイルを作らない。
- command-based deletion を禁止し、`apply_patch` は差分単位で確認できる編集手段として許可する。
- `template/.codex/config.toml` は `workspace-write`、`untrusted`、`web_search = "cached"`、workspace network disabled を baseline とする。
- `codex-safe.*` / `codex-task.*` は `--run-id` / `-RunId` を受け取り、run がある作業では `.codex/runs/<run_id>/artifacts|reports|logs` へ出力を集約する。
- runtime artifact は配布対象外にし、既存 tracked artifact は `git rm --cached -- <path>` の index-only migration で外す。

## Consequences
- レビュー結果はチャット返答を既定にでき、`reports/` の意味が保たれる。
- file write は実用性を保ちつつ、削除は instructions / execpolicy / wrapper / tests の複数層で抑制される。
- downstream が旧 `.codex/artifacts` / `.codex/reports` を参照している場合のため、明示 path override は後方互換として維持する。
