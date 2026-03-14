# ADR 0004: mode別入口ファイルと repoローカルSkillの導入

## Status
- Accepted

## Context
- `docs/agent/` 配下には役割設計とテンプレートがあるが、Plan Mode や review 要求時にどの文書を優先的に参照すべきかが `AGENTS.md` から明示されていなかった。
- `.agent/` への全面移行は、Codex の自動発見上の利点が確認できず、既存参照の更新コストが高い。
- planning / review の反復ワークフローを repo 内で再利用する仕組みが不足していた。

## Decision
- `docs/agent/` は役割設計と詳細手順の正本として維持する。
- repo ルートに `PLANS.md` と `CODE_REVIEW.md` を追加し、Codex の mode別入口として `AGENTS.md` から明示的に参照する。
- repo ローカルの反復 planning / review ワークフローは `.agents/skills/` に Skill として追加する。
- Skill の暗黙起動だけに依存せず、必須導線は `AGENTS.md` の明示ルーティングで担保する。

## Consequences
- Plan Mode と review 要求で参照すべき入口が明確になり、役割テンプレートまでの導線が短くなる。
- `docs/agent/` を維持するため既存文書との整合を保ちやすい。
- `AGENTS.md`、入口ファイル、`docs/agent/`、Skill 定義の4点でルール整合を保守する必要がある。
