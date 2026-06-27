# Harness Improvement Loop

## Purpose

Harness improvement candidates are proposals, not automatic changes.
run 結果、評価結果、repair loop outcome を、再発防止のための reviewable candidate に変換する reference である。

## Inputs
- `evaluation.json`
- run manifest
- validation results
- hook observation artifacts
- subagent records
- review comments
- repeated failure across runs

## Candidate model

candidate は次の field を持つ。

```text
candidate_id
target
failure_category
source_runs
evidence
expected_impact
risk
recommended_change
strictness
status
owner_decision
```

## Evidence requirements
Each improvement candidate must include concrete evidence.
At least one of:
- `evaluation.findings[]`
- `improvement_candidates[]`
- `run.json.validation.commands`
- hook-observation JSONL
- `subagent-run.json`
- review comment
- repeated failure across runs

## Prioritization
- repeated failure を伴うものを優先する。
- safety / contract / reviewability の改善を wording-only より優先する。
- `strict` と `blocked` は risk と owner decision を先に明示する。

## Strict workflow triggers
- safety layer、hooks、execpolicy、`codex-safe.*`、`codex-task.*`、`spec/` の変更提案
- destructive operation、credential、external permission、policy bypass を要する提案

Safety-layer changes require strict workflow review.
この workflow は failure taxonomy と evidence を使って candidate を分類する。

## Separation from implementation work
Implementation fixes and harness improvements must be separated unless the user explicitly scopes both.
Harness improvement must not be bundled into unrelated product implementation work.
If a task fixes product code and also discovers a harness issue, record the harness issue as a candidate and handle it in a separate follow-up.

## Relationship to evaluation.json
- `evaluation.json` は candidate の primary evidence source である。
- `failure_category` は `spec/failure-taxonomy.json` の category を使う。
- candidate は `evaluation.json` の finding をそのまま実装修正へ変換するのではなく、改善 target と strictness を付けて follow-up 化する。

## Relationship to repair loop
- repair loop の停止理由や repeated failure は harness improvement candidate の入力になる。
- loop で解決できない structural issue は `strict` か `blocked` の候補として分離する。

## Relationship to observation artifacts
- hook observation は blocked action や validation behavior の evidence として使う。
- subagent records は delegation / scope / reviewability 改善の evidence として使う。

## Review and approval
- candidate は `proposed` から始め、owner decision を経て follow-up scope を決める。
- auto-apply しない。
- rejected / deferred も evidence と理由を残す。

## Non-goals
- 自動適用
- safety layer 変更の即時実装
- product implementation との混在
- failure category の自動推論や新規 taxonomy 追加
