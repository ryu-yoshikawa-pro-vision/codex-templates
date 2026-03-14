# ADR 0003: クロスプラットフォーム安全ハーネスと軽量実行モードの導入

## Status
- Accepted

## Context
- 安全ハーネスは `scripts/codex-safe.ps1` に依存しており、bash中心環境で同等の運用を適用しづらかった。
- 品質ゲート実行が分散しており、実行手順が環境ごとにぶれやすかった。
- 小規模・低リスク作業でも標準フローの運用コストが高く、汎用適用時の障壁になっていた。

## Decision
- PowerShell版と同方針の bash wrapper `scripts/codex-safe.sh` を追加する。
- 品質ゲートの統一入口として `scripts/verify` を追加する。
- `AGENTS.md` に Lightweight Execution Mode を追加し、適用条件・最低証跡・禁止条件を明示する。

## Consequences
- Windows/PowerShell と bash の双方で同等ポリシーを適用しやすくなる。
- 品質ゲート実行が一貫化し、運用の再現性が向上する。
- 軽量モードを許可することで小規模タスクの速度は向上するが、適用条件の逸脱監視が必要になる。
