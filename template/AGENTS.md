# Codex Working Agreement

Codex は、このリポジトリで作業を始める前にこの文書へ従うこと。

## 0. 最初に必ず読むもの
1) `docs/PROJECT_CONTEXT.md`
2) `docs/adr/`（最近の ADR を確認する）
3) `.codex/runs/`（最近の run があれば確認する）
4) この `AGENTS.md`

> `docs/PROJECT_CONTEXT.md` は living document として保つこと。  
> 重要な設計判断は ADR として記録すること。

## 0.1 モード別の入口ファイル
- 複雑なタスク、明示的な計画依頼、Plan Mode のときは `PLANS.md` を読み、`.agents/skills/feature-plan/SKILL.md` を使う。Plan では planning に集中し、実装やレビューを混ぜない。
- レビュー依頼または `/review` のときは `CODE_REVIEW.md` を読み、`.agents/skills/code-review/SKILL.md` を使う。Review では findings を返し、実装や設計相談へ逸れない。
- チャットで合意した計画を実装に移す前に、`docs/plans/` 配下へ保存する。

## 1. Run 初期化
- `run_id = YYYYMMDD-HHMMSS-JST` を使う。
- 現在の会話に active run がない場合は `.codex/runs/<run_id>/` を作る。
- 以下をコピーする。
  - `.codex/templates/PLAN.md`
  - `.codex/templates/TASKS.md`
  - `.codex/templates/REPORT.md`
- run artifact は日本語で書く。

## 2. 実行ループ
1) `.codex/runs/<run_id>/TASKS.md` のタスクを上から順に実行する。  
2) 各タスク完了後に次を行う。  
   - `TASKS.md` のチェックを更新する  
   - `REPORT.md` に JST 時刻の記録を追記する  
   - `Progress: <NN>% (<done>/<total>)` を含める  
3) 作業中に見つかったタスクは `## Discovered` に追加する。  
4) 判断メモは `PLAN.md` に、行動ログは `REPORT.md` に追記する。

## 3. Progress ルール
- 分母は `## Now` + `## Discovered` の checkbox task
- `## Blocked` は分母に含めない
- 表記は `Progress: <NN>% (<done>/<total>)`

## 4. ユーザー向けレポート
すべての返答に以下を含めること。
1) 5件以内の `Summary`
2) `Progress: <NN>% (<done>/<total>)`
3) 完了していない場合は `Next`
4) 実行コマンド/結果と主要ファイルを含む `Evidence`

## 5. Living Documentation
- プロジェクト理解が変わったら `docs/PROJECT_CONTEXT.md` を更新する。
- PROJECT_CONTEXT の履歴は `docs/history/YYYY-MM-DD_HHMMSS_<summary>.md` に残す。
- 重要な設計判断は `docs/adr/` に記録する。

## 6. Plan と Report の保存先
- Plans: `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md`
- Reports: `docs/reports/{yyyy-mm-dd}_{HHMMSS}_{report_name}.md`
- タイムスタンプは JST (`Asia/Tokyo`) を使う。
- `docs/reports/` は durable な調査・監査・検証結果の置き場であり、通常のレビュー返答、進捗報告、軽い確認結果、run 内ログの既定保存先ではない。
- Report file を生成してよいのは、ユーザーが保存を明示した場合、計画 DoD に report file がある場合、複数ソース調査・監査・検証結果を後で参照する必要がある場合のみ。
- review-only、plan-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価では `docs/reports/` にファイルを作らない。
- 判断に迷う場合は report file を作らず、チャット返答と `.codex/runs/<run_id>/REPORT.md` に留める。

## 7. 安全性 / スコープ
- 関連のないファイルは変更しない。
- プロジェクト配下の読み書きは許可する。ただし shell / PowerShell / git などの command によるファイル削除、履歴破壊、配布対象除去は明示承認なしに行わない。command-based deletion is forbidden.
- command-based deletion is forbidden.
- `apply_patch` は差分単位で意図を確認できる通常の編集手段として許可する。
- 手動の Codex 実行には `scripts/codex-safe.ps1` または `scripts/codex-safe.sh` を優先する。
- 非対話の `codex exec` には `scripts/codex-task.ps1` または `scripts/codex-task.sh` を優先する。
- 明示的な依頼と外部 sandbox がない限り、`--dangerously-bypass-approvals-and-sandbox` は使わない。
- repository の execpolicy ルールは `.codex/rules/*.rules` 配下で管理する。

## 8. 必須検証
- 必要に応じて次の一部または全部を実行する。
  - `bash scripts/verify`
  - project formatter / lint / typecheck / tests / build
- 実行できない検証があれば、run report とユーザー向けレポートの両方に明記する。

## 9. 言語ポリシー
- 内部思考: English
- ユーザー向け出力と run artifact: 日本語
- `AGENTS.md`: 日本語

## 10. 自律的な調査ループ
- 未知がある依頼では、`PLAN.md` に仮説を定義する。
- 根拠は `REPORT.md` に記録する。
- 実行に移せる発見は `TASKS.md` に落とし込む。
- 長い task-specific workflow は `AGENTS.md` に直接書き込まず、repo-local skill を使う。
- plan の詳細形式は `PLANS.md` と planning reference、review の詳細形式は `CODE_REVIEW.md` と review reference に委譲する。

## 11. 改善ガバナンス
- L1: wording のみの文書改善は、`REPORT.md` に記録すれば自己承認でよい。
- L2: workflow や template 構造の変更は、実装前にユーザー承認が必要。
- L3: permission / sandbox / approval / wrapper behavior の変更は、実装前に明示承認と rollback plan が必要。

## 12. Safety Harness
- 手動実行は `scripts/codex-safe.ps1` または `scripts/codex-safe.sh` を優先する。
- output/report を残す非対話実行は `scripts/codex-task.ps1` または `scripts/codex-task.sh` を優先する。
- `scripts/codex-sandbox.ps1` または `scripts/codex-sandbox.sh` は opt-in の Docker sandbox 実験時だけ使う。
- wrapper behavior、blocked option、preflight expectation が関係する場合は `docs/reference/codex-safety-harness.md` を参照する。
- manual / task / Docker runtime の使い分けは `docs/reference/codex-implementation-harness.md` を参照する。
- 既定の project config は `repo_safe` 相当の workspace-write + untrusted approval とし、live web search と追加 writable root は明示 opt-in にする。

## 13. Lightweight Mode
- 狭く低リスクなタスクでのみ許可する。
- その場合でも run artifact と 1 件以上の evidence command は残す。

## 14. Workflow Level
- Lightweight: 単一ファイルや低リスクの軽微修正。run artifact と evidence command は残すが、`docs/reports/` file は作らない。
- Standard: 通常の実装・修正。`.codex/runs/<run_id>/` を使い、必要な検証を実行する。
- Strict: permission / sandbox / approval / wrapper behavior / external integration / data handling を触る作業。計画、rollback、明示検証を必須にする。
