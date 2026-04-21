# Project Context

## 目的
- このリポジトリで Codex を使うときの運用前提、重要な制約、主要ディレクトリを共有する。

## 運用の要点
- `AGENTS.md` の読込順と run 運用を必ず守る。
- 計画依頼では `docs/plans/TEMPLATE.md` をベースに計画書を作る。
- `docs/reports/` は durable な調査・監査・検証結果だけに使う。review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録では作らない。
- run の進捗と実行ログは `.codex/runs/<run_id>/REPORT.md` と `.codex/runs/<run_id>/logs/` に残す。
- プロジェクト配下の読み書きは通常承認なしでよいが、shell / PowerShell / git command によるファイル削除は禁止する。意図した差分としての `apply_patch` は許可する。
- 重要な意思決定は `docs/adr/` に記録する。
- `docs/PROJECT_CONTEXT.md` 自体は living document として更新し、履歴は `docs/history/` に残す。

## ディレクトリ構成
- `.codex/templates/`: PLAN / TASKS / REPORT の run テンプレート
- `.codex/rules/`: execpolicy ルール
- `.agents/skills/`: repo-local の planning / review workflow と references
- `docs/plans/`: ユーザー向け計画書
- `docs/reports/`: durable な調査・監査・検証レポート
- `docs/reference/`: operator / maintainer 向け補助資料
- `scripts/`: `codex-safe` / `codex-task` / `codex-sandbox` と verify
- `codex-project.toml`: template 適用後の project metadata

## メモ
- この文書はプロジェクト固有の実態に合わせて上書きしてよい。
- 標準経路は host 上の `codex-safe` / `codex-task --run-id <run_id>`。Docker sandbox は experimental かつ opt-in。
