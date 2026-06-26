# Quickstart

## 新規 consumer repo への導入

1. `template/` の内容を対象 repo のルートへコピーする。
2. `scripts/init-project.*` を実行し、`.codex/runs/`、`docs/adr/`、`docs/history/`、`docs/plans/`、`docs/reports/` などの初期ディレクトリを作る。
3. `AGENTS.md` を読む。
4. `docs/PROJECT_CONTEXT.md` をそのプロジェクト用に更新する。
5. `bash scripts/verify` または `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` を実行して最低限のセットアップを確認する。
6. 最初の依頼で `.codex/runs/<run_id>/` を作る。
7. 計画系は `PLANS.md`、レビュー系は `CODE_REVIEW.md` から対応 skill を開く。

## 最初に編集すること

- プロジェクトの目的
- ディレクトリ構造
- 品質ゲート
- 安全制約
- よく使う検証コマンド
- 外部通信や認証が必要な作業の扱い

## 既存 consumer repo の更新

既存 repo へ template 更新を取り込む場合は、consumer 固有情報を守ることを優先する。

1. 現在の `template/codex-project.toml` または repo 内 metadata から `template_version` を確認する。
2. source repo の `CHANGELOG.md` と `MIGRATION.md` を確認する。
3. consumer repo 側で更新用ブランチを切る。
4. template 差分を同期する。
5. `docs/PROJECT_CONTEXT.md`、`docs/adr/`、`docs/plans/`、`docs/reports/`、`.codex/runs/` は機械的に上書きしない。
6. `bash scripts/verify` または PowerShell 版 verify を実行する。
7. PR で差分を確認し、プロジェクト固有の運用・品質ゲート・安全制約が失われていないことをレビューする。

## mode 選択の目安

| 作業 | 推奨 mode |
| --- | --- |
| ドキュメント確認、PRレビュー、静的調査 | `readonly` または `safe` |
| 通常の実装・文書更新 | `safe` |
| 外部通信、依存解決、ネットワークが必要な検証 | 明示的に `auto-net` |
| 削除、rename、git add/commit/push/rm | Codex に実行させない |

`auto-net` は通常作業の既定値ではない。外部通信が必要な場合だけ明示的に使う。
