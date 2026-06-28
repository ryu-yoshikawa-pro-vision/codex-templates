# Evaluation Contract

## 目的

この文書は、Codex harness における `evaluation.json` の評価契約を説明します。Initial implementation A では schema 実装ではなく、後続の schema / validator 実装に先行する contract example として扱います。

## 基本方針

- 初期段階では数値 score を主軸にしません。
- `rating + evidence` を基本にします。
- 数値 score は、十分な評価データが溜まってから後段で検討します。
- evaluation は成果評価だけでなく、harness improvement candidate を持てます。
- 観測事実は `run.json` / `codex-task` report JSON / logs を参照します。
- agent が exit code、changed files、executed commands などの実行事実を後書きしません。
- `evidence` は人間向け短文、`evidence_refs` は machine-readable な artifact 参照として使います。

## Rating Enum

dimension ごとの rating enum は以下に固定します。

```text
pass | warn | fail | not_evaluated
```

## Evaluation Result Enum

run 全体の `evaluation.result` は以下に固定します。

```text
pass | partial | fail | not_evaluated
```

`dimensions.*.rating` は観点ごとの状態、`evaluation.result` は run 全体の成果達成度を表します。

## 主な評価観点

### `task_completion`

- 何を評価するか:
  - ユーザー依頼や計画で定義された成果がどこまで達成されたか。
- どのような evidence を求めるか:
  - changed files、実装差分、出力 artifact、未完了項目の明示。
- 判断例:
  - `pass`: 必須成果物が揃い、非目標も守られている。
  - `warn`: 主成果はあるが、未完了項目や追加修正前提が残る。
  - `fail`: 必須成果物が不足し、目的を満たしていない。

### `scope_control`

- 何を評価するか:
  - 変更が許可範囲に収まり、不要な差分を出していないか。
- どのような evidence を求めるか:
  - `changed_files`、計画上の対象ファイル、除外対象の確認。
- 判断例:
  - `pass`: 変更は許可された対象に限定されている。
  - `warn`: 境界に近い変更があり、追加レビューが必要。
  - `fail`: スコープ外の source file 変更や削除がある。

### `validation_confidence`

- 何を評価するか:
  - 実行済み検証が十分か、結果をどこまで信頼できるか。
- どのような evidence を求めるか:
  - verify command の status、既存 test / smoke / integration 実行結果、未実行理由。
- 判断例:
  - `pass`: 必須検証が実行され、結果も妥当。
  - `warn`: 一部未実行または一部失敗だが、限定的な説明が付いている。
  - `fail`: 必須検証が不足、失敗、または理由なく省略されている。

### `safety_compliance`

- 何を評価するか:
  - safety rule、hook、wrapper policy、禁止事項を守ったか。
- どのような evidence を求めるか:
  - blocked action の有無、実行コマンド、wrapper 利用状況、禁止操作未実施の確認。
- 判断例:
  - `pass`: 安全ポリシー違反がない。
  - `warn`: blocked action はあったが、危険操作は実行されていない。
  - `fail`: 禁止された実行経路や unsafe action が行われた。

### `reviewability`

- 何を評価するか:
  - 後から人間が差分、根拠、判断を追跡できるか。
- どのような evidence を求めるか:
  - `REPORT.md`、run artifact、明示された evidence、整合した category / finding。
- 判断例:
  - `pass`: 主要判断と証跡が追跡可能。
  - `warn`: 一部説明不足だが、全体は追える。
  - `fail`: 根拠不足でレビュー不能。

### `maintainability`

- 何を評価するか:
  - 変更が既存構造に沿い、今後の保守を不必要に難しくしていないか。
- どのような evidence を求めるか:
  - 既存設計との整合、責務分離、不要な複雑化の有無。
- 判断例:
  - `pass`: 既存構造と責務分離を保っている。
  - `warn`: 動くが、後続で整理が必要な箇所がある。
  - `fail`: 保守性を大きく損なう構造変更になっている。

### `reproducibility`

- 何を評価するか:
  - 同じ run を別の保守者が追跡・再実行しやすいか。
- どのような evidence を求めるか:
  - run id、参照 plan、実行コマンド、artifact path、環境依存の明示。
- 判断例:
  - `pass`: 再現に必要な情報が残っている。
  - `warn`: 一部環境依存が強いが、未再現要因が明記されている。
  - `fail`: 再現に必要な前提や証跡が欠けている。

## Failure Taxonomy との接続

- `primary_failure_category` は `spec/failure-taxonomy.json` の category から選びます。
- `failure_categories` も taxonomy と整合する必要があります。
- `findings[].category` も taxonomy と整合する必要があります。
- taxonomy 外の category は使いません。
- evidence のない finding / rating は後続 validator で warning または failure にするべきです。
- `evidence_refs` は optional ですが、`run.json` / report / log / subagent / validation command への参照があると reviewability が上がります。

## Improvement Candidates

`improvement_candidates` は、少なくとも以下を持つべきです。

- `target`
- `evidence`
- `evidence_refs` (optional)
- `expected_impact`
- `recommendation`

対象になり得るもの:

- `AGENTS.md`
- `PLANS.md`
- `CODE_REVIEW.md`
- `.agents/skills/`
- `.codex/rules/`
- `.codex/hooks/`
- `scripts/codex-safe.*`
- `scripts/codex-task.*`
- `spec/`

## Contract Example

以下は Initial implementation A の説明用 example です。schema 実装ではありません。

```json
{
  "schema_version": 1,
  "run_id": "20260627-103240-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {
      "rating": "warn",
      "evidence": "Implementation completed, but required verification failed.",
      "evidence_refs": [
        {
          "kind": "validation_command",
          "path": ".codex/runs/20260627-103240-JST/run.json",
          "selector": "$.validation.commands[0]",
          "event_id": null,
          "summary": "verify command exited with code 1"
        }
      ]
    },
    "scope_control": {
      "rating": "pass",
      "evidence": "Changed files were within the allowed scope."
    },
    "validation_confidence": {
      "rating": "fail",
      "evidence": "Required verify command exited with code 1."
    }
  },
  "findings": [
    {
      "category": "missing_validation",
      "severity": "medium",
      "evidence": "bash template/scripts/verify exited with code 1.",
      "evidence_refs": [
        {
          "kind": "run_manifest",
          "path": ".codex/runs/20260627-103240-JST/run.json",
          "selector": "$.validation",
          "event_id": null,
          "summary": "validation summary recorded the verify failure"
        }
      ],
      "detail": "Required verification did not pass."
    }
  ],
  "improvement_candidates": [
    {
      "target": "PLANS.md",
      "evidence": "Repeated missing validation findings across implementation runs.",
      "evidence_refs": [],
      "expected_impact": "Reduce ambiguous fallback validation decisions.",
      "recommendation": "Clarify fallback validation policy."
    }
  ]
}
```
