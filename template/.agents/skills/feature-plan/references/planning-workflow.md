# Planning Workflow

## 使う場面
- 複雑な依頼
- 複数ファイルや複数段階にまたがる依頼
- Plan Mode
- 実装前に変更範囲、検証、移行を固める必要がある依頼

## Do not use
- 変更対象が 1 ファイルで明確な軽微修正
- typo 修正や wording-only 修正
- 既に計画と safe change surface が確定している追従実装

## Phase 1: repo mapping
### Goal
- 関連コード、実行経路、既存テスト、設定の地図を作り、どこまで安全に変更できるかを見極める。

### Checklist
1. 関連 code / test / config / docs を探索する。
2. `Entry points` を列挙する。
3. `Main flow` を短く説明する。
4. `Key abstractions` を整理する。
5. `Existing tests` を確認する。
6. `Safe change surface` と `Unknowns` を分ける。

### 出力セクション
- Entry points
- Main flow
- Key abstractions
- Existing tests
- Safe change surface
- Unknowns

## Phase 2: change planning
### Goal
- repo mapping の結果を、実装者が追加判断なしで進められる計画へ変換する。

### Checklist
1. `Goal` を短く言い換える。
2. `Current understanding` と `Assumptions` を分ける。
3. `Non-goals` を切り出す。
4. `Impacted areas` と `Files to inspect` を整理する。
5. `Change strategy` を段階化する。
6. `Validation plan` を定義する。
7. `Risks` と `Open questions` を決める。

### 変更方針を書くときの観点
- 何を変えるか
- なぜその順番か
- 失敗すると何が壊れるか
- rollback や feature flag で退避できるか

### Validation candidates
- unit test
- integration test
- e2e test
- manual verification
- log / metrics confirmation
- rollback confirmation

## 出力ルール
- 実装順に沿って書く。
- 判定条件を曖昧にしない。
- 事実と推測を混ぜない。
- 実装へ進む前に `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md` を保存する。
- 必要なら `.codex/runs/<run_id>/PLAN.md` と `TASKS.md` にも落とし込む。

## Failure modes
- code を読む前に設計を閉じてしまう
- `Current understanding` に推測を混ぜる
- `Non-goals` を書かず、ついでの改善を混ぜる
- `Validation plan` が曖昧で Done 判定できない
- `Unknowns` を放置したまま実装に進む
