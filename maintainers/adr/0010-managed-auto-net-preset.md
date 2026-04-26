# ADR 0010: Managed auto-net preset with safe defaults

## Status
Accepted

## Context
開発効率のため、workspace 内編集と network access を承認なしで実行できる mode が必要になった。一方で `danger-full-access` や raw `--full-auto` は workspace 外書き込みや破壊操作の誤用リスクが大きく、既存の safe baseline と矛盾する。

## Decision
- project config の top-level default は `workspace-write`、`approval_policy = "untrusted"`、workspace network disabled の safe baseline として維持する。
- 明示指定専用の `auto-net` preset を追加し、`repo_auto_net` profile で `workspace-write`、`approval_policy = "never"`、workspace network enabled、`writable_roots = []` を使う。
- `codex-safe.*` と `codex-task.*` の既定 preset は `safe` のまま維持する。
- global execpolicy rules は safe 寄りに維持し、auto-net 用 allow/forbidden rules は `.codex/rules-auto-net/` に分離する。
- 削除、git staging/commit/push/rm/reset/clean、remote script piping、外部 resource deletion は auto-net でも forbidden とする。
- PreToolUse hook は補助防御として追加するが、CLI version 依存のため唯一の安全境界にはしない。

## Consequences
- 通常起動と既定 wrapper 実行は従来通り安全側に保たれる。
- 明示的な `--preset auto-net` でのみ network access と approval never が有効になる。
- preset 別 preflight と tests により、safe と auto-net の期待値を分離して検証できる。
