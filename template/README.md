# Codex Project Template

このテンプレートは、Codex を使った開発を `PLAN -> TASKS -> REPORT` の運用で始めるための最小セットです。

## 使い方
1. このディレクトリの内容を新規 repo のルートへ配置する。
2. 最初の依頼から `AGENTS.md` に従って `.codex/runs/<run_id>/` を作成する。
3. `docs/PROJECT_CONTEXT.md` をそのプロジェクトの実態に合わせて更新し続ける。

## 含まれるもの
- `AGENTS.md`, `PLANS.md`, `CODE_REVIEW.md`: Codex の入口
- `.codex/templates/`: run 初期化テンプレート
- `.codex/rules/`: execpolicy ルール
- `.agents/skills/`: repo-local の task-specific workflow と references
- `docs/reference/`: 人間向けの補助ガイド
- `docs/plans/`, `docs/reports/`: ユーザー向け成果物の保存先
- `scripts/`: manual / task / sandbox wrapper と consumer-facing verify

## 最初に読むもの
- `AGENTS.md`
- `docs/PROJECT_CONTEXT.md`
- `docs/guides/quickstart.md`
- `docs/reference/repository-layout.md`

## 検証
- bash: `bash scripts/verify`
- PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`

## Codex 実行ハーネス
- 手動対話: `scripts/codex-safe.ps1` / `scripts/codex-safe.sh`
- 非対話タスク: `scripts/codex-task.ps1` / `scripts/codex-task.sh`
- Docker sandbox 実験: `scripts/codex-sandbox.ps1` / `scripts/codex-sandbox.sh`
- 詳細: `docs/reference/codex-implementation-harness.md`
