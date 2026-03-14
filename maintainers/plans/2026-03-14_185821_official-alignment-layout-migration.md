# Source Repo 計画書テンプレート

## 0. 依頼概要
- 依頼内容: consumer-facing template を Codex 公式整合のレイアウトへ再編する。
- 背景: `template/docs/agent/` が正本、`.agents/skills/` が補助という現状は、公式の `AGENTS.md` + `.agents/skills/` + `.codex/` という責務分離に対して中間層が多い。
- 期待成果: `template/docs/agent/` を解体し、`AGENTS.md`・`.agents/skills/`・`docs/`・`.codex/` の役割が明確になった状態で spec / verify / tests / maintainer docs が整合している。

## 1. ゴール / 完了条件
- ゴール: consumer-facing template が `AGENTS.md` を常設指示、`.agents/skills/` を task-scoped workflow の正本、`.codex/` を config/runtime、`docs/` を人間向け補助資料として一貫した構造になる。
- 完了条件（DoD）:
  - `template/docs/agent/` が削除され、必要情報が `AGENTS.md`・skills・`docs/reference/` / `docs/guides/` に再配置されている
  - `PLANS.md` と `CODE_REVIEW.md` が薄い索引として skill を案内する
  - `spec/`、`template/scripts/verify*`、smoke/integration tests が新構成を前提に通る
  - 新 ADR、PROJECT_CONTEXT、history、README/MIGRATION が新レイアウトを説明している

## 2. スコープ
- In Scope:
  - `template/AGENTS.md`, `template/PLANS.md`, `template/CODE_REVIEW.md`
  - `template/.agents/skills/*`
  - `template/docs/*` の再配置
  - `spec/*`, `template/scripts/verify*`, `tests/*`
  - `maintainers/adr/*`, `maintainers/PROJECT_CONTEXT.md`, `maintainers/history/*`, `README.md`, `MIGRATION.md`
- Out of Scope:
  - 新しい skill 種別の追加
  - wrapper / execpolicy の挙動変更

## 3. 実行タスク
- [ ] 1. 新レイアウトを ADR / spec / maintainer docs に反映する
- [ ] 2. template の instruction / skill / docs を再編し `docs/agent/` を除去する
- [ ] 3. verify / tests / fixture / README 系を新契約へ更新する
- [ ] 4. 必須検証を実行し、結果を記録する

## 4. マイルストーン
- M1: 新レイアウトの責務と契約が ADR / spec で固定されている
- M2: consumer-facing template が新構造に置き換わっている
- M3: 検証が通り、source repo 文脈文書が更新されている

## 5. リスクと対策
- リスク:
  - 既存 verify / smoke が `docs/agent/*` を hard-code しており、変更漏れが起きやすい
  - `docs/agent/` 削除により参照切れが多点発生する
  - 既存 ADR 0004 と矛盾する記述が残る可能性がある
  - 対策:
    - 先に `rg` で参照箇所を網羅してから編集する
    - `spec` と verify / tests を同一バッチで更新する
    - 新 ADR で 0004 supersede を明記し、関連 docs を一括更新する

## 6. 検証方法
- 実施する確認:
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
  - `bash tools/validate-spec.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1`
  - `bash tests/smoke/test-template-layout.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
  - `bash tests/integration/test-codex-safety-harness.sh`
  - `rg -n "docs/agent/" template spec tests`
- 成功判定:
  - 想定した validation / smoke / integration が成功する
  - consumer-facing の `docs/agent/` 参照が除去されている

## 7. 成果物
- 変更ファイル:
  - `template/`, `spec/`, `tests/`, `maintainers/`, `README.md`, `MIGRATION.md`
- 付随ドキュメント:
  - 新 ADR
  - PROJECT_CONTEXT history
  - run REPORT

## 8. 備考
- `.codex/agents/` は導入しない。公式 docs の discovery / config 対象にないため。
