# Sample Runs

このディレクトリには説明価値のある curated sample run だけを置く。

- 日常運用の `.codex/runs/` は Git 追跡対象外とする。
- sample として残す run は、consumer-facing template の説明に再利用できるものに限る。

## auto-net example

明示的に network access つきの自律実装を行う場合だけ、managed preset を使う。

```bash
bash scripts/codex-safe.sh --preset auto-net
bash scripts/codex-task.sh --preset auto-net --prompt-file .codex/runs/<run_id>/PROMPT.md --verify-command "bash scripts/verify"
```

`auto-net` でも削除、git staging / commit / push、remote script piping、外部 resource deletion は行わない。不要に見えるファイルは `REPORT.md` の `Deletion candidates` に記録する。
