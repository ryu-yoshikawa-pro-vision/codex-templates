# PR review run example

PR review workflow では、実装を変更せず、差分・CI・既存コメントを確認して findings first で返す。

## Directory shape

```text
.codex/runs/20260627-093000-JST/
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

対象PRの現在差分、CI、既存レビューコメントを確認し、残っている問題だけを severity 順に整理する。

## Non-goals

- 実装修正。
- PR本文やタイトルの変更。
- レビューコメント投稿。

## Review focus

1. correctness / behavioral regression
2. security / data handling
3. missing tests
4. maintainability
5. documentation

## Evidence sources

- PR diff
- CI results
- Review threads
- Relevant source files
```

## TASKS.md example

```md
# Tasks

## Now

- [x] PR metadataを確認する
- [x] 変更ファイル一覧を確認する
- [x] CI結果を確認する
- [x] 主要diffを読む
- [ ] findingsをseverity順にまとめる

## Discovered

- [ ] 古いreview commentが現在も有効か確認する

## Blocked

- なし
```

## REPORT.md example

```md
# Report

## Summary

- CIは成功している。
- 主要diffを確認した。
- High severityの懸念が1件残っている。

Progress: 80% (4/5)

## Evidence

- PR metadata
- CI result
- `src/api/settings.ts`
- `src/features/settings/SettingsForm.tsx`

## Findings draft

### High: API error時にUI stateがrollbackされない

- Location: `src/features/settings/SettingsForm.tsx`
- Why it matters: 保存失敗時に画面だけ成功状態に見える。
- Suggested fix: mutation failure時にform stateを戻す、またはerror bannerを表示する。

## Next

- findingsを最終回答形式に整理する。
```
