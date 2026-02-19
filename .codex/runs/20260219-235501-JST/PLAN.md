# Plan

## Objective
- 前回変更の意図ずれを修正し、「docs/plans 用テンプレート追加」を中心に運用ドキュメントを調整する。

## Scope
- In:
  - 既存 `.codex/templates/*.md` の不要変更の取り下げ
  - `docs/plans/` 用テンプレートファイルの新規作成
  - AGENTS / PROJECT_CONTEXT の記述を要件に合わせて補正
- Out:
  - 実行コードやCI設定の変更

## Assumptions
- ユーザー要望は「既存テンプレートではなく docs/plans 向けテンプレートを作る」こと。

## Approach
- 最新コミット差分を見直し、不要箇所は戻す。
- `docs/plans` 配下に再利用可能な計画テンプレートを追加する。
- AGENTS の計画ルールを新テンプレート参照へ更新する。

## Definition of Done
- `.codex/templates/*.md` の前回追加分が取り下げられている。
- `docs/plans` 用テンプレートが追加され、AGENTS と整合している。
- コミットとPR作成が完了している。

## Risks / Unknowns
- 既存運用との用語差分（plan_name/プラン名）をどう統一するか。

## Thinking Log
- 2026-02-19 23:56 JST: ユーザーコメントから、前回の `.codex/templates` 変更は不要と判断。削除・巻き戻しを優先。
