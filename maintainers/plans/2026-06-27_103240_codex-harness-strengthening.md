# Codex ハーネス強化計画

作成日時: 2026-06-27 10:32:40 JST  
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`  
対象ブランチ: `docs/codex-harness-strengthening-plan`

## 1. Goal

`codex-templates` を、単なる Codex 運用テンプレートから、Codex の実行結果を観測・評価・改善できるハーネスへ強化する。

目標は、Codex そのものを別 SDK で置き換えることではない。既存の `AGENTS.md`、`scripts/codex-safe.*`、`scripts/codex-task.*`、execpolicy rules、hooks、subagents、skills を中核に置き、Codex が失敗しにくく、失敗しても原因が残り、次回の instructions / skills / rules / hooks / runner 改善へつながる構造を作る。

## 2. Current understanding

- このリポジトリは consumer repo に配布する Codex 運用テンプレートの source repository である。
- `template/` が consumer-facing distribution surface、`maintainers/` が source repo 側の運用文脈、`spec/` が contract の正本という分離になっている。
- 既存の強みは、Codex 実行時の安全制約、run artifact、planning / review entry point、subagent の read-only / workspace-write 分離である。
- 既存の弱点は、実行結果を後から機械的に評価・集計・改善へ変換するための構造化データが不足している点である。
- OpenAI Agents SDK を中心にした別エージェントアプリ化は、今回の主目的ではない。
- 今回は Codex ネイティブなハーネス強化を優先する。

## 3. Non-goals

この計画では、次を目的にしない。

- OpenAI Agents SDK を core dependency として導入する。
- `codex-safe` / `codex-task` を別 SDK で置き換える。
- 汎用 agent framework を新規開発する。
- writable subagent を安易に増やす。
- `auto-net` を通常実行の便利 preset として拡大する。
- 人間レビュー不要の完全自律運用を目指す。

## 4. Target architecture

目指す流れは以下。

```text
User request
  ↓
Task classification
  ↓
Plan / Review / Implementation / Investigation / Repair routing
  ↓
Safety preset selection
  ↓
Codex execution through existing wrappers
  ↓
Validation
  ↓
Review / Evaluation
  ↓
Failure classification
  ↓
Harness improvement candidates
  ↓
