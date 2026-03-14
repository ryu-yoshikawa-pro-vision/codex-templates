# ADR 0007: consumer template を Codex 公式整合の instruction / skill layout へ移行する

## Status
- Accepted

## Context
- これまでの consumer-facing template は `template/docs/agent/` を詳細手順の正本、`.agents/skills/` を補助導線として持っていた。
- その結果、`AGENTS.md`、mode 別入口、`docs/agent/`、skill 定義の4点で同一ルールを保守する必要があり、導線と契約が分散していた。
- 2026-03-14 時点の OpenAI 公式 Codex docs では、`AGENTS.md` は常設 instruction surface、`.agents/skills/` は progressive disclosure で読む task-scoped workflow、`.codex/` は config/runtime として整理されている。

## Decision
- consumer-facing template では `AGENTS.md` を唯一の常設 instruction surface とする。
- `template/.agents/skills/` を planning / review workflow の正本とし、詳細手順は `references/` 配下に置く。
- `PLANS.md` と `CODE_REVIEW.md` は skill へ誘導する薄い索引として維持する。
- `template/docs/agent/` は廃止し、必要な人間向け補助資料のみ `template/docs/reference/` または `template/docs/guides/` に再配置する。
- `template/.codex/` は引き続き config/runtime 用ディレクトリとし、`.codex/agents/` のような独自 discovery path は導入しない。

## Consequences
- consumer-facing contract は `AGENTS.md` + `.agents/skills/` + `.codex/` + `docs/reference/` の4層に整理される。
- `docs/agent/` に依存した spec / verify / smoke tests / docs の一括更新が必要になる。
- ADR 0004 の「`docs/agent/` を正本として維持する」判断は consumer-facing template について superseded される。
