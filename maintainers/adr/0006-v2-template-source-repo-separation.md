# ADR 0006: v2 で template と source repository を分離する

## Status
- Accepted

## Context
- v1 構成では consumer-facing 配布物、source repo の運用記録、契約の正本が同居していた。
- その結果、利用者向け導線と保守者向け導線が混ざり、構造変更時の影響範囲が見えにくかった。

## Decision
- consumer-facing 配布面を `template/` に集約する。
- source repo の文脈、ADR、plans、reports、history は `maintainers/` に集約する。
- workflow / routing / naming / safety の契約は `spec/` に置き、`tools/validate-spec.*` で整合を確認する。
- tracked sample run は `examples/sample-runs/` の curated assets に限定する。

## Consequences
- consumer が取るべきファイル群が明確になる。
- source repo の運用記録と template の内容を分離できる。
- 文書・skill・wrapper を変更するときは `spec/` 更新と validation が必須になる。
