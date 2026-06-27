# Failure Taxonomy

## 目的

この文書は、source repo の static catalog `spec/failure-taxonomy.json` を人間向けに説明するための reference です。failure taxonomy の目的は、run の失敗原因を再発防止につながる形で揃えて記録し、`evaluation.json` の category 名が毎回ぶれないようにすることです。

## 基本ルール

- `primary_failure_category` は run の主たる失敗原因を 1 つ選びます。
- `failure_categories` は複合要因を表す配列です。
- `failure_categories` は `primary_failure_category` を必ず含みます。
- `findings[].category` は taxonomy と整合する必要があります。
- taxonomy 外の category を agent が作ってはいけません。
- evidence のない分類は、後続 validator で warning または failure にするべきです。

## Category 一覧

| Category | 意味 | Improvement target |
| --- | --- | --- |
| `instruction_gap` | 指示が曖昧で Codex が迷った | `AGENTS.md`, skills |
| `scope_creep` | 余計な変更をした | worker policy, allowed files |
| `missing_context` | 必要なファイルや背景を読んでいない | planning skill |
| `missing_validation` | 検証不足 | `codex-task`, validation plan |
| `unsafe_action_blocked` | 危険操作が rule / hook で止まった | rules, hooks, prompt policy |
| `bad_subagent_delegation` | subagent の委譲が不適切 | subagent policy |
| `flaky_or_env_issue` | 環境差分・不安定性 | sandbox, setup docs |
| `review_gap` | review 観点が漏れた | `CODE_REVIEW.md`, review skill |
| `repair_loop_stalled` | 修正ループが収束しない | stop condition, repair skill |
| `artifact_contract_gap` | artifact の責務・構造・正本関係が不明確で run を評価できない | run artifact docs, schema |

## Runner Candidate と Agent Judgement

- runner candidate:
  - exit code、verify status、hook block、changed file などの観測事実から候補を提案してよい分類です。
  - 例: `missing_validation`, `unsafe_action_blocked`, `scope_creep`, `flaky_or_env_issue`
- agent judgement:
  - instruction quality、読み漏れ、review 観点、subagent 委譲の適否のように文脈判断が必要な分類です。
  - 例: `instruction_gap`, `missing_context`, `bad_subagent_delegation`, `review_gap`, `repair_loop_stalled`, `artifact_contract_gap`

最終的な `primary_failure_category` は、runner が決めるのではなく、agent / reviewer が taxonomy から選びます。

## `primary_failure_category` と `failure_categories`

### `primary_failure_category`

- run の主たる失敗原因を 1 つ選びます。
- summary / aggregation で使います。

### `failure_categories`

- 複合要因を表す配列です。
- `primary_failure_category` を必ず含めます。

## `findings[].category` の扱い

- `findings[].category` は taxonomy の category と一致している必要があります。
- rating や finding に evidence がない場合、後続 validator は warning または failure にするべきです。
- category だけを付けて、なぜそう判断したかを示さない使い方は避けます。

## `artifact_contract_gap` の利用条件

- 通常の implementation failure には使いません。
- artifact schema / responsibility / source-of-truth relationship が不明確で、run を評価できない場合に限って使います。
- 例:
  - `run.json` と `evaluation.json` のどちらが failure interpretation の正本か不明
  - `codex-task` report JSON と `run.json` の責務が重複していて観測事実の正本が判断できない

### 誤用防止

- verify 失敗、実装漏れ、単純な bug、テスト失敗を理由に `artifact_contract_gap` を付けてはいけません。
- その場合は通常、`missing_validation`、`scope_creep`、`instruction_gap` など別 category を選びます。

## Example

```json
{
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "findings": [
    {
      "category": "missing_validation",
      "severity": "medium",
      "evidence": "bash template/scripts/verify exited with code 1.",
      "detail": "Required verification did not pass."
    }
  ]
}
```
