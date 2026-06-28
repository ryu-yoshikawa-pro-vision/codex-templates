# Codex SDK runner evaluation example

## Purpose

This example is source-repo-only.
It is not a consumer-facing template.
It does not implement a runnable SDK runner.
Do not copy this into consumer repos until an ADR approves adoption.

この example は、Codex SDK runner を実装するのではなく、評価時に何を比較し、どの条件を満たすまで core template に入れないかを説明するための source repo asset である。

## Current status

- `codex-task` remains the canonical runner baseline.
- SDK runner is not adopted into the core template.
- This directory exists only to support evaluation, ADR review, and future evidence gathering.

## Non-goals

- runnable SDK runner の提供
- `codex-task` の置き換え
- consumer-facing `template/` への導入
- safety policy や run artifact contract の変更

## How to use this example

- `maintainers/adr/2026-06-28_codex-sdk-runner-evaluation.md` を読んで採用条件と不採用条件を確認する。
- 実際に SDK runner 候補を試す前に `contract-checklist.md` を複製または記入して、baseline parity を判定する。
- gap は source repo 側の improvement candidate または follow-up plan として記録する。

## Evaluation flow

1. Compare SDK runner capabilities against `codex-task` baseline.
2. Fill `contract-checklist.md`.
3. Record gaps as harness improvement candidates.
4. Keep `codex-task` as the canonical runner unless adoption conditions are met.

## Contract checklist

- 評価時のチェックリストは [`contract-checklist.md`](contract-checklist.md) を使う。
- Safety、Artifacts、Validation、Scope control、Portability、Consumer distribution を個別に確認する。

## Expected outcome

- 結論は `Adopt into core template` ではなく、まず `Needs more evidence` または `Keep source-repo-only experimental` になることを想定する。
- core template 採用の前に、baseline parity、portability、distribution cost、rollback path の evidence を揃える。

## Do not copy into consumer repos yet

- This example is source-repo-only.
- It is not a consumer-facing template.
- It does not implement a runnable SDK runner.
- Do not copy this into consumer repos until an ADR approves adoption.
