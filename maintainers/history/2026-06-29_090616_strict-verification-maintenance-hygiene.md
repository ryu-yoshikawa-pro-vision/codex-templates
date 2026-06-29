# 2026-06-29 09:06:16 JST

## Summary
- source repo maintainer 向けの strict verification / maintenance workflow を `maintainers/PROJECT_CONTEXT.md` に追記した。

## Changes
- release / maintenance gate に `template/scripts/verify --strict-harness` / `verify.ps1 -StrictHarness` を追加した。
- consumer update planning は `tools/plan-consumer-update.*` と `tools/sync-template.* --plan-only --exclude-protected` を使う方針を明記した。
- generated run artifact cleanup は `template/scripts/cleanup-runs.*` の preview-only / confirm 必須 / repo 外拒否 / symlink・reparse 拒否を前提にすることを明記した。
- Bash / PowerShell parity を `validate-spec`、strict verify、cleanup / consumer update planning integration tests、CI で確認する前提を明記した。

## Rationale
- v0.11.0 の source repo 運用では、consumer-facing verify と maintainer-facing release hygiene を分離して説明した方が保守判断と CI 期待値が一致するため。

## ADR
- 追加なし。既存 source/consumer 境界の中での保守・検証 hardening であり、新しい設計分岐は導入していない。
