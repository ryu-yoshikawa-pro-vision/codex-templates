# TASK-005 change scope policy JSON catalog 実装計画

作成日時: 2026-06-27 17:38:13 JST  
対象リポジトリ: `ryu-yoshikawa-pro-vision/codex-templates`  
対象ブランチ: `feature/change-scope-policy-catalog`

## 1. `spec/` 影響

あり。`spec/change-scope-policy.json` を新規追加し、source repo 側の機械検証対象として `tools/validate-spec.sh` / `tools/validate-spec.ps1` に組み込む。

## 2. Goal

change scope policy を Markdown-only contract から「consumer-facing reference + source-repo JSON catalog」の二層構成へ移し、後続の `--allowed-files` / `--expected-changed-files` 実装前に変更範囲契約を固定する。

## 3. Current understanding

- 現状 `template/docs/reference/change-scope-policy.md` は path normalization、changed files、`allowed_files`、`expected_changed_files`、deleted / renamed / copied、`.codex/runs/` artifact exclusion を説明している。
- 同文書の `Deferred JSON Catalog` セクションでは、`spec/change-scope-policy.json` はまだ追加しない前提になっている。
- `tools/validate-spec.sh` と `tools/validate-spec.ps1` は run artifact / failure taxonomy / evaluation などの既存 static catalog を検証しているが、change scope policy catalog の検証はまだない。
- `template/scripts/verify` は change scope policy reference の存在と一部語句だけを見ており、spec file や source-of-truth 関係までは確認していない。
- 直近の TASK-006A 実装で `.codex/runs/<run_id>/run.json` baseline が導入され、今回の policy catalog はその後続タスクとして位置づけられている。

## 4. Assumptions

- 新規 catalog は既存 `spec/artifact-responsibility.json` や `spec/failure-taxonomy.json` と同様の reviewable static JSON とし、JSON Schema 自体は作らない。
- `case_sensitive: true` を catalog に明記し、比較 canonical format は `repo_relative_posix` に固定する。
- `template/codex-project.toml` の version bump は不要とする。理由は consumer-facing runner behavior をまだ変更しないため。

## 5. Source-repo changes

- `.codex/runs/20260627-173813-JST/` に plan / tasks / report を作成し、進捗と検証結果を残す。
- `maintainers/plans/2026-06-27_173813_change-scope-policy-catalog.md` に本計画を保存する。
- `tools/validate-spec.sh` / `tools/validate-spec.ps1` に catalog validation を追加する。

## 6. Consumer-facing changes

- `template/docs/reference/change-scope-policy.md`
  - Markdown contract を維持しつつ、`spec/change-scope-policy.json` が source repo 側の source-of-truth catalog であることを明記する。
  - `.codex/runs/` artifact exclusion と source changes 非混同の文言を維持する。
- `template/scripts/verify`
  - `spec/change-scope-policy.json` と `docs/reference/change-scope-policy.md` の存在確認を追加する。
  - `allowed_files`、`expected_changed_files`、`.codex/runs/`、`repo root`、`scope check`、`spec/change-scope-policy.json` の主要語句チェックを追加する。
- `CHANGELOG.md`
  - Unreleased に policy catalog 追加と Markdown / JSON の責務明確化を追記する。

## 7. やること

- `spec/change-scope-policy.json` を追加する。
- Markdown reference を JSON catalog と整合する内容へ更新する。
- Bash / PowerShell validator に同等の catalog validation を追加する。
- `template/scripts/verify` に存在・主要語句チェックを追加する。
- `CHANGELOG.md` を更新する。
- 指定 validation を実行し、結果を run report に記録する。

## 8. やらないこと

- `codex-task.sh` / `codex-task.ps1` への `--allowed-files` 実装
- `--expected-changed-files` 実装
- changed files collection
- scope violation detection
- `run.json.changed_files` の自動収集
- `run.json.safety.scope_violation` の自動更新
- hook observation
- subagent logging
- evaluation template / requirement 変更

## 9. Validation plan

実装後に以下を実行する。

```bash
bash tools/validate-spec.sh
bash template/scripts/verify
bash tests/integration/test-codex-safety-harness.sh
bash tests/integration/test-codex-task-harness.sh
```

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1
powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexTaskHarness.ps1
```

実行不能な検証があれば、run report とユーザー向け返答の両方に理由を残す。

## 10. 後続 PR でやること

- `--allowed-files`
- `--expected-changed-files`
- changed files collection
- scope violation detection

## 11. Migration / rollback

- Migration:
  - consumer repo が今回の doc / verify / spec 更新を取り込む場合、`docs/reference/change-scope-policy.md`、`scripts/verify`、`CHANGELOG.md`、新規 `spec/change-scope-policy.json` を同期する。
- Rollback:
  - 新規 catalog と validator / verify / doc / changelog の差分を戻せば、runner behavior を触らずに元の Markdown-only contract へ戻せる。

## 12. リスク

- Windows / WSL / Linux path 差分を contract に十分固定しないと後続 enforcement 実装でズレる。
- `.codex/runs/` artifact と source changes の混同が残ると、generated artifact exclusion が過剰に解釈される。
- glob support を早期に入れすぎると validator と runner の責務境界が曖昧になる。

## 13. 保存先

`maintainers/plans/2026-06-27_173813_change-scope-policy-catalog.md`
