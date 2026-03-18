# Review Workflow

## 使う場面
- `/review`
- ユーザーからのレビュー依頼
- 実装完了前の自己レビュー

## Do not use
- 実装前の設計相談
- 要件整理やタスク分解が主目的のとき
- 差分がなく、単にコード説明だけが必要なとき

## Phase 1: diff triage
### Goal
- 差分のどこに本当の危険があるかを仕分けし、深掘り対象を絞る。

### Diff classification
- 仕様変更
- バグ修正
- リファクタリング
- テスト変更
- 設定変更
- 依存更新
- ドキュメント変更

### High-risk areas
- auth / permission
- persistence / migration
- async ordering
- contract change
- exception handling
- cache / state
- feature flag branches

### What needs deep review
- correctness high risk
- security high risk
- regression high risk
- test gap risk

### Potential missing tests
- failure paths
- boundary values
- permission differences
- flag on/off
- call-site contract changes

## Phase 2: deep review
### correctness
- 条件分岐の抜け
- null / undefined / empty の扱い漏れ
- 境界値の破綻
- 非同期処理の順序問題
- 例外時の契約不一致
- 変更前後で戻り値や副作用が変わっていないか

### security
- 権限チェックの抜け
- 機密情報の露出
- 入力検証不足
- インジェクションや XSS / CSRF 相当経路
- 安全でないログ出力

### behavioral regression
- 既存フローの前提を壊していないか
- 呼び出し元の期待契約が変わっていないか
- feature flag の ON/OFF 両方で成立するか
- cache や state の整合性が保たれるか

### missing tests
- 変更内容に対して必要なテストが足りているか
- 失敗系、境界値、権限差分が未検証ではないか
- 既存テストの意図が変更で崩れていないか

### maintainability
- 責務混在
- 副作用の散乱
- 不自然な抽象化
- 将来の修正を難しくする暗黙ルール

## 出力ルール
- findings-first で返す。
- severity 順に並べる。
- 各 finding に根拠、影響、ファイル参照を付ける。
- `Suggested fix` は方向性を短く示す。
- 好みだけの指摘や根拠の弱い推測は finding にしない。
- 根拠が弱い論点は `Open questions` に回す。
- 問題がない場合も残余リスクと未実施検証を明記する。

## Failure modes
- triage を飛ばして変更量だけで優先順位を決める
- 差分起因でない既存問題を findings に混ぜる
- 好みベースのコメントで findings を埋める
- `Why it matters` や `Evidence` が弱く、修正の必要性が伝わらない
- 未確認事項を finding にして confidence を偽装する