AGENTS / skills / rules / hooks / runner improvement
```

強化対象は以下の 6 層に分ける。

| Layer | Purpose | Main targets |
| --- | --- | --- |
| Instruction layer | Codex の判断を安定させる | `AGENTS.md`, `PLANS.md`, `CODE_REVIEW.md`, `.agents/skills/` |
| Safety layer | 危険操作を防ぐ | `.codex/rules/`, `.codex/hooks/`, `codex-safe.*` |
| Execution layer | 再現可能に実行する | `codex-task.*`, run id, output schema |
| Observation layer | 何が起きたか追える | `run.json`, report JSON, JSONL logs |
| Evaluation layer | 成功・失敗を判定する | `evaluation.json`, failure taxonomy |
| Improvement layer | 次回改善へ変換する | improvement candidates, harness improvement skill |

## 5. Implementation strategy

PR 分割ではなく、タスク分割として進める。

### TASK-001: Run manifest contract を追加する

目的: Codex 実行結果を機械集計できる単位にする。

追加候補:

- `spec/run-manifest.schema.json`
- `template/docs/reference/run-artifacts.md`
- `template/.codex/templates/RUN_MANIFEST.json`

主なフィールド:

```json
{
  "schema_version": 1,
  "run_id": "20260627-103240-JST",
  "task_type": "implementation",
  "workflow_level": "standard",
  "preset": "safe",
  "runtime": "host",
  "agents_used": [],
  "repo": null,
  "branch": null,
  "base_branch": null,
  "changed_files": [],
  "commands": [],
  "validation": {
    "status": "not_run",
    "commands": []
  },
  "safety": {
    "network": false,
    "delete_attempt_blocked": false,
    "git_mutation_attempt_blocked": false,
    "scope_violation": false
  },
  "status": "pending",
  "failure_category": null
}
```

DoD:

- schema が source repo の validation 対象になる。
- `run_id`, `task_type`, `workflow_level`, `preset`, `status` の必須性が定義される。
- `template/docs/reference/run-artifacts.md` に run artifact の責務と配置が説明される。

### TASK-002: Evaluation contract を追加する

目的: Codex の実行結果を評価し、次回改善へつなげる。

追加候補:

- `spec/evaluation.schema.json`
- `template/.codex/templates/EVALUATION.md`
- `template/docs/reference/evaluation.md`

主な評価観点:

- task completion
- scope control
- validation confidence
- safety compliance
- reviewability
- maintainability
- reproducibility

主な出力例:

```json
{
  "schema_version": 1,
  "run_id": "20260627-103240-JST",
  "result": "partial",
  "score": {
    "task_completion": 0.8,
    "scope_control": 1.0,
    "validation_confidence": 0.6,
    "safety_compliance": 1.0,
    "reviewability": 0.7
  },
  "findings": [
    {
      "category": "missing_validation",
      "severity": "medium",
      "detail": "Required validation was not executed."
    }
  ],
  "improvement_candidates": [
    {
      "target": "AGENTS.md",
      "recommendation": "Clarify fallback validation policy."
    }
  ]
}
```

DoD:

- evaluation の schema が定義される。
- run artifact と evaluation の関係が説明される。
- evaluation は成果物評価だけでなく、harness improvement candidate を持てる。

### TASK-003: Failure taxonomy を標準化する

目的: 失敗原因を毎回同じ分類で残せるようにする。

追加候補:

- `spec/failure-taxonomy.json`
- `template/docs/reference/failure-taxonomy.md`

初期分類:

| Category | Meaning | Improvement target |
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

DoD:

- `evaluation.schema.json` の `failure_category` が taxonomy と整合する。
- `codex-task` / repair loop で参照可能な分類として説明される。

### TASK-004: `codex-task` を runner として強化する

目的: Codex 実行時に task metadata と scope metadata を残せるようにする。

追加候補オプション:

```text
--task-type plan|review|implementation|investigation|repair
--workflow-level lightweight|standard|strict
--allowed-files <path-list>
--expected-changed-files <path-list>
--max-iterations <n>
--record-run-manifest
--record-evaluation
--require-clean-git
--require-run-id
```

初期対応では、破壊的に増やしすぎない。まずは以下を優先する。

1. `--task-type`
2. `--workflow-level`
3. `--record-run-manifest`
4. `--allowed-files`
5. `--expected-changed-files`

DoD:

- `codex-task.sh` と `codex-task.ps1` の両方で同等の引数を扱える。
- `--record-run-manifest` 指定時に `.codex/runs/<run_id>/run.json` を作成できる。
- `--allowed-files` 指定時に diff のスコープ外変更を検出できる。
- 既存の safe / readonly / auto-net preset の意味を変えない。

### TASK-005: Hook を観測レイヤーとして拡張する

目的: Hook を危険操作ブロックだけでなく、Codex 行動ログの構造化に使う。

検討対象イベント:

- `PreToolUse`
- `PostToolUse`
- `SubagentStart`
- `SubagentStop`
- `Stop`

初期対応案:

- 既存 `PreToolUse` の destructive guard は維持する。
- 追加 hook は最初から block 目的にしない。
- run manifest へ統合する前に、JSONL で観測ログを出すだけに留める。

DoD:

- 既存 hook の safety behavior を壊さない。
- hook が使えない環境でも wrapper / execpolicy の既存安全性が残る。
- 観測 hook の出力先と失敗時挙動が明確になる。

### TASK-006: Subagent 実行ログを構造化する

目的: subagent の利用効果を後から評価できるようにする。

追加候補:

- `spec/subagent-run.schema.json`
- `template/docs/reference/subagent-observation.md`

記録例:

```json
{
  "agent": "test_investigator",
  "purpose": "check missing coverage for changed files",
  "sandbox": "read-only",
  "input_files": [],
  "summary": "...",
  "parent_decision": "accepted",
  "used_in_final_plan": true,
  "changed_files": []
}
```

DoD:

- read-only subagent と writable subagent の記録項目を分ける。
- `implementation_worker` の allowed files / changed files / scope compliance を記録できる。
- writable subagent を増やす前に評価可能な形にする。

### TASK-007: Repair loop skill を追加する

目的: Review -> Repair -> Validate の反復を repo 標準 workflow として定義する。

追加候補:

- `template/.agents/skills/repair-loop/SKILL.md`
- `template/.agents/skills/repair-loop/references/repair-workflow.md`
- `template/docs/reference/repair-loop.md`

基本ルール:

- 各 iteration で findings, repair changes, validation result, remaining delta を残す。
- max iteration を設定する。
- 同じ failure が繰り返される場合は停止し、人間判断へ戻す。
- unsafe / scope violation は自動 repair で押し切らない。

DoD:

- repair loop の入口条件と停止条件が明確である。
- `CODE_REVIEW.md` と矛盾しない。
- `evaluation.json` と failure taxonomy に接続できる。

### TASK-008: Harness improvement skill を追加する

目的: 実行結果・評価結果を、ハーネス改善候補へ変換する。

追加候補:

- `template/.agents/skills/harness-improvement/SKILL.md`
- `template/.agents/skills/harness-improvement/references/improvement-workflow.md`
- `template/docs/reference/harness-improvement-loop.md`

対象:

- `AGENTS.md`
- `PLANS.md`
- `CODE_REVIEW.md`
- `.agents/skills/`
- `.codex/rules/`
- `.codex/hooks/`
- `scripts/codex-safe.*`
- `scripts/codex-task.*`
- `spec/`

DoD:

- harness improvement は実装変更と分離される。
- improvement candidate は evidence / failure category / expected impact を必須にする。
- safety layer の変更は Strict workflow 扱いにする。

### TASK-009: Codex SDK runner は後段検証に回す

目的: 将来的な runner 改善候補として Codex SDK を評価する。ただし、既存 wrapper の置き換えを前提にしない。

追加候補:

- `examples/codex-sdk-runner/README.md`
- `maintainers/adr/YYYY-MM-DD_codex-sdk-runner-evaluation.md`

評価観点:

- 既存 `codex-task` と同等以上の safety を保てるか。
- run manifest / evaluation をより正確に記録できるか。
- Windows / WSL / Linux で安定するか。
- consumer repo への配布負荷が許容できるか。

DoD:

- SDK 導入判断を保留または experimental に留める ADR がある。
- core template へ入れる条件が明文化される。

## 6. Suggested initial implementation order

最初の対応は、以下に絞る。

1. `spec/run-manifest.schema.json`
2. `spec/evaluation.schema.json`
3. `spec/failure-taxonomy.json`
4. `template/docs/reference/run-artifacts.md`
5. `template/docs/reference/evaluation.md`
6. `template/docs/reference/failure-taxonomy.md`
7. `tools/validate-spec.*` の拡張
8. `template/scripts/verify` の拡張

理由:

- まず contract を固めないと、runner / hook / subagent 拡張が場当たりになる。
- いきなり `codex-task` を大きく変えると既存安全ハーネスを壊すリスクがある。
- run manifest / evaluation / taxonomy があれば、次の PR 以降で実装効果を測れる。

## 7. Risks

### RISK-001: ハーネスが複雑化しすぎる

対策:

- 最初は schema と docs を中心にする。
- runner の挙動変更は小さく分ける。
- `AGENTS.md` に詳細を詰め込まず、skills / reference docs に逃がす。

### RISK-002: 評価項目が形骸化する

対策:

- score だけにしない。
- findings と improvement candidates を必須にする。
- failure taxonomy と接続する。

### RISK-003: Subagent が増えて責任境界が曖昧になる

対策:

- writable subagent を増やさない。
- 先に subagent run logging を入れる。
- parent decision を必ず記録する。

### RISK-004: `auto-net` が便利枠として使われる

対策:

- `auto-net` の既存禁止事項を維持する。
- network / dependency install / external access の記録を必須化する。
- 将来的に `--require-run-id` と組み合わせる。

### RISK-005: OpenAI Agents SDK / Codex SDK に寄りすぎる

対策:

- core は Codex CLI wrapper / rules / hooks / skills のままにする。
- SDK は examples / ADR / experimental に留める。
- 既存 safety layer を迂回する integration は採用しない。

## 8. Validation plan

初期対応では以下を通す。

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
bash tests/integration/test-codex-safety-harness.sh
```

PowerShell 環境では以下も確認する。

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1
```

検証できない環境がある場合は、実行不可理由を run report と PR description に明記する。

## 9. Completion criteria for this plan

この計画自体の完了条件は以下。

- source repo 側の `maintainers/plans/` に保存されている。
- Codex 強化の方向性が OpenAI Agents SDK 中心ではなく Codex harness 中心に修正されている。
- 初期対応タスク、後続タスク、リスク、検証方針が明確である。
- 以後の実装 PR / タスク化の土台として使える。

## 10. Next action

次に進める場合は、TASK-001 から TASK-003 をまとめて contract-first で実装する。

具体的には、以下を最初の実装対象にする。

- `spec/run-manifest.schema.json`
- `spec/evaluation.schema.json`
- `spec/failure-taxonomy.json`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/evaluation.md`
- `template/docs/reference/failure-taxonomy.md`
- `tools/validate-spec.*` の contract validation 追加
- `template/scripts/verify` の contract validation 追加
