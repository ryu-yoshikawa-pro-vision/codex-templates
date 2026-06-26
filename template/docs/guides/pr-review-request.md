# PRレビュー依頼テンプレート

PRレビューを依頼するときは、対象、確認範囲、優先観点、出力形式を先に固定する。

## Template

```md
対象PR:
確認範囲:
- 実装差分
- CI結果
- ドキュメント差分

優先観点:
1. correctness / behavioral regression
2. security / data handling
3. missing tests
4. maintainability
5. documentation

出力形式:
- Findings first
- Severity
- Location
- Why it matters
- Evidence
- Suggested fix
- Open questions
- Verdict
```

## Example

```md
https://github.com/<owner>/<repo>/pull/<number> をレビューしてください。
CIと現在の実装差分を含めて確認し、残っている問題だけ severity 順に出してください。
```

## Notes

- review-only の場合、`docs/reports/` に report file を作らない。
- 重要な判断根拠はチャット返答または `.codex/runs/<run_id>/REPORT.md` に残す。
- GitHub上の変更操作は、ユーザーが明示した場合だけ行う。
