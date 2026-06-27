# Observation & Subagent Baseline 計画

作成日時: 2026-06-27 23:15:30 JST  
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`  
対象ブランチ: `feature/observation-subagent-baseline`

## 1. Goal

PR-2 Observation & subagent baseline として、Codex / agent / subagent の挙動を後から評価できるように、observation event schema、subagent run schema、reference docs、optional hook baseline、validator/test baseline を追加する。

今回の主眼は observation layer の baseline であり、実行フロー変更や評価自動化ではない。

## 2. Current understanding

- `template/` が consumer-facing の配布面、`spec/` が contract の正本、`maintainers/` が source repo 文脈の保管先である。
- PR #16 相当の runner completion milestone は main に取り込まれており、`CHANGELOG.md` と `template/codex-project.toml` は `0.7.0` を示している。
- 既存 safety hook は `template/.codex/hooks/pre_tool_use_policy.py` / `.ps1` であり、`template/.codex/config.toml` では PreToolUse に接続されている。
- observation hook はまだ存在しない。
- `tools/validate-spec.*` と `template/scripts/verify` は schema / template / docs の存在、enum、sync をコードで検証している。
- `tests/integration/test-codex-task-harness.*` と `test-codex-safety-harness.*` は既存 runner / safety behavior の統合テストを担っている。

## 3. Assumptions

- optional observation hook は consumer template にファイルとして追加するが、既存 config には接続しない。
- `metadata` は top-level だけ strict にし、内部は free-form object として扱う。
- 新規 test は `tests/integration/test-observation-baseline.sh` と `tests/integration/Test-ObservationBaseline.ps1` を追加し、既存 test へ過剰に混ぜない。

## 4. Non-goals

- repair loop skill の追加
- harness improvement skill の追加
- run.json への observation summary 統合
- run.json への subagent summary 統合
- subagent-run artifact の自動生成
- hook event の実環境自動連携
- subagent 自動起動
- `codex-task` / `codex-safe` の実行フロー変更
- 既存 safety hook の block 条件変更
- evaluation judgement の自動化

## 5. Source-repo changes

- `spec/hook-observation.schema.json` を追加する。
- `spec/subagent-run.schema.json` を追加する。
- `tools/validate-spec.sh` と `tools/validate-spec.ps1` に新 schema の存在、主要 field、enum、bundled copy sync を追加する。
- `tests/integration/test-observation-baseline.sh` と `tests/integration/Test-ObservationBaseline.ps1` を追加する。
- `CHANGELOG.md` を更新する。
- run-local artifact と本計画書を更新する。

## 6. Consumer-facing changes

- `template/.codex/templates/hook-observation.schema.json` を追加する。
- `template/.codex/templates/subagent-run.schema.json` を追加する。
- `template/docs/reference/hook-observation.md` を追加する。
- `template/docs/reference/subagent-observation.md` を追加する。
- `template/docs/reference/run-artifacts.md` に observation / subagent artifact の責務追記を行う。
- `template/.codex/hooks/observe.sh` と `template/.codex/hooks/observe.ps1` を optional baseline として追加する。
- `template/scripts/verify` に docs / schema / optional hook の contract check を追加する。
- `template/codex-project.toml` の `template_version` を `0.8.0` へ更新する。

## 7. Reference files

- `maintainers/plans/2026-06-27_103240_codex-harness-strengthening.md`
- `template/scripts/codex-task.sh`
- `template/scripts/codex-task.ps1`
- `template/scripts/codex-safe.sh`
- `template/scripts/codex-safe.ps1`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/change-scope-policy.md`
- `template/docs/reference/evaluation.md`
- `template/docs/reference/failure-taxonomy.md`
- `template/.codex/hooks/`
- `template/.agents/`
- `template/AGENTS.md`
- `template/CODE_REVIEW.md`
- `template/PLANS.md`
- `tools/validate-spec.sh`
- `tools/validate-spec.ps1`
- `template/scripts/verify`
- `tests/integration/test-codex-safety-harness.sh`
- `tests/integration/Test-CodexSafetyHarness.ps1`
- `tests/integration/test-codex-task-harness.sh`
- `tests/integration/Test-CodexTaskHarness.ps1`
- `CHANGELOG.md`
- `template/codex-project.toml`

