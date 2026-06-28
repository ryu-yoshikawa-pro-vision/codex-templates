# Subagent Observation

## 目的

この文書は `subagent-run.json` baseline を説明します。目的は、subagent が有効だったか、scope を守ったか、親 agent が採用したかを後から評価できるようにすることです。

Writable subagents must declare allowed_files before changing files.  
Read-only subagents should have changed_files = [].  
Subagent logs are evidence, not final evaluation judgement.

## Read-only と Writable の違い

- read-only subagent:
  - 調査専用です。
  - schema 上は `allowed_files = []` を記録します。
  - 入力がなければ `input_files = []` を記録します。
  - `changed_files = []` を基本にします。
  - `mode = read_only` 相当の記録を残します。
- writable subagent:
  - 親 agent が scope を確定した後だけ使います。
  - `allowed_files` を先に宣言し、`changed_files` がその範囲内かを後で評価します。
  - `implementation_worker` のような限定実装役を想定します。

## `implementation_worker` の記録項目

`implementation_worker` を記録する場合、少なくとも以下を確認します。

- `allowed_files`
- `input_files`
- `changed_files`
- `scope.declared`
- `scope.compliant`
- `scope.violations`
- `summary`
- `parent_decision`
- `used_in_final_plan`

## `allowed_files` / `changed_files` / `scope.compliant`

- `allowed_files`:
  - writable subagent が変更してよい上限です。
- `changed_files`:
  - subagent が実際に変更した file です。
  - read-only subagent なら空配列であるべきです。
- `scope.compliant`:
  - `changed_files` が `allowed_files` の範囲に収まっていたかを示します。
  - 判定不能なら `null` を使えます。

## `parent_decision` の意味

- 親 agent が subagent 出力をどう扱ったかを示します。
- `accepted`
- `partially_accepted`
- `rejected`
- `deferred`
- `not_reviewed`

これは evidence に対する親の判断であり、自動評価結果ではありません。

## `used_in_final_plan` の意味

- `true`: subagent の結果が最終 plan / 実装方針 / 最終回答に使われた。
- `false`: 記録として残したが、最終 plan には採用しなかった。

## `evaluation.json` / failure taxonomy との接続

- `subagent-run.json` は evidence artifact です。
- `evaluation.json` が interpretation の source of truth です。
- subagent 利用が不適切だった場合は、必要に応じて `bad_subagent_delegation` などの failure taxonomy category と接続します。
- ただし category の最終判断は親 agent / reviewer が行います。

## run manifest との関係

- collector は `.codex/runs/<run_id>/subagents/*.json` を集約し、`run.json.subagents.records[]` に path と summary を載せます。
- `run.json` には全文を埋め込まず、`allowed_files_count` / `changed_files_count` / `scope_compliant` / `parent_decision` などの summary だけを載せます。
- read-only subagent の `changed_files != []` や writable subagent の `allowed_files = []` は warning の対象です。

## Sample JSON

```json
{
  "schema_version": 1,
  "subagent_run_id": "subagent-001",
  "parent_run_id": "20260627-120000-JST",
  "agent": {
    "name": "implementation_worker",
    "model": "gpt-5.4-mini"
  },
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Update observation docs for the requested files only.",
  "sandbox": {
    "type": "workspace-write",
    "network": false
  },
  "allowed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "input_files": [
    "template/docs/reference/run-artifacts.md"
  ],
  "changed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "scope": {
    "declared": true,
    "compliant": true,
    "violations": []
  },
  "started_at": "2026-06-27T12:00:00Z",
  "ended_at": "2026-06-27T12:02:00Z",
  "status": "completed",
  "summary": "Updated the requested observation doc within the declared scope.",
  "parent_decision": {
    "action": "accepted",
    "reason": "The output stayed within allowed_files and matched the requested change."
  },
  "used_in_final_plan": true,
  "evidence": [
    {
      "kind": "path",
      "value": "template/docs/reference/hook-observation.md"
    }
  ],
  "metadata": {
    "note": "Sample only"
  }
}
```
