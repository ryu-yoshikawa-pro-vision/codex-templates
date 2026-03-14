# Source Repository 向け Codex Working Agreement

Codex が `codex-templates` の source repository 自体を変更するときは、この文書に従うこと。

## 0. 最初に必ず読むもの
1) `maintainers/PROJECT_CONTEXT.md`
2) `maintainers/adr/`（最近の ADR を確認する）
3) `.codex/runs/`（最近の run があれば確認する）
4) この `AGENTS.md`

> `maintainers/PROJECT_CONTEXT.md` は source repository の現状に合わせて保つこと。  
> source repo の重要な設計判断は `maintainers/adr/` に記録すること。  
> consumer-facing instruction を変更するときは `template/AGENTS.md` と `spec/` を整合させること。ただし consumer repo の運用ルールを source repo 作業へ誤適用しないこと。

## 0.1 モード別の入口ファイル
- 複雑なタスク、明示的な計画依頼、Plan Mode のときは `PLANS.md` を読む。
- レビュー依頼または `/review` のときは `CODE_REVIEW.md` を読む。
- チャットで合意した計画を実装に移す前に、`maintainers/plans/` 配下へ JST 命名で保存する。

## 1. Run 初期化
- `run_id = YYYYMMDD-HHMMSS-JST` を使う。
- 現在の会話に active run がない場合は `.codex/runs/<run_id>/` を作る。
- `template/.codex/templates/{PLAN,TASKS,REPORT}.md` を雛形としてコピーする。
- run artifact は日本語で書く。
- ユーザーが新しい run を明示しない限り、同じ会話では同じ run を使い続ける。

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
- source repo の構造やワークフロー理解が変わったら `maintainers/PROJECT_CONTEXT.md` を更新する。
- PROJECT_CONTEXT の履歴は `maintainers/history/YYYY-MM-DD_HHMMSS_<summary>.md` に残す。
- 重要な設計判断は `maintainers/adr/` に記録する。
- consumer-facing の文書は `template/`、source repo の文書は `maintainers/` に分離して保つ。

## 6. Plan と Report の保存先
- Source-repo plans: `maintainers/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md`
- Source-repo reports: `maintainers/reports/{yyyy-mm-dd}_{HHMMSS}_{report_name}.md`
- タイムスタンプは JST (`Asia/Tokyo`) を使う。

## 7. 安全性 / スコープ
- 関連のないファイルは変更しない。
- consumer-facing のルールを root-level 文書へ戻し入れない。consumer-facing の内容は `template/` に置く。
- wrapper の挙動を更新するときは、`template/scripts/codex-safe.ps1` または `template/scripts/codex-safe.sh` の方針を基準にする。
- consumer-facing contract を変えたら、完了報告前に `spec/` と整合させる。

## 8. 必須検証
- 必要に応じて次の一部または全部を実行する。
  - `tools/validate-spec.ps1`
  - `bash tools/validate-spec.sh`
  - `bash template/scripts/verify`
  - `powershell.exe -ExecutionPolicy Bypass -File tests/integration/Test-CodexSafetyHarness.ps1`
  - `bash tests/integration/test-codex-safety-harness.sh`
- 実行できない検証があれば、run report とユーザー向けレポートの両方に明記する。

## 9. 言語ポリシー
- 内部思考: English
- ユーザー向け出力と run artifact: 日本語
- `AGENTS.md`: 日本語

## 10. 境界の再確認
- `template/` は consumer-facing distribution surface の唯一の正本。
- `maintainers/` は source repo の文脈、plans、reports、ADR、architecture notes を置く場所。
- `spec/` は docs / skills / wrappers が一致すべき contract の正本。
