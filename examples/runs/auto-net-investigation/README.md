# Auto-net investigation run example

`auto-net` は、外部仕様確認、依存解決、network が必要な検証に限定して使う。通常の文書修正、静的調査、PRレビューでは使わない。

## Directory shape

```text
.codex/runs/20260627-100000-JST/
├── PLAN.md
├── TASKS.md
├── REPORT.md
├── artifacts/
└── logs/
```

## PLAN.md example

```md
# Plan

## Goal

外部APIの最新仕様を確認し、現在のadapter実装が仕様変更の影響を受けるか調査する。

## Why auto-net is needed

- 公式APIドキュメントの確認が必要。
- 現在の依存packageのmetadata確認が必要。

## Safety boundaries

- ファイル削除、rename、git操作はしない。
- remote script をshellへ直結しない。
- package installが必要な場合は、まず `--ignore-scripts` を検討する。
- 不要ファイルは削除せず、削除候補としてREPORT.mdに記録する。

## Validation plan

- 公式ドキュメントの該当箇所を確認する。
- adapterの現行実装を読む。
- 必要なら既存テストだけを実行する。
```

## TASKS.md example

```md
# Tasks

## Now

- [x] auto-netが必要な理由を明記する
- [x] 外部仕様を確認する
- [x] 現行adapterとの差分を整理する
- [ ] 影響有無をまとめる

## Discovered

- [ ] 依存packageのmajor update有無を確認する

## Blocked

- なし
```

## REPORT.md example

```md
# Report

## Summary

- 外部APIの認証header仕様に変更は見つからなかった。
- rate limit responseの説明が更新されていた。
- 現行adapterへの即時影響は低い。

Progress: 75% (3/4)

## Evidence

- Official API docs checked at 2026-06-27 JST
- `src/integrations/vendor/adapter.ts`
- `tests/integrations/vendor/adapter.test.ts`

## Risks

- rate limit retry policyの確認は別タスク化した方がよい。

## Deletion candidates

- なし

## Next

- 影響なしの根拠を最終回答にまとめる。
```
