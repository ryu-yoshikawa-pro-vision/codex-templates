# Repair Workflow

## 使う場面
- review finding を反映して修正を進めるとき
- validation failure を起点に bounded な再修正を行うとき
- `evaluation.result` が `partial` または `fail` で、修正可否と停止判断を整理したいとき

## Do not use
- 要件整理や計画策定が主目的のとき
- user がレビューのみを依頼しているとき
- root cause が環境要因だけで修正不要なとき
- unsafe action や destructive operation を伴う変更を押し切りたいとき

## Inputs
- review findings
- `evaluation.json`
- validation failure
- scope report
- `allowed_files`
- `expected_changed_files`
- observation artifacts
- subagent records

## Entry conditions

repair loop を開始してよい条件:

- review finding がある
- validation failure がある
- `evaluation.result` が `partial` または `fail`
- `evaluation.findings[]` に actionable finding がある
- scope が明確で `allowed_files` を宣言できる

開始してはいけない条件:

- 要件が不明
- scope が不明
- unsafe action が必要
- destructive operation が必要
- credential / secret / network permission の判断が必要
- user がレビューのみを依頼している
- root cause が環境要因だけで修正不要

## Iteration model

各iterationで以下を記録する。

- `iteration_number`
- `input_findings`
- `repair_plan`
- `allowed_files`
- `changed_files`
- `validation_commands`
- `validation_result`
- `remaining_delta`
- `decision`

`decision` は以下に固定する。

```text
continue
stop_success
stop_no_progress
stop_scope_violation
stop_unsafe
stop_max_iterations
stop_needs_human
```

## Finding triage

findings は以下に分類する。

```text
must_fix
should_fix
defer
reject
needs_human
```

分類基準:

- `must_fix`: correctness / safety / contract / CI / data integrity に関わる
- `should_fix`: maintainability / clarity / test confidence を上げる
- `defer`: PR scope外だが後続で扱う
- `reject`: 誤検知、現行実装で対応済み、根拠不足
- `needs_human`: 要件判断、破壊的変更、権限判断が必要

## Repair planning
- `must_fix` を優先し、なぜその修正が root cause に効くかを各iterationで明示する。
- `should_fix` は `must_fix` を阻害しない範囲でだけ扱う。
- `defer` と `reject` は理由を残し、loop の成功条件に混ぜない。
- `needs_human` は loop の継続条件ではなく escalation 条件として扱う。

## Scope control
- `--allowed-files`、`--expected-changed-files`、`docs/reference/change-scope-policy.md` に沿って変更境界を先に固定する。
- `changed_files` は各iterationで記録し、宣言した `allowed_files` を超えないことを確認する。
- scope ambiguity がある場合は repair を始めず、人間判断へ戻す。

## Validation per iteration
- 各iterationで実行した validation command と結果を記録する。
- validation は差分に対して十分な最小集合に絞るが、必須 check を省略しない。
- validation failure が残る場合は `remaining_delta` と次の判断を残す。

## Stop conditions
- max iteration に達した
- 同じ failure category が2回以上繰り返された
- 変更範囲が `allowed_files` を超える
- unsafe / destructive action が必要になった
- validation が環境依存で再現不能
- root cause が不明のまま修正を重ねている
- 修正が新しい failure を増やした
- user / reviewer の判断が必要な requirement ambiguity が出た

## Escalation to human decision
- `needs_human` finding が出た時点で loop を止める。
- requirement ambiguity、destructive change、permission judgement、policy boundary を含む場合は人間判断へ戻す。
- Unsafe or scope-violating findings must not be repaired by pushing through the loop.
- Stop the loop and escalate to a human decision.

## Evaluation connection
- 各iterationの結果は `evaluation.json` の `result`、`findings[]`、`improvement_candidates[]` と整合する形で要約する。
- loop 成功でも残差がある場合は `evaluation.result = partial` を許容し、なぜ完了扱いにしないかを明示する。
- `evaluation.result = fail` または `partial` のまま止める場合は、停止理由を `decision` と対応づける。

## Failure taxonomy connection
- `failure_category` や `findings[].category` は `spec/failure-taxonomy.json` の category を使う。
- 同じ failure category が反復した場合は `repair_loop_stalled` を候補にする。
- category を推測で増やさない。

## Observation / subagent evidence
- hook-observation JSONL は何が起きたかを示す evidence として参照してよい。
- `subagent-run.json` は scope compliance や親判断の evidence として参照してよい。
- observation / subagent evidence は最終判断の source of truth ではなく、`evaluation.json` と REPORT の根拠として使う。

## Output format
- iteration ごとに inputs、plan、changed_files、validation、remaining_delta、decision を並べる。
- 最終要約では loop の停止理由、残差、follow-up の有無を明示する。
- `evaluation.json`、failure taxonomy、`REPORT.md` へ接続できる命名を使う。

## Report file generation policy
- run の進行記録は `.codex/runs/<run_id>/REPORT.md` を使う。
- review-only や軽い確認だけでは durable report file を作らない。
- repair で durable report file を作るのは、ユーザーが保存を明示した場合や後から監査参照が必要な場合だけにする。

## Failure modes
- findings を triage せず着手順だけで loop を回す
- repeated failure を evidence ではなく「まだ試せる理由」と誤解する
- `allowed_files` を決めずに修正を始めて scope violation を招く
- validation を省略して「直ったはず」で止める
- unsafe / destructive action を loop の勢いで正当化する

`--max-iterations` is currently a reserved / validated runner option.
It documents the intended repair-loop bound, but `codex-task` does not automatically re-run Codex.
The agent must manually stop at the configured maximum and record the reason.
