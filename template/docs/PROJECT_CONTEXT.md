# Project Context

## 目的
- このリポジトリで Codex を使うときの運用前提、重要な制約、主要ディレクトリを共有する。

## 運用の要点
- `AGENTS.md` の読込順と run 運用を必ず守る。
- 計画依頼では `docs/plans/TEMPLATE.md` をベースに計画書を作る。
- 調査や実行ログは `docs/reports/` に残す。
- 重要な意思決定は `docs/adr/` に記録する。
- `docs/PROJECT_CONTEXT.md` 自体は living document として更新し、履歴は `docs/history/` に残す。

## ディレクトリ構成
- `.codex/templates/`: PLAN / TASKS / REPORT の run テンプレート
- `.codex/rules/`: execpolicy ルール
- `.agents/skills/`: repo-local の planning / review workflow と references
- `docs/plans/`: ユーザー向け計画書
- `docs/reports/`: 調査・実行レポート
- `docs/reference/`: operator / maintainer 向け補助資料
- `scripts/`: `codex-safe` / `codex-task` / `codex-sandbox` と verify

## メモ
- この文書はプロジェクト固有の実態に合わせて上書きしてよい。
- 標準経路は host 上の `codex-safe` / `codex-task`。Docker sandbox は experimental かつ opt-in。
