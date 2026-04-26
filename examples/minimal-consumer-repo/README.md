# Minimal Consumer Repo

このディレクトリは、`template/` を consumer repo のルートへ展開したときに何が揃うべきかを説明する最小例です。

## 期待されるルート
- `AGENTS.md`
- `PLANS.md`
- `CODE_REVIEW.md`
- `.codex/`
- `.agents/`
- `docs/`
- `scripts/`

実体は `tools/sync-template.*` で任意ディレクトリへ展開してください。

## auto-net preset

最小 consumer repo でも、既定は safe mode のままです。network access つきの自律作業が必要な場合だけ、次を明示します。

```bash
bash scripts/codex-safe.sh --preset auto-net
```

`auto-net` は workspace 内編集と network access を許可しますが、削除・git commit 系・危険な remote script 実行は禁止します。
