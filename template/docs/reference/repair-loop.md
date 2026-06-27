# Repair Loop

## Purpose

Repair loop is a bounded workflow, not an instruction to keep trying indefinitely.
Review -> Repair -> Validate の反復を、停止条件と証跡つきで扱うための reference である。

## Relationship to code-review skill
- `code-review` skill は findings を作る。
- `repair-loop` skill は findings を triage し、bounded な修正・検証・停止判断へ接続する。
- review-only task では repair loop を始めない。

## Relationship to evaluation.json
- `evaluation.json` は loop 前後の評価と残差の正本である。
- `evaluation.result = partial | fail` は repair loop の入口候補になる。
- loop の停止理由と残差は `evaluation.json` に接続できる形で残す。

## Relationship to failure taxonomy
- failure category は `spec/failure-taxonomy.json` に揃える。
- repeated failure は evidence であり、blind retry の理由ではない。
- 同じ category の反復は `repair_loop_stalled` を検討する。

## Relationship to run artifacts
- `REPORT.md` に iteration ごとの判断を残す。
- `run.json` や report JSON がある場合は validation command と changed files の事実を参照する。
- `--max-iterations` は repair-loop bound を文書化する reserved option であり、runner auto-loop ではない。

## Relationship to observation and subagent records
- hook-observation JSONL は validation failure や blocked action の evidence に使う。
- `subagent-run.json` は scope compliance や delegated investigation の evidence に使う。
- どちらも evidence であり、最終判断の source of truth は `evaluation.json` である。

## Max iteration policy
- `--max-iterations` が設定されている場合、agent はその上限で必ず止まる。
- `codex-task` does not automatically re-run Codex.
- max iteration 到達は `stop_max_iterations` として記録する。
- stop condition を満たしたら loop を継続しない。

## Stop conditions
- max iteration に達した
- 同じ failure category が2回以上繰り返された
- `allowed_files` を超えた
- unsafe / destructive action が必要
- validation が環境依存で再現不能
- root cause が不明のまま修正を重ねている
- 修正で新しい failure が増えた
- requirement ambiguity が発生した

Repeated failure is evidence, not a reason to continue blindly.

## Scope control
- repair 前に `allowed_files` と expected scope を宣言する。
- `docs/reference/change-scope-policy.md` を基準に changed files を確認する。
- scope violation が出たら loop を継続しない。

## Unsafe action policy
Unsafe or scope-violating repairs stop the loop.
Unsafe or scope-violating findings must not be repaired by pushing through the loop.

## Required iteration record
- `iteration_number`
- `input_findings`
- `repair_plan`
- `allowed_files`
- `changed_files`
- `validation_commands`
- `validation_result`
- `remaining_delta`
- `decision`

`decision` values:

```text
continue
stop_success
stop_no_progress
stop_scope_violation
stop_unsafe
stop_max_iterations
stop_needs_human
```

## Example workflow
1. review finding または `evaluation.result = partial` を確認する。
2. findings を `must_fix` / `should_fix` / `defer` / `reject` / `needs_human` に分ける。
3. `allowed_files` を確定し、1 iteration 分の repair plan を作る。
4. 修正後に validation を実行し、remaining delta と decision を記録する。
5. success、no progress、scope violation、unsafe、max iteration のいずれかで止める。

## Non-goals
- 無制限 self-healing
- runner-level automatic repair loop
- safety layer を押し切る例外運用
- repair summary の `run.json` 自動統合
