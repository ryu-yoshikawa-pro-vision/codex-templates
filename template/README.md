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
- `docs/plans/`: ユーザー向け計画書の保存先
- `docs/reports/`: durable な調査・監査・検証レポートの保存先（review-only や run progress では作らない）
- `scripts/`: manual / task / sandbox wrapper と consumer-facing verify
- `codex-project.toml`, `scripts/init-project.*`: template 適用後の初期化補助

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

## Execution modes
このテンプレートの project-level default は safe のままです。通常起動と wrapper の既定では `workspace-write`、`approval_policy = "untrusted"`、workspace network disabled を使います。

ネットワークアクセスつきの自律的な workspace 内作業が必要な場合だけ、管理された `auto-net` preset を明示します。

```bash
bash scripts/codex-safe.sh --preset auto-net
bash scripts/codex-task.sh --preset auto-net --prompt-file .codex/runs/<run_id>/PROMPT.md
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -Preset auto-net
powershell -ExecutionPolicy Bypass -File scripts/codex-task.ps1 --preset auto-net --prompt-file .codex/runs/<run_id>/PROMPT.md
```

`auto-net` は `workspace-write`、approval prompts disabled、workspace network enabled、削除・破壊操作 forbidden の preset です。`--full-auto`、`danger-full-access`、`--dangerously-bypass-approvals-and-sandbox` は使いません。

`auto-net` の remote script piping や delete / rename patch は `.codex/hooks/pre_tool_use_policy.ps1` でも検出します。hooks 非対応または `pwsh` 不在の環境では、shell wrapper 系を forbidden にする execpolicy rules が主な fallback です。
