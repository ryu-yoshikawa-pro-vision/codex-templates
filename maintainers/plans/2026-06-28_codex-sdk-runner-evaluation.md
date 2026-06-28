# Codex SDK runner evaluation plan

## 目的

- TASK-011 として、Codex SDK runner を core template へ採用する前に必要な評価基準、採用条件、不採用条件、experimental 条件を ADR と source-repo-only examples として整理する。

## 背景

- このリポジトリは consumer repo へ配布する Codex 運用テンプレートの source repository である。
- 現行の canonical runner baseline は `template/scripts/codex-task.sh` / `template/scripts/codex-task.ps1` であり、安全補助、非対話実行、run artifacts、evaluation validation、scope check を担っている。
- 今後 runner 機能を拡張する場合、wrapper に責務を積み増すのか、SDK runner を後段で experimental に評価するのかを分ける判断軸が必要である。

## 参照ファイル

- `maintainers/plans/2026-06-27_103240_codex-harness-strengthening.md`
- `README.md`
- `template/docs/reference/codex-implementation-harness.md`
- `template/docs/reference/codex-safety-harness.md`
- `template/docs/reference/run-artifacts.md`
- `template/docs/reference/evaluation.md`
- `template/docs/reference/change-scope-policy.md`
- `template/docs/reference/repair-loop.md`
- `template/docs/reference/harness-improvement-loop.md`
- `template/scripts/codex-task.sh`
- `template/scripts/codex-task.ps1`
- `template/scripts/codex-safe.sh`
- `template/scripts/codex-safe.ps1`
- `spec/run-manifest.schema.json`
- `spec/evaluation.schema.json`
- `spec/failure-taxonomy.json`

## 今回やること

- `codex-task` baseline と SDK runner 候補の比較観点を ADR に明文化する。
- source-repo-only の `examples/codex-sdk-runner/` を追加し、評価フローと contract checklist を文書化する。
- `README.md` に source repo examples の一部として 1 行だけ導線を追加する。

## 今回やらないこと

- SDK runner の実装。
- `codex-task` / `codex-safe` の置き換えや挙動変更。
- `template/` 配下の consumer-facing 変更。
- `run.json` への SDK runner 統合。
- `evaluation.json` 自動生成。
- repair-loop 自動実行。
- safety policy / approval / sandbox policy の変更。

## 成果物

- `maintainers/adr/2026-06-28_codex-sdk-runner-evaluation.md`
- `examples/codex-sdk-runner/README.md`
- `examples/codex-sdk-runner/contract-checklist.md`
- `README.md` の最小追記

## 評価観点

- Safety: `safe` / `readonly` / `auto-net` と同等以上の安全境界を維持できるか。
- Artifacts: output、report JSON、JSONL log、`run.json`、`evaluation.json` との責務分離を保てるか。
- Validation: schema validation、`verify-command`、`require-*` 系 precondition を再現できるか。
- Scope control: `allowed_files` / `expected_changed_files`、untracked/deleted/renamed/generated files の扱いを維持できるか。
- Portability: Windows PowerShell、WSL、Linux、GitHub Actions で同じ contract を満たせるか。
- Consumer distribution: source repo example に留めるべきか、consumer repo に配布可能かを判断できるか。

## validation plan

- `bash tools/validate-spec.sh`: source repo specs と examples の整合性が壊れていないことを確認する。
- `bash template/scripts/verify`: consumer-facing template の既存 contract が壊れていないことを確認する。
- `bash tests/integration/test-repair-improvement-workflow.sh`: repair / improvement workflow の既存integration contractが壊れていないことを確認する。
- `bash tests/integration/test-observation-baseline.sh`: observation / subagent baseline の既存contractが壊れていないことを確認する。
- `bash tests/integration/test-codex-safety-harness.sh`: safety harness の既存contractが壊れていないことを確認する。
- 可能なら `pwsh -NoProfile -File tools/validate-spec.ps1` を実行し、PowerShell版のspec validationがBash版と同等に通ることを確認する。
- Windows PowerShell 5.1 環境では、代替として `powershell -ExecutionPolicy Bypass -File tools/validate-spec.ps1` を実行する。

## rollback plan

- source repo docs 追加のみのため、問題があれば追加した ADR / example / README 追記を個別に戻せる。
- `codex-task` baseline、consumer-facing template、spec、tests の contract は変更しないため、運用 rollback は不要とする。

## follow-up

- SDK runner を評価する場合は、この ADR と checklist を evidence record として使い、gap を harness improvement candidate に記録する。
- core template への採用は、別 PR で adoption conditions を満たしたことを示してから判断する。
