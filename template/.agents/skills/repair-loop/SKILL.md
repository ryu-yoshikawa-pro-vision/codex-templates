---
name: repair-loop
description: Use when applying review findings, fixing validation failures, or running a bounded Review -> Repair -> Validate loop.
---

1. `AGENTS.md`、`CODE_REVIEW.md`、`docs/reference/repair-loop.md` を読む。
2. `references/repair-workflow.md` を読み、入口条件、iteration記録、停止条件を確認する。
3. review findings / evaluation.json / validation failure / scope report を入力として整理する。
4. repair対象を `must_fix` / `should_fix` / `defer` / `reject` に分類する。
5. `--allowed-files` / `--expected-changed-files` / change-scope policy に合わせて修正範囲を確定する。
6. 各iterationで、変更内容、validation結果、残差、次アクションを記録する。
7. 同じ failure が繰り返される、scope violation が出る、unsafe action が必要になる、または max iteration に達した場合は停止して人間判断へ戻す。
8. repair結果は `evaluation.json` / failure taxonomy / REPORT.md に接続できる形でまとめる。
