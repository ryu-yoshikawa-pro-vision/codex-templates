# Project Context for the Source Repository

## 目的
- `codex-templates` v2 の source repository として、consumer-facing template、仕様、検証、履歴を分離して保守する。

## 現在の設計原則
- `template/` が consumer へ渡す唯一の配布面。
- `maintainers/` が source repo 自体の文脈、履歴、ADR、計画、レポートの保存先。
- `spec/` が workflow / naming / routing / safety の単一正本。
- `tools/` と `tests/` が source repo の保守と検証を担う。
- root の `AGENTS.md`、`PLANS.md`、`CODE_REVIEW.md` は source repo の保守作業用入口。
- consumer-facing template では `AGENTS.md` が常設 instruction surface、`.agents/skills/` が task-scoped workflow の正本、`.codex/` が config/runtime、`docs/reference/` が人間向け補助資料。
- consumer-facing `scripts/` は `codex-safe`（手動対話）、`codex-task`（非対話実装）、`codex-sandbox`（Docker 実験）の 3 層ハーネスを持つ。
- consumer-facing `.codex/config.toml` は `workspace-write` + `untrusted` + cached web search + workspace network disabled を標準 baseline とする。
- consumer-facing `.codex/config.toml` は明示指定専用の `repo_auto_net` profile を持ち、wrapper の `--preset auto-net` でのみ approval never + workspace network enabled を使う。wrapper default は `safe` のまま維持する。
- consumer-facing execpolicy は global rules を safe baseline とし、auto-net 専用 rules を `template/.codex/rules-auto-net/` に分離する。
- consumer-facing wrapper は `--run-id` / `-RunId` を受け取り、run がある作業では `.codex/runs/<run_id>/artifacts|reports|logs` に出力を集約する。
- command-based deletion は禁止する。`apply_patch` は差分単位で確認できる通常の編集手段として許可し、tracked runtime artifact の配布除外は明示された `git rm --cached -- <path>` の index-only migration に限定する。
- auto-net でも削除、git add/commit/push/rm/reset/clean、remote script piping、外部 resource deletion は禁止する。PreToolUse hook は補助防御として扱い、唯一の安全境界にはしない。

## 運用の要点
- 計画依頼または計画 handoff は `maintainers/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md` に保存する。
- `maintainers/reports/` は durable な調査・監査・検証結果の保存先。review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録では作らない。
- source repo の run 進捗と実行ログは `.codex/runs/<run_id>/REPORT.md` と `.codex/runs/<run_id>/logs/` に残す。
- `maintainers/PROJECT_CONTEXT.md` を更新したら、更新履歴を `maintainers/history/` の同一セッションファイルへ追記する。
- consumer-facing 契約変更では `spec/` を先に更新し、`tools/validate-spec.*` で整合を確認する。
- consumer-facing 配布物に関する説明は root ではなく `template/` 配下の文書に置く。
- root `PLANS.md` と `CODE_REVIEW.md` は source repo 用 contract を定義し、source/consumer 境界、validation、rollback、finding 形式を明示する。
- consumer-facing `template/PLANS.md` と `template/CODE_REVIEW.md` は mode の索引を保ったまま、required output format を固定する。
- Plan Mode では、AI が判断し切れない不透明点を推測で埋めず、目的・成功条件・非目標・スコープ・DoD・検証方法・破壊的変更・移行・削除・セキュリティ・外部連携・費用・運用負荷・ユーザー優先順位に影響する曖昧さを必ず質問する。
- consumer-facing planning/review skill は 2 本を維持し、reference で `repo mapping -> change planning` と `diff triage -> deep review` を扱う。
- reference は `Use / Do not use`、出力セクション、観点チェック、failure modes を持ち、`SKILL.md` より具体的な task workflow を担う。

## ディレクトリ構成
- `template/`: consumer repo の配布面
- `maintainers/adr/`: source repo の意思決定記録
- `maintainers/plans/`: source repo の計画書
- `maintainers/reports/`: source repo のレポート
- `maintainers/history/`: PROJECT_CONTEXT 更新履歴
- `maintainers/architecture/`: source repo の構造説明
- `spec/`: consumer-facing 契約の単一正本
- `tools/`: template 同期・spec 検証などの maintainer 補助ツール
- `tests/`: source repo 向け fixture / smoke / integration tests
- `examples/`: curated sample runs と導入例
- `.codex/runs/`: source repo 作業時の一時 run。日常の run は Git 追跡対象外。

## 補足メモ
- consumer repo 側の living documentation 雛形は `template/docs/PROJECT_CONTEXT.md` にある。
- consumer repo 側の workflow 詳細は `template/.agents/skills/*/references/` に置き、`template/docs/agent/` は廃止した。
- consumer repo 側の非対話実装では `template/scripts/codex-task.* --run-id <run_id>` が output/report/log を run-local 成果物として残し、Docker runtime は `CODEX_DOCKER_IMAGE` 必須の experimental path とする。
- template 適用後の初期化補助として `template/codex-project.toml` と `template/scripts/init-project.*` を持つ。
- runtime artifact の既定保存先は Git 追跡対象外。`template/.codex/artifacts/`, `template/.codex/reports/`, `template/.codex/logs/*.jsonl`, `template/.codex/runs/` は配布対象外にする。
- source repo の historical documents は過去時点の path を含みうる。現在の正本は `spec/` と本ファイルで判断する。
- template contract の検証は `spec/` と `template/scripts/verify*` / `tests/smoke/*` の両方で行う。
- auto-net contract の検証は safe default、明示 preset、profile、rules-auto-net、削除禁止を合わせて確認する。
