# Harness Improvement Workflow

## 使う場面
- run 結果や `evaluation.json` からハーネス改善候補を作るとき
- repair loop の反復失敗を、次回の workflow 改善へ変換したいとき
- review comment や repeated failure を安全に follow-up 化したいとき

## Do not use
- product implementation の修正そのものを進めるとき
- root cause が単発 bug で、harness 側の改善候補がないとき
- evidence なしで思いつきの改善提案を列挙したいとき

## Inputs
- `evaluation.json`
- run manifest
- validation results
- hook observations
- subagent-run records
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

### target

```text
AGENTS.md
PLANS.md
CODE_REVIEW.md
.agents/skills/
.codex/rules/
.codex/hooks/
scripts/codex-safe.*
scripts/codex-task.*
spec/
docs/reference/
examples/
other
```

### strictness

```text
normal
strict
blocked
```

- `normal`: docs / examples / non-safety skill improvement
- `strict`: safety layer、runner、schema、rules、hooks、codex-safe、codex-task に関わる
- `blocked`: destructive operation、credential、external permission、policy bypass が必要

### status

```text
proposed
accepted
rejected
deferred
implemented
```

### owner_decision

```text
not_reviewed
approved
rejected
needs_more_evidence
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

根拠なし candidate は禁止する。

## Target areas
- instruction layer: `AGENTS.md`、`PLANS.md`、`CODE_REVIEW.md`、`.agents/skills/`
- safety layer: `.codex/rules/`、`.codex/hooks/`、`scripts/codex-safe.*`
- execution layer: `scripts/codex-task.*`
- contract layer: `spec/`、`docs/reference/`、`examples/`

## Classification
- `failure_category` は `spec/failure-taxonomy.json` の category を参照する。
- 今回は failure category を追加しない。
- candidate は failure の種類、改善 target、strictness を分けて記録する。

## Prioritization
- correctness、safety、contract ambiguity の再発を防ぐものを優先する。
- repeated failure を伴うものは単発候補より優先する。
- `strict` と `blocked` は impact だけでなく review cost と risk を明示する。

## Safety strictness
- safety layer、hooks、execpolicy、`codex-safe.*`、`codex-task.*`、`spec/` 変更案は strict workflow review を必要とする。
- `blocked` candidate は現行 task 内で扱わず、明示的な許可と別スコープへ送る。

## Separation from implementation work
Harness improvement must not be bundled into unrelated product implementation work.
If a task fixes product code and also discovers a harness issue, record the harness issue as a candidate and handle it in a separate follow-up.

## Output format
- candidate summary
- evidence
- expected impact
- risk
- recommended change
- strictness
- owner decision
- follow-up scope

## Review requirements
- candidate は proposal としてレビュー可能な形にする。
- auto-apply せず、plan / docs / issue / follow-up PR に落とす。
- `strict` と `blocked` はなぜ通常実装と分離したかを説明する。

## Examples
- docs / examples の wording 改善は `normal`
- validator / schema / runner contract 改善は `strict`
- policy bypass や destructive action を伴う提案は `blocked`

## Failure modes
- evidence なしで candidate を増やす
- product fix と harness improvement を同じ PR で混ぜる
- `strict` を `normal` として扱い review cost を隠す
- blocked candidate を「今だけ必要」として押し通す
