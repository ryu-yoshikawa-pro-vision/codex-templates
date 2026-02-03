# Project Context

## 目的
- Codexが多様なタスクを実行する際に、計画（PLAN）→タスク（TASKS）→行動ログ（REPORT）を厳密に運用できるようテンプレートと規約を整備する。

## 運用の要点
- セッション開始時に `.codex/runs/<run_id>/` を作成し、テンプレートをコピーする。
- 思考や判断理由は PLAN の Thinking Log に追記する。
- 実装・調査などの行動ログは REPORT に逐次追記する。
- 追加タスクは TASKS の Discovered に追記する。
- `docs/PROJECT_CONTEXT.md` は各プロジェクトの実態に合わせて調整し、開発の進行に伴って更新し続ける。

## ディレクトリ構成
- `.codex/templates/`: PLAN/TASKS/REPORT のテンプレート
- `.codex/runs/`: セッションごとの実行ログ
- `docs/adr/`: 運用や方針の意思決定記録