## 8. Implemented targets

- hook observation schema
- optional JSONL observation hook
- subagent run schema
- reference docs
- validator sync checks
- integration tests
- version / changelog update

## 9. Change strategy

### 9.1 Hook observation schema

- `spec/hook-observation.schema.json` を `additionalProperties: false` で追加する。
- required fields と enum は添付指示に揃える。
- `tool` は `object | null`、`cwd` は `string | null` とする。
- `decision.action` と `evidence[].kind` は enum を固定する。
- `metadata` は `type: object` とし、内部は柔軟に扱う。
- bundled copy を `template/.codex/templates/hook-observation.schema.json` に完全同期で追加する。

### 9.2 Optional JSONL hook

- `template/.codex/hooks/observe.sh` と `.ps1` を追加する。
- 既定出力は `.codex/observations/hooks.jsonl`、`CODEX_OBSERVATION_LOG` で上書き可能にする。
- `CODEX_RUN_ID` がなければ `run_id = null` を書く。
- failure 時は stderr に短文を出すだけで `exit 0` を維持する。
- safety bypass にならないよう block 判定ロジックは持たせない。
- config への hook 接続は行わない。

### 9.3 Subagent run schema

- `spec/subagent-run.schema.json` を `additionalProperties: false` で追加する。
- required fields、enum、`scope` / `parent_decision` / `sandbox` の nested contract を定義する。
- bundled copy を `template/.codex/templates/subagent-run.schema.json` に完全同期で追加する。

### 9.4 Artifact responsibility

- `template/docs/reference/run-artifacts.md` に `hook-observation JSONL` と `subagent-run.json` の役割を追記する。
- これらは evidence 補助であり、最終 interpretation の正本は引き続き `evaluation.json` であると明記する。
- run manifest 統合は後続 PR と明記する。

### 9.5 Safety preservation policy

- `pre_tool_use_policy.*` と既存 wrapper behavior は変更しない。
- observation hook は block 用途にしない。
- observation hook failure は Codex 実行停止条件にしない。
- `codex-safe.*` と `codex-task.*` の安全挙動・runner completion behavior は変更しない。

## 10. Validation plan

実装後に以下を実行する。

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
bash tests/integration/test-codex-safety-harness.sh
bash tests/integration/test-codex-task-harness.sh
bash tests/integration/test-observation-baseline.sh
```

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-ObservationBaseline.ps1
```

実行できない検証があれば `.codex/runs/<run_id>/REPORT.md` と最終報告へ理由を記録する。

## 11. Migration / rollback

- migration:
  - consumer repo が今回の更新を取り込む場合、new schema / docs / optional hook / verify をまとめて同期する必要がある。
- rollback:
  - new observation/subagent artifacts の追加は additive change であり、rollback は追加ファイルと verify/validator/test の対応差分を戻せばよい。
  - 既存 safety hook や wrapper の behavior change を含めないため、rollback 時の安全リスクは低い。

## 12. Risks / open issues

- Bash / PowerShell hook で timestamp と JSON serialization の差が出ると test parity を崩す可能性がある。
- optional hook を config へ接続しない設計は意図どおりだが、利用方法を docs に十分明記しないと consumer 側で迷う可能性がある。
- validator に enum / required field を重複実装するため、片系更新漏れのリスクがある。

## 13. Rollback plan

- 追加した schema / docs / hooks / tests / validator 差分を個別に巻き戻す。
- version bump と changelog も同時に戻す。
- rollback 判断時も `pre_tool_use_policy.*` と wrapper には手を入れない。

## 14. Follow-up PRs

- Repair loop skill
- Harness improvement skill
- `run.json` への observation summary 統合
- subagent-run artifact の自動生成
- hook event の実環境連携
