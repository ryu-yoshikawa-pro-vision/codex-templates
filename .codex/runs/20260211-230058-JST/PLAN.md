# Plan

## Objective
- ユーザー指摘（別セッションで既存runに追記してしまった問題）を解消するため、`AGENTS.md` のrun初期化ルールを明確化する。
- 「新しい会話/セッションでは新しいrunを作る。既存runを再利用するのはユーザーが明示した場合のみ」という規約を、今後誤解が起きない文言へ修正する。

## Scope
- In:
  - `AGENTS.md`
  - `docs/PROJECT_CONTEXT.md`
  - `.codex/runs/20260211-230058-JST/{PLAN.md,TASKS.md,REPORT.md}`
- Out:
  - その他のコード・設定ファイル

## Assumptions
- 既存runの再利用は、ユーザーが「このrun_idを使う」と明示した場合のみ許可する。
- 今回は運用ルール文言の明確化であり、ADR追加が必要なアーキテクチャ変更には該当しない。

## Approach
- 現行 `AGENTS.md` のRun initialization節とOne-shot prompt節を確認する。
- 新セッション時のrun新規作成必須ルールと、既存run再利用の明示条件を追記する。
- Living documentationとして `docs/PROJECT_CONTEXT.md` に運用注意点を反映する。
- runログ更新、検証、コミット、PRメッセージ作成まで実施する。

## Definition of Done
- `AGENTS.md` に「新セッションでは新しいrun作成」「既存run再利用は明示指示時のみ」が明記されている。
- `docs/PROJECT_CONTEXT.md` に同趣旨の運用注意が追記されている。
- このセッション専用run（`20260211-230058-JST`）でPLAN/TASKS/REPORTが更新されている。
- 変更を検証し、コミットと `make_pr` を完了している。

## Risks / Unknowns
- 「session/conversation」の定義解釈が実行環境差で曖昧になり得るため、文言を具体化して誤運用を抑制する。

## Thinking Log
- 2026-02-11 23:00 JST: ユーザー指摘どおり、セッション跨ぎのrun再利用を防止する明示文が不足していたため、AGENTSに明文化を追加する。
- 2026-02-11 23:00 JST: 同ルールをOne-shot promptにも反映し、非対話実行時にも同じ挙動を強制する。
