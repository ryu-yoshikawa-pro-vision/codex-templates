# ADR 0008: Codex 実装ハーネスを手動対話 / 非対話 / Docker 実験の 3 層へ分離する

## Status
- Accepted

## Context
- 既存 template の `codex-safe` は、手動対話での危険引数拒否、preflight、logging には有効だった。
- 一方で `codex exec` を使う非対話実装では、output file、schema check、post-run verify、report JSON をまとめて扱う入口がなかった。
- Docker による外部隔離実行は有用だが、Codex CLI 自体は Docker runtime を直接提供していないため、repo-local の運用判断が必要だった。

## Decision
- `scripts/codex-safe.*` は手動対話用の安全 wrapper として維持する。
- `scripts/codex-task.*` を追加し、`preflight -> codex exec -> output/schema check -> verify -> report` の非対話実装フローを提供する。
- `scripts/codex-sandbox.*` を追加し、`codex-task --runtime docker-sandbox` の薄い wrapper として提供する。
- Docker runtime は `CODEX_DOCKER_IMAGE` 必須の opt-in experimental path とし、host fallback はしない。

## Consequences
- 手動対話、CI 補助、外部隔離実行を異なる入口で明確に運用できる。
- 非対話実装では machine-readable report JSON を成果物として標準化できる。
- Docker runtime は導入前提が多いため、利用者は image / auth / mount を自分で明示設定する必要がある。
