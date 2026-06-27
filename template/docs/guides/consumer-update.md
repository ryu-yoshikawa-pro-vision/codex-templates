# Consumer repo 更新ガイド

既存 consumer repo に template 更新を取り込むときは、consumer 固有情報を守ることを最優先にする。`sync-template` は便利だが、既存 destination の top-level contents を置き換えるため、使い方を誤るとプロジェクト固有ファイルを失う。

## 原則

- 更新用ブランチを切ってから作業する。
- まず `CHANGELOG.md` と `MIGRATION.md` を読む。
- `docs/PROJECT_CONTEXT.md`、`docs/adr/`、`docs/plans/`、`docs/reports/`、`.codex/runs/` は機械的に上書きしない。
- 既存 repo に直接同期する前に、必ず dry-run を実行する。
- 不安がある場合は、一時ディレクトリに同期して差分を手動反映する。

## 推奨フロー

1. consumer repo 側で更新用ブランチを切る。
2. 現在の `template_version` を確認する。
3. source repo の `CHANGELOG.md` と `MIGRATION.md` を確認する。
4. 一時ディレクトリへ同期する。
5. consumer 固有ファイルを除外しながら差分を確認する。
6. 必要な template 差分だけを consumer repo へ反映する。
7. `bash scripts/verify` または PowerShell 版 verify を実行する。
8. PRで差分をレビューする。

## 一時ディレクトリ同期の例

一時ディレクトリへ同期する場合も、削除して作り直すのではなく、毎回ユニークな未作成ディレクトリを使う。これにより `--force` / `-Force` や削除コマンドを使わずに安全に差分確認できる。

Bash:

```bash
target="${TMPDIR:-/tmp}/codex-template-next-$(date +%Y%m%d%H%M%S)"
/path/to/codex-templates/tools/sync-template.sh "$target"
echo "Synced template to: $target"
```

PowerShell:

```powershell
$target = Join-Path $env:TEMP ("codex-template-next-" + [guid]::NewGuid().ToString())
powershell -ExecutionPolicy Bypass -File path\to\codex-templates\tools\sync-template.ps1 -Destination $target
Write-Host "Synced template to: $target"
```

## 直接同期する場合

既存 repo に直接同期する場合は、まず dry-run で削除対象を確認する。

Bash:

```bash
/path/to/codex-templates/tools/sync-template.sh --dry-run --force /path/to/consumer-repo
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File path\to\codex-templates\tools\sync-template.ps1 -Destination path\to\consumer-repo -Force -DryRun
```

削除対象が想定通りの場合だけ、明示確認付きで実行する。

Bash:

```bash
/path/to/codex-templates/tools/sync-template.sh --force --confirm-destructive-overwrite /path/to/consumer-repo
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File path\to\codex-templates\tools\sync-template.ps1 -Destination path\to\consumer-repo -Force -ConfirmDestructiveOverwrite
```

## 上書きしないもの

| パス | 理由 |
| --- | --- |
| `docs/PROJECT_CONTEXT.md` | プロジェクト固有の文脈が入るため |
| `docs/adr/` | consumer repo の設計判断履歴のため |
| `docs/plans/` | consumer repo の計画履歴のため |
| `docs/reports/` | consumer repo の調査・検証履歴のため |
| `.codex/runs/` | 実行ログ・作業履歴のため |
| 認証情報や環境設定 | template 管理対象ではないため |

## レビュー観点

- `AGENTS.md` の安全制約が consumer repo の実態と矛盾していないか。
- `scripts/verify` が consumer repo で実行できるか。
- `.codex/config.toml` の sandbox / approval / network 設定が意図通りか。
- consumer 固有ファイルが削除・上書きされていないか。
- `template_version` と `CHANGELOG.md` の内容が一致しているか。

## Rollback

更新後に問題があれば、consumer repo 側の更新PRを閉じるか、更新ブランチを破棄する。既存mainへ直接同期しない運用にしておけば、rollback はブランチ削除で済む。
