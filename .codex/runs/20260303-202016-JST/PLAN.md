# Plan

## Objective
- `docs/plans/` と `docs/reports/` のファイル命名規則を「年月日 + 時分秒」を含む形式へ統一する。
- `docs/PROJECT_CONTEXT.md` の更新履歴運用を `docs/history/` へ分離し、同一セッション内で同一履歴ファイルを使う規則を明文化する。

## Scope
- In:
  - `AGENTS.md` の関連規則（命名規則、PROJECT_CONTEXT更新履歴運用）
  - `docs/PROJECT_CONTEXT.md` の運用要点/配置メモ
  - `docs/plans/README.md` の命名規則
  - `docs/history/` の新規作成と本セッション履歴ファイルの作成
- Out:
  - 既存の過去成果物ファイル名の一括リネーム
  - 既存ADRの改訂

## Assumptions
- ユーザー要望の「時分秒」は JST ベースの `HHMMSS` を指す。
- `docs/history/` の履歴ファイル名は `YYYY-MM-DD_HHMMSS_<summary>.md` 形式で管理する。

## Hypotheses
- H1: 命名規則は `AGENTS.md` と `docs/plans/README.md`、`docs/PROJECT_CONTEXT.md` を更新すれば運用上の齟齬を解消できる。
- H2: `PROJECT_CONTEXT.md` 更新履歴を `docs/history/` に分離することで、本文の可読性を保ちながら証跡を残せる。

## Research Plan
- Round 1 Query: リポジトリ内の命名規則記述箇所を `rg` で特定する。
- Round 2 Query: なし（ローカル規約改定のみで完結）。
- Exit Criteria:
  - 主要仮説ごとに支持/反証の根拠がある
  - 未解決論点に次アクションがある

## Approach
- 既存規約記述を確認し、命名規則の差分を定義する。
- `AGENTS.md` を主規約として更新し、関連ドキュメントへ同一ルールを反映する。
- `docs/history/` に本セッションの PROJECT_CONTEXT 更新履歴ファイルを作成して運用を開始する。
- 変更後に差分確認と検証コマンドを実行し、REPORTへ記録する。

## Definition of Done
- `AGENTS.md` に以下が明記されている:
  - `docs/plans/` と `docs/reports/` の新規ファイル命名に時分秒を含めること
  - `docs/PROJECT_CONTEXT.md` 更新履歴を `docs/history/` で管理し、同一セッションで同一履歴ファイルを使うこと
- `docs/PROJECT_CONTEXT.md` と `docs/plans/README.md` の記述が上記規則と整合している。
- `docs/history/` に本セッション履歴ファイルが作成され、今回更新の要約が記録されている。
- 変更差分と検証結果が `REPORT.md` に追記されている。

## Risks / Unknowns
- 既存ファイル名規則（日付のみ）との混在期間が発生する。
- `docs/reports/` に命名規則を明示する専用READMEが存在しないため、`AGENTS.md` と `PROJECT_CONTEXT.md` で補完する。

## Thinking Log
- 2026-03-03 20:20 (JST): ユーザー要求は規約改定が中心。既存成果物のリネームは要求されていないため、今後生成分の規約更新に限定する。
- 2026-03-03 20:20 (JST): `PROJECT_CONTEXT.md` の更新履歴は本文内ではなく `docs/history/` に分離し、同一セッション追記ルールを明文化する。
- 2026-03-03 20:25 (JST): `docs/reports/README.md` を追加して reports 命名ルールの参照先を補強。`scripts/verify` は PASS=3/FAIL=0 で完了したため本タスクを完了判定とする。
- 2026-03-03 20:30 (JST): ユーザー要求によりレビューサイクルを追加。規約矛盾・命名規則漏れを再点検し、懸念があれば即時修正して再検証する。
- 2026-03-03 20:33 (JST): 修正後に `scripts/verify` を再実行し PASS=3/FAIL=0 を確認。命名規則・履歴運用の矛盾は解消したためレビュー完了と判断。
