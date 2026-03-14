# Source Repo Layout

## 境界
- `template/`: consumer-facing 配布面
- `maintainers/`: source repo の運用文脈と履歴
- `spec/`: 契約の正本
- `tools/`: maintainer 補助ツール
- `tests/`: source repo の検証
- `examples/`: curated examples

## 原則
- consumer-facing な説明を root や `maintainers/` に戻さない。
- source repo 固有の履歴を `template/` に持ち込まない。
- 契約変更は `spec/` を先に変える。
