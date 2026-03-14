# Code Review Entry Point

## 適用条件
- ユーザーがレビューを依頼した場合
- `/review` を使う場合
- 実装完了前の自己レビュー

## 必須動作
1. Findings-first で報告する。
2. 正しさ、回帰リスク、検証不足を優先して確認する。
3. 重大度順に並べ、根拠と影響を明示する。
4. 問題がない場合も、その旨と残余リスクや未実施検証を明示する。

## 参照先
- ベーステンプレート: `docs/agent/templates/reviewer-template.md`
- 役割定義: `docs/agent/agent-role-design.md` の Reviewer 節

## 最低限含める観点
- 要件充足
- 正常系 / 異常系の正しさ
- 副作用や状態変化の妥当性
- テスト、lint、typecheck、build など検証の妥当性
- 変更範囲の肥大化や不要なリファクタ混入

## 出力方針
- まず findings を列挙し、その後に要約を書く。
- 各 findings にはファイル参照と再現根拠を添える。
- 役割ベースで考える場合は Reviewer の責務に沿って整理する。
