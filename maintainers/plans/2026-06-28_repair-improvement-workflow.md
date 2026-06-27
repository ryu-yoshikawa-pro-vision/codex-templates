# Repair & Improvement Workflow Plan

作成日時: 2026-06-28 07:22 JST  
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`  
対象ブランチ: `feature/repair-improvement-workflow`

## 目的

PR-3 として、TASK-009 / TASK-010 をまとめた Repair & improvement workflow を consumer-facing の標準 workflow として追加する。対象は skill / docs / examples / validators / tests であり、runner automation は含めない。

## 参照ファイル

- `maintainers/plans/2026-06-27_103240_codex-harness-strengthening.md`
- `template/.agents/skills/code-review/SKILL.md`
- `template/.agents/skills/code-review/references/review-workflow.md`
- `template/.agents/skills/feature-plan/SKILL.md`
- `template/.agents/skills/feature-plan/references/planning-workflow.md`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/evaluation.md`
- `template/docs/reference/failure-taxonomy.md`
- `template/docs/reference/change-scope-policy.md`
- `template/docs/reference/hook-observation.md`
- `template/docs/reference/subagent-observation.md`
- `template/scripts/verify`
- `tools/validate-spec.sh`
- `tools/validate-spec.ps1`
- `tests/integration/test-observation-baseline.sh`
- `tests/integration/test-codex-safety-harness.sh`
- `.github/workflows/validate-template.yml`
- `CHANGELOG.md`
- `template/codex-project.toml`

## 実装対象

- `template/.agents/skills/repair-loop/`
- `template/.agents/skills/harness-improvement/`
- `template/docs/reference/repair-loop.md`
- `template/docs/reference/harness-improvement-loop.md`
- `template/examples/repair-loop/`
- `template/examples/harness-improvement/`
- `template/scripts/verify`
- `tools/validate-spec.sh`
- `tools/validate-spec.ps1`
- `tests/integration/test-repair-improvement-workflow.sh`
- `tests/integration/Test-RepairImprovementWorkflow.ps1`
- `.github/workflows/validate-template.yml`
- `CHANGELOG.md`
- `template/codex-project.toml`

## やること

- `repair-loop` skill と reference workflow を追加する。
- `harness-improvement` skill と reference workflow を追加する。
- repair loop / harness improvement の reference docs を追加する。
- `evaluation.schema.json` と failure taxonomy に整合する examples を追加する。
- `verify` と `validate-spec.*` に skill / docs / examples の存在・内容・JSON contract 検証を追加する。
- Bash / PowerShell integration test を追加し、CI に Bash test を組み込む。
- `template_version` を `0.9.0` に更新し、consumer-facing changelog / migration note を追記する。

## やらないこと

- `codex-task` の自動再実行
- `--max-iterations` による runner-level loop 実装
- repair iteration schema の追加
- harness improvement candidate schema の追加
- `run.json` への repair / improvement summary 統合
- subagent-run artifact の自動生成
- hook observation summary の自動統合
- Codex SDK runner / OpenAI Agents SDK integration
- safety hook block 条件や `codex-safe` の安全挙動変更
- execpolicy / permission / network 許可の緩和

## repair loop workflow

- `Review -> Repair -> Validate` を bounded workflow として定義する。
- 入口条件は review finding、validation failure、`evaluation.result = partial|fail`、actionable findings、明確な `allowed_files` を前提にする。
- 各 iteration は `iteration_number`、`input_findings`、`repair_plan`、`allowed_files`、`changed_files`、`validation_commands`、`validation_result`、`remaining_delta`、`decision` を記録する。
- findings は `must_fix` / `should_fix` / `defer` / `reject` / `needs_human` に triage する。
- stop condition、unsafe、scope violation、`--max-iterations` の reserved contract を明文化する。

## harness improvement workflow

- `evaluation.json`、validation result、hook observation、subagent record、review comment を evidence に harness improvement candidate を作る。
- candidate model は `candidate_id`、`target`、`failure_category`、`source_runs`、`evidence`、`expected_impact`、`risk`、`recommended_change`、`strictness`、`status`、`owner_decision` を持つ。
- `strictness = normal | strict | blocked` を定義し、safety layer / hooks / runner / spec に関わる提案は strict workflow とする。
- candidate は proposal であり、自動適用しない。実装修正と混ぜず follow-up として扱う。

## safety / scope policy

- unsafe または scope-violating finding は loop を継続して押し切らず、人間判断へ戻す。
- `allowed_files` と change-scope policy を repair planning に接続する。
- safety layer、hooks、execpolicy、`codex-safe.*`、`codex-task.*`、`spec/` を変える提案は strict workflow として分離する。
- blocked candidate は destructive operation、credential、external permission、policy bypass を必要とする提案に限定する。

## examples

- repair loop は 2 iteration 例を用意し、iteration 1 では validation gap が残り、iteration 2 で改善または停止判断に到達する形にする。
- evaluation examples は `spec/evaluation.schema.json` に適合させる。
- harness improvement candidates 例は最低 3 件とし、`normal` / `strict` / `blocked` を各 1 件以上含める。
- product implementation fix と harness improvement follow-up を分離する例を README と review doc に含める。

## validation plan

必須:

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
bash tests/integration/test-observation-baseline.sh
bash tests/integration/test-repair-improvement-workflow.sh
bash tests/integration/test-codex-safety-harness.sh
```

可能なら:

```powershell
pwsh -NoProfile -File tools/validate-spec.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-RepairImprovementWorkflow.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-ObservationBaseline.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1
```

検証できない項目があれば `.codex/runs/<run_id>/REPORT.md` と最終返答に明記する。

## rollback plan

- 変更は workflow / docs / examples / validators / tests に限定し、runner automation へ踏み込まないことで rollback 面を狭く保つ。
- 問題が出た場合は、追加した skill / docs / examples と validator/test entry を個別に切り戻せるよう、既存 runner behavior を不変に保つ。
- CI failure が出た場合は、schema / example / phrase check のどこが契約違反かを特定できる構成にする。

## 後続PRでやること

- `run.json` への repair-loop summary 統合
- repair iteration schema の追加要否判断
- harness improvement candidate schema の追加要否判断
- subagent-run artifact の自動生成
- hook observation summary の run manifest 統合
- Codex SDK runner evaluation ADR
