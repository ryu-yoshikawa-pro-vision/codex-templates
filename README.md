# codex-templates v2 Source Repository

このリポジトリは consumer repo へ配布する Codex 運用テンプレートの source repository です。利用者が直接読む面は [`template/`](template) に集約し、root は template 自体の保守・仕様・検証を担います。

## 使い分け
- consumer-facing template: [`template/`](template)
- source repo の運用記録と意思決定: [`maintainers/`](maintainers)
- 単一正本の仕様: [`spec/`](spec)
- source repo 向け補助ツール: [`tools/`](tools)
- source repo 向け検証: [`tests/`](tests)
- 例示資産: [`examples/`](examples)

## できること / できないこと

| できること | できないこと |
| --- | --- |
| Codex の作業ルール、計画、レビュー、実行記録を標準化する | 何もしなくても完全自律運用を保証する |
| `safe` / `readonly` / `auto-net` の使い分けを定義する | `danger-full-access` や raw `--full-auto` 前提で高速化する |
| wrapper、execpolicy rules、hook による安全補助を提供する | hook だけで破壊的操作を完全防御する |
| consumer repo に展開できるテンプレート一式を提供する | consumer 固有の `docs/PROJECT_CONTEXT.md` を自動で正しく埋める |
| source repo 側で spec と validation により template 契約を検証する | 人間レビューなしで安全な実装・配布を保証する |

## 最短導入手順

新規 consumer repo へ導入する場合は、まず次の順で進めます。

1. `template/` の内容を対象 repo のルートへコピーする。
2. `scripts/init-project.*` を実行して、必要なディレクトリと初期 metadata を作る。
3. `docs/PROJECT_CONTEXT.md` を対象プロジェクト向けに更新する。
4. `bash scripts/verify` または `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` を実行する。
5. Codex に repo ルートの `AGENTS.md` を読ませ、依頼内容に応じて `PLANS.md` / `CODE_REVIEW.md` を使う。

## Consumer への配布
1. `template/` の内容を新規 repo のルートへ展開する。
2. もしくは `tools/sync-template.*` で別ディレクトリへ同期する。
3. consumer repo 側では `template/AGENTS.md` 相当の内容が repo ルートにある前提で運用する。

## 既存 consumer repo の更新手順

既存 repo へ template 更新を反映する場合は、新規導入より慎重に扱います。

1. consumer repo 側の現在の `template_version` を確認する。
2. [`CHANGELOG.md`](CHANGELOG.md) と [`MIGRATION.md`](MIGRATION.md) を確認する。
3. consumer repo 側で作業ブランチを切る。
4. `tools/sync-template.*` を使う場合は、まず dry-run で削除対象を確認する。
   - Bash: `tools/sync-template.sh --dry-run --force <destination>`
   - PowerShell: `powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination <destination> -Force -DryRun`
5. dry-run の削除対象が想定通りの場合だけ、明示確認フラグ付きで同期する。
   - Bash: `tools/sync-template.sh --force --confirm-destructive-overwrite <destination>`
   - PowerShell: `powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination <destination> -Force -ConfirmDestructiveOverwrite`
6. `docs/PROJECT_CONTEXT.md`、`docs/adr/`、`docs/plans/`、`docs/reports/` など consumer 固有ファイルは機械的に上書きしない。
7. `bash scripts/verify` または PowerShell 版 verify を実行する。
8. PR で差分をレビューし、運用ルールや安全制約が consumer repo の実態と矛盾しないことを確認する。

## sync-template safety

`tools/sync-template.*` で既存ディレクトリへ同期すると、同期先の top-level contents を置き換えるため、誤った destination を指定すると重要ファイルを失うリスクがあります。

- `--dry-run` / `-DryRun` で必ず削除対象を確認する。
- 既存 destination に `--force` / `-Force` だけでは同期しない。
- destructive overwrite には `--confirm-destructive-overwrite` / `-ConfirmDestructiveOverwrite` を追加する。
- consumer 固有ファイルを残す必要がある場合は、直接同期ではなく別ディレクトリに同期して差分を手動反映する。

## auto-net の利用条件

`auto-net` は外部通信や依存解決が必要なときだけ明示的に使います。通常の文書修正、静的調査、PRレビューでは `safe` または `readonly` を使います。

`auto-net` でも削除、rename、git add/commit/push/rm、dangerous bypass は許可しません。外部通信が必要な調査・検証でも、不要ファイルは削除せず `REPORT.md` に削除候補として記録します。

## Maintainer ワークフロー
1. root [`AGENTS.md`](AGENTS.md) に従って source repo を更新する。
2. consumer-facing ルールを変えるときは `spec/` を先に更新する。
3. `tools/validate-spec.*` と `tests/` を通してから完了報告する。

## Versioning

配布テンプレートの変更は [`CHANGELOG.md`](CHANGELOG.md) に記録します。`template/codex-project.toml` の `template_version` は、consumer-facing contract の変更に合わせて更新します。

- Major: 既存 consumer repo の運用や配置に破壊的変更がある。
- Minor: consumer-facing file、workflow、safety rule、配布手順を追加・拡張する。
- Patch: 誤字、説明補足、validator の非破壊的修正、内部メンテナンス。

## 関連文書
- 変更履歴: [`CHANGELOG.md`](CHANGELOG.md)
- 移行案内: [`MIGRATION.md`](MIGRATION.md)
- source repo 文脈: [`maintainers/PROJECT_CONTEXT.md`](maintainers/PROJECT_CONTEXT.md)
- consumer 向け quickstart: [`template/docs/guides/quickstart.md`](template/docs/guides/quickstart.md)
- consumer 向け safety harness: [`template/docs/reference/codex-safety-harness.md`](template/docs/reference/codex-safety-harness.md)
