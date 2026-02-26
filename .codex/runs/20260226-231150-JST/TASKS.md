# Tasks

## Now
- [x] 1. 調査観点を整理し、危険コマンドの分類軸を決める
- [x] 2. 危険コマンドのカテゴリ・代表例・意味・リスク・注意点を整理する
- [x] 3. `docs/reports/` にMarkdownレポートを作成する
- [x] 4. 関連ドキュメント（runログ/PROJECT_CONTEXT）更新と最終確認を行う

## Discovered
- 作業中に発見したタスクはここに追記する（セッション内で増える前提）
- [x] D2. 危険コマンドを防ぐためのルール/ハーネス設計方針を整理して回答する
- [x] D3. Codexでのハーネス/ルール設定方法を調査し、`docs/plans/` に実装計画書を作成する
- [x] D4. 実装計画書をレビューし、懸念点（抜け・曖昧さ・回避経路）を確認して回答する
- [x] D5. 実装計画書に懸念点を反映して修正する
- [x] D6. 修正版を再レビューし、懸念点が解消されたことを確認する
- [x] D7. Codexの実装前提（CLIバージョン、execpolicy/rules適用方式、requirements可否）を実測確認する
- [x] D8. `.codex/rules/` に execpolicy ルールセットを実装し、`codex execpolicy check` で検証する
- [x] D9. `scripts/codex-safe.ps1` wrapper を実装し、危険引数・固定設定・fallback 判定を組み込む
- [x] D10. `AGENTS.md` / `docs/PROJECT_CONTEXT.md` / 補助ドキュメントを更新して運用手順を明記する
- [x] D11. 検証結果レポートを作成し、最終チェック（差分/動作確認）を実施する
- [x] D12. 実装計画に対する実装完全性レビューを実施し、不足点を抽出する
- [x] D13. 不足点（ログ出力、回避ケース検証、運用整備、`-c` 衝突バグ）を修正する
- [x] D14. 修正後に再レビュー・再検証を行い、重大な不足がないことを確認する
- [x] D15. GitHub Desktop の LF/CRLF 警告の原因（`.gitattributes` と Git設定）を確認して説明する
- [x] D16. GitHub Desktop の改行警告を減らすために `.gitattributes` / `.editorconfig` / 主要ファイルの改行を調整する

## Blocked
- なし
