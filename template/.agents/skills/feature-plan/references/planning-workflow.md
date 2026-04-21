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

## Ambiguity handling
- Contract marker: `mandatory-question`
- Plan Mode では、AI が判断し切れない不透明点を推測で埋めてはいけない。
- 目的、成功条件、非目標、変更スコープ、対象ユーザー、DoD、検証方法、完了判定が曖昧な場合は必ず質問する。
- 破壊的変更、移行、削除、セキュリティ、外部連携、費用、運用負荷に影響する不透明点は必ず質問する。
- ユーザーの好みや優先順位で結論が変わる場合は必ず質問する。
- 既存 repo の明確な convention に従える局所実装、後から容易に修正できる細部、成果物の方向性を変えない安全側 default は、仮定として記録してよい。
- 質問は重要度順にまとめ、なぜ必要かと回答により何が変わるかを添える。
- 未回答の重要質問が残る場合、実装には進まず `Open questions` に残す。ユーザーが「仮定して進めてよい」と明示した場合のみ、仮定を計画に記録して進める。

## 出力ルール
- 実装順に沿って書く。
- 判定条件を曖昧にしない。
- 事実と推測を混ぜない。
- 実装へ進む前に `docs/plans/{yyyy-mm-dd}_{HHMMSS}_{plan_name}.md` を保存する。
- 必要なら `.codex/runs/<run_id>/PLAN.md` と `TASKS.md` にも落とし込む。
- plan-only では `docs/reports/` に report file を作らない。必要な記録はチャット返答と run-local `REPORT.md` に留める。

## Report file generation policy
- Allowed: ユーザーが保存を明示した場合、計画 DoD に report file が明記されている場合、複数ソース調査・監査・検証結果を後で参照する durable artifact として残す必要がある場合。
- Not allowed: plan-only、review-only、status update、軽い確認、通常の evidence command 結果、run progress 記録、チャットで完結する評価。
- review-only and plan-only do not create docs/reports files.
- 判断に迷う場合は report file を作らず、チャット返答と run-local `REPORT.md` に留める。

## Failure modes
- code を読む前に設計を閉じてしまう
- `Current understanding` に推測を混ぜる
- `Non-goals` を書かず、ついでの改善を混ぜる
- `Validation plan` が曖昧で Done 判定できない
- `Unknowns` を放置したまま実装に進む
- plan-only で `docs/reports/` に report file を作る
