# Plan/Review Guidance Hardening

## 0. 依頼概要
- 依頼内容: 2026-03-18 input の分析結果に基づき、source repo と consumer-facing template の plan/review guidance を強化する。
- 背景: 現行 repo は mode 分離の骨格は持つが、`PLANS.md` / `CODE_REVIEW.md` と skills/reference の内容がまだ薄く、plan/review の出力粒度が揺れやすい。
- 期待成果: 既存 2 skills 構成を維持したまま、plan/review contract、spec、verify、history を整合更新する。

## 1. ゴール / 完了条件
- ゴール:
  - root と template の plan/review 文書を、実装に使える明確な contract に更新する。
  - skills/reference に `repo mapping -> change planning`、`diff triage -> deep review` を取り込む。
  - `spec/` と `verify` / smoke test に新しい contract を反映する。
- 完了条件（DoD）:
  - root/template/spec/verify/history の差分が計画どおりに揃っている。
  - `bash tools/validate-spec.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1`
  - `bash tests/smoke/test-template-layout.sh`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1`
    の結果が記録されている。

## 2. スコープ
- In Scope:
  - root `PLANS.md` / `CODE_REVIEW.md`
  - `template/AGENTS.md` / `template/PLANS.md` / `template/CODE_REVIEW.md`
  - `template/.agents/skills/feature-plan/*`
  - `template/.agents/skills/code-review/*`
  - `spec/routing.yaml` / `spec/workflow.yaml`
  - `template/scripts/verify*`
  - `tests/smoke/*`
  - `maintainers/PROJECT_CONTEXT.md` / `maintainers/history/*`
- Out of Scope:
  - 4 skill への再編
  - wrapper runtime behavior の変更
  - eval 基盤や metrics 集計の導入

## 3. 実行タスク
- [ ] 1. run artifact と source-repo plan/report の初期化
- [ ] 2. root 文書の plan/review contract 強化
- [ ] 3. consumer-facing docs と 2 skills/reference の強化
- [ ] 4. spec と verify/smoke の追従
- [ ] 5. PROJECT_CONTEXT/history の更新
- [ ] 6. validate/verify/smoke の実行と結果記録

## 4. マイルストーン
- M1: 記録系初期化と root/template 文書更新完了
- M2: spec/verify/smoke 更新完了
- M3: PROJECT_CONTEXT/history 更新と検証完了

## 5. リスクと対策
- リスク: verify の文字列チェックが文書変更に過敏になり保守性を下げる
  - 対策: heading や core phrase のみに絞って検査し、全文一致や長文固定を避ける
- リスク: source repo 文書に consumer-facing wording を混入させる
  - 対策: root 側は source repo 固有の境界確認を最初に明記する
- リスク: PowerShell 系の検証が環境依存で SKIP になる
  - 対策: 実行可否を report と最終報告へ明記する

## 6. 検証方法
- 実施する確認:
  - spec validate
  - template verify
  - smoke tests
  - 差分確認
- 成功判定:
  - spec と verify が PASS
  - 文書が plan/review contract を明確に表現している
  - root と template の境界が崩れていない

## 7. 成果物
- 変更ファイル:
  - root 文書
  - template 文書 / skills / reference
  - `spec/`
  - `template/scripts/verify*`
  - `tests/smoke/*`
  - `maintainers/PROJECT_CONTEXT.md`
  - `maintainers/history/*`
- 付随ドキュメント:
  - `maintainers/reports/2026-03-18_165514_plan-review-guidance-hardening.md`
  - `.codex/runs/20260318-165514-JST/*`

## 8. 備考
- 2026-03-18 input は参考情報として利用し、現行 ADR と衝突する提案は採用しない。
- stable public contract は既存 2 skills を維持する。
