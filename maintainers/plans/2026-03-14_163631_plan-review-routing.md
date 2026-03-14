# 計画書テンプレート

## 0. 依頼概要
- 依頼内容: Plan / Review 入口ファイルと repo local skill を追加し、Codex の mode 別導線を明示する。
- 背景: `docs/agent/` は維持しつつ、Plan Mode と review request で参照すべき入口を `AGENTS.md` から明示したい。
- 期待成果: `PLANS.md` / `CODE_REVIEW.md` / `.agents/skills/*` が追加され、関連文書と run ログに反映されている。

## 1. ゴール / 完了条件
- ゴール: Plan / Review の入口を repo ルートへ追加し、`AGENTS.md` と supporting docs から参照される構成にする。
- 完了条件（DoD）:
  - `AGENTS.md` に mode 別入口が明記されている
  - `PLANS.md` と `CODE_REVIEW.md` が追加されている
  - planning / review の repo local skill が追加されている
  - `docs/PROJECT_CONTEXT.md`、ADR、history、run ログが更新されている
  - 検証結果が確認できる

## 2. スコープ
- In Scope:
  - `AGENTS.md`
  - `PLANS.md`
  - `CODE_REVIEW.md`
  - `.agents/skills/*`
  - `docs/agent/overrides.md`
  - `docs/PROJECT_CONTEXT.md`
  - `docs/adr/`
  - `docs/history/`
- Out of Scope:
  - `docs/agent/` の全面 `.agent/` 移行
  - safety harness の実装変更
  - 既存テンプレート群の大幅リファクタ

## 3. 実行タスク
- [x] 1. `AGENTS.md` に Plan / Review 入口のルーティングを追加する
- [x] 2. `PLANS.md` / `CODE_REVIEW.md` と repo local skill を追加する
- [x] 3. `docs/PROJECT_CONTEXT.md`、ADR、history、run ログを更新する

## 4. マイルストーン
- M1: mode 入口ファイルを追加
- M2: `AGENTS.md` と supporting docs を整合
- M3: 静的検証と runtime 確認を実施

## 5. リスクと対策
- リスク:
  - nested Codex の runtime 確認が環境制約で不安定
  - 対策: `git diff --check` と `rg` による静的検証、PowerShell 側の preflight を併用する

## 6. 検証方法
- 実施する確認:
  - `git diff --check`
  - `rg -n "PLANS.md|CODE_REVIEW.md|\\.agents/skills" ...`
  - nested Codex の read-only planning / review request
- 成功判定:
  - 参照整合に問題がない
  - planning / review の双方で入口ファイル適用を確認できる

## 7. 成果物
- 変更ファイル:
  - `AGENTS.md`
  - `PLANS.md`
  - `CODE_REVIEW.md`
  - `.agents/skills/feature-plan/SKILL.md`
  - `.agents/skills/code-review/SKILL.md`
- 付随ドキュメント:
  - `docs/PROJECT_CONTEXT.md`
  - `docs/adr/0004-mode-entrypoints-and-repo-local-skills.md`
  - `docs/history/2026-03-14_162210_mode-entrypoints-update.md`

## 8. 備考
- `docs/agent/` は正本として維持する。
