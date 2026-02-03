# Codex Templates Repository

このリポジトリは、Codexを使った作業を「計画 → タスク → 行動ログ」の順に整理し、再現性と追跡性を高めるためのテンプレート集です。

## 目的
- セッション内の意思決定や作業履歴を一貫した形式で残す
- 追加タスクや判断理由を追跡できるようにする
- Codex運用に必要な最小限のルールを統一する

## 使い方（概要）
1. `AGENTS.md` の手順に従い、`.codex/runs/<run_id>/` を作成する
2. `.codex/templates/` から PLAN/TASKS/REPORT をコピーする
3. 作業中は以下の運用ルールを守る
   - 思考や判断理由は PLAN の Thinking Log に追記する
   - 実行ログは REPORT に逐次追記する
   - 追加タスクは TASKS の Discovered に追記する

## 重要な運用ルール
- `docs/PROJECT_CONTEXT.md` は各プロジェクトの実態に合わせて調整し、開発の進行に伴って更新し続ける
- 重要な意思決定は `docs/adr/` に ADR として記録する

## ディレクトリ構成
- `.codex/templates/`: PLAN/TASKS/REPORT のテンプレート
- `.codex/runs/`: セッションごとの実行ログ
- `docs/PROJECT_CONTEXT.md`: プロジェクトの状況や運用方針の記録
- `docs/adr/`: アーキテクチャや運用方針の決定記録

## 参考
- 詳細な運用ルールは `AGENTS.md` を参照してください。
