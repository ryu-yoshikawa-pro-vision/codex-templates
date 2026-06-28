# Hook Observation

## 目的

この文書は、Codex hook / wrapper / 将来の runner が出力する observation event baseline を説明します。目的は、後から何が起きたかを JSONL で追跡できるようにすることです。

Observation hook must not weaken safety hooks.  
Observation hook failure must not stop Codex execution.  
Observation events are not the source of truth for evaluation decisions.

## Scope

- 対象は observation event 1 件ごとの schema と optional hook baseline です。
- `hook-observation JSONL` は evidence / tracing 用です。
- block 判断の正本は既存 safety hook / wrapper / policy に残ります。
- collector は run_id 一致の event を `run.json.hook_observations` に summary 統合します。

## Event Types

`spec/hook-observation.schema.json` と bundled copy は次の event を定義します。

- `PreToolUse`
- `PostToolUse`
- `SubagentStart`
- `SubagentStop`
- `Stop`
- `WrapperStart`
- `WrapperStop`
- `SafetyBlocked`
- `ObservationError`

## JSONL Path

- 既定 path: `.codex/observations/hooks.jsonl`
- 環境変数 `CODEX_OBSERVATION_LOG` で上書きできます。
- 1 行 1 JSON object の JSONL 形式です。

## Environment Variables

optional hook baseline は次を受け取れます。

- `CODEX_HOOK_EVENT`
- `CODEX_HOOK_TOOL_NAME`
- `CODEX_HOOK_TOOL_OPERATION`
- `CODEX_HOOK_TOOL_TARGET`
- `CODEX_HOOK_INPUT_SUMMARY`
- `CODEX_RUN_ID`
- `CODEX_OBSERVATION_LOG`

必要なら `CODEX_HOOK_SEVERITY`、`CODEX_HOOK_SOURCE`、`CODEX_HOOK_DECISION_REASON`、`CODEX_HOOK_CWD` も使えますが、baseline の既定は `severity=info`、`source=codex_hook`、`decision.action=observe`、`blocking=false` です。

## Schema Fields

主要 field は以下です。

- `schema_version`
- `event_id`
- `run_id`
- `timestamp`
- `source`
- `event`
- `severity`
- `blocking`
- `tool`
- `cwd`
- `input_summary`
- `decision`
- `evidence`
- `metadata`

`input_summary` は raw prompt や secret の全文ではなく summary だけを書きます。

## Optional Behavior

- observation hook は optional です。
- config に接続しなくても schema / docs / bundled template を先に使えます。
- optional hook を有効化する場合も、observation event は evidence であり、評価判断の source of truth にはしません。

## Failure Behavior

- observation hook は書き込み失敗時でも `exit 0` を維持します。
- stderr には短い失敗メッセージだけを書きます。
- observation hook failure で Codex 実行を止めません。

## Safety Hook との違い

- observation hook は block のための hook ではありません。
- 既存 safety hook の block behavior は維持します。
- `blocking = true` は既存 safety hook の block event を記録するときだけ想定します。
- optional observe hook baseline 自体は `blocking = false` を既定にします。

## Secrets を記録しないルール

- secrets / tokens / API keys / raw prompt を記録しない。
- tool input は summary にする。
- path / command は必要最小限にする。
- observation hook は safety bypass ではない。

## run manifest との関係

- `hook-observation JSONL` は追跡用の補助 artifact です。
- `run.json` には path / count / blocking summary だけを載せ、raw event 全文は JSONL に残します。
- `SafetyBlocked` は count と既知 type に限って `run.json.safety` summary 更新に使えます。
- `evaluation.json` が interpretation の source of truth である点は変えません。

## Sample JSONL

```json
{"schema_version":1,"event_id":"20260627T120000Z-12345","run_id":null,"timestamp":"2026-06-27T12:00:00Z","source":"codex_hook","event":"PreToolUse","severity":"info","blocking":false,"tool":{"name":"Bash","operation":"command","target":"scripts/verify"},"cwd":"/workspace","input_summary":"Run verification command","decision":{"action":"observe","reason":"optional observation hook recorded the event"},"evidence":[],"metadata":{"hook":"observe.sh"}}
```

## Bash / PowerShell Hook の使い方

```bash
CODEX_HOOK_EVENT=PreToolUse \
CODEX_HOOK_TOOL_NAME=Bash \
CODEX_HOOK_TOOL_OPERATION=command \
CODEX_HOOK_TOOL_TARGET=scripts/verify \
CODEX_HOOK_INPUT_SUMMARY="Run verification command" \
bash .codex/hooks/observe.sh
```

```powershell
$env:CODEX_HOOK_EVENT = "PreToolUse"
$env:CODEX_HOOK_TOOL_NAME = "PowerShell"
$env:CODEX_HOOK_TOOL_OPERATION = "command"
$env:CODEX_HOOK_TOOL_TARGET = "scripts/verify"
$env:CODEX_HOOK_INPUT_SUMMARY = "Run verification command"
powershell.exe -ExecutionPolicy Bypass -File .codex/hooks/observe.ps1
```
