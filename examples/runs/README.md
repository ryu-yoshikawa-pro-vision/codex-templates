# Run examples

このディレクトリは、`.codex/runs/<run_id>/` の使い方を具体例で示すための source repo 向け examples です。consumer repo にそのままコピーする必須ファイルではありません。

## Examples

| Example | 用途 |
| --- | --- |
| `standard-implementation/` | 通常実装で PLAN / TASKS / REPORT を残す例 |
| `pr-review/` | PRレビュー依頼で実装修正せず findings を整理する例 |
| `auto-net-investigation/` | 外部通信が必要な調査で auto-net の理由と安全境界を記録する例 |

## 使い方

- 新しい workflow を追加するときは、まずここに小さな example を追加して運用イメージを固定する。
- example は実ファイルを削除・renameしない。
- 実行ログや一時ファイルは含めず、PLAN / TASKS / REPORT の書き方に集中する。
