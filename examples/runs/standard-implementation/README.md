# Standard implementation run example

Standard workflow では、実装前に影響範囲と検証方針を固定し、`.codex/runs/<run_id>/` に作業の根拠を残す。

## Directory shape

```text
.codex/runs/20260627-090000-JST/
├── PLAN.md
├── TASKS.md
├── REPORT.md
├── artifacts/
├── logs/
└── reports/
```

## PLAN.md example

```md
# Plan

## Goal

既存の入力バリデーションを壊さず、設定画面に通知ON/OFFの項目を追加する。

## Current understanding

- 設定画面は `src/features/settings/` 配下にある。
- 保存処理は `updateUserSettings` を経由する。
- 既存テストは form submit と API error を確認している。

## Assumptions

- 通知ON/OFFの初期値は既存ユーザーでは `false` とする。
- API schema の変更は別途完了済みとする。

## Non-goals

- 通知配信処理の実装。
- 既存設定UIの大幅な再設計。

## Impacted areas

- Settings form
- Settings schema
- Settings tests

## Change strategy

1. schema に boolean field を追加する。
2. form に checkbox を追加する。
3. submit payload に field を含める。
4. 既存テストに最小ケースを追加する。

## Validation plan

- `npm test -- settings`
- `npm run typecheck`
```

## TASKS.md example

```md
# Tasks

## Now

- [x] 現在の設定画面とschemaを確認する
- [x] 通知ON/OFF fieldを追加する
- [x] submit payloadを更新する
- [ ] テストを追加する
- [ ] validationを実行する

## Discovered

- [ ] storybook exampleの更新要否を確認する

## Blocked

- なし
```

## REPORT.md example

```md
# Report

## Summary

- 設定画面に通知ON/OFF fieldを追加した。
- schemaとsubmit payloadを更新した。
- テスト追加とvalidationは未完了。

Progress: 60% (3/5)

## Evidence

- `src/features/settings/SettingsForm.tsx`
- `src/features/settings/settingsSchema.ts`

## Next

- テストを追加する。
- `npm test -- settings` と `npm run typecheck` を実行する。
```
