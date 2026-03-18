---
name: code-review
description: Use when reviewing changes, handling /review, or doing self-review in this repository.
---

1. `AGENTS.md` と `CODE_REVIEW.md` を読む。
2. `references/review-workflow.md` を読み、観点の優先順と出力形式を固定する。
3. まず diff triage を行い、深掘りすべき変更領域を絞る。
4. 次に deep review を行い、correctness、security、behavioral regression、missing tests を優先して確認する。
5. 各 finding に severity、根拠、影響、ファイル参照を添える。
6. 問題がない場合も、その旨と残余リスクや未実施検証を明示する。
