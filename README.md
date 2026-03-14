# codex-templates v2 Source Repository

このリポジトリは consumer repo へ配布する Codex 運用テンプレートの source repository です。利用者が直接読む面は [`template/`](template) に集約し、root は template 自体の保守・仕様・検証を担います。

## 使い分け
- consumer-facing template: [`template/`](template)
- source repo の運用記録と意思決定: [`maintainers/`](maintainers)
- 単一正本の仕様: [`spec/`](spec)
- source repo 向け補助ツール: [`tools/`](tools)
- source repo 向け検証: [`tests/`](tests)
- 例示資産: [`examples/`](examples)

## Consumer への配布
1. `template/` の内容を新規 repo のルートへ展開する。
2. もしくは `tools/sync-template.*` で別ディレクトリへ同期する。
3. consumer repo 側では `template/AGENTS.md` 相当の内容が repo ルートにある前提で運用する。

## Maintainer ワークフロー
1. root [`AGENTS.md`](AGENTS.md) に従って source repo を更新する。
2. consumer-facing ルールを変えるときは `spec/` を先に更新する。
3. `tools/validate-spec.*` と `tests/` を通してから完了報告する。

## 関連文書
- 移行案内: [`MIGRATION.md`](MIGRATION.md)
- source repo 文脈: [`maintainers/PROJECT_CONTEXT.md`](maintainers/PROJECT_CONTEXT.md)
- consumer 向け quickstart: [`template/docs/guides/quickstart.md`](template/docs/guides/quickstart.md)
- consumer 向け safety harness: [`template/docs/reference/codex-safety-harness.md`](template/docs/reference/codex-safety-harness.md)
