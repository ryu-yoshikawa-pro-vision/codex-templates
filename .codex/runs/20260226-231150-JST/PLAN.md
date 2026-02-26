# Plan

## Objective
- AIエージェントが実行し得る危険なコマンドを種類別に整理し、意味・主なリスク・注意点を日本語のMarkdownレポートとして作成する。

## Scope
- In:
- 一般的なCLI/シェル（Linux/macOS/Windows/PowerShell）で実行される危険コマンドの分類
- 代表的なコマンド例、意味、危険性、AIエージェント運用上の注意点
- このリポジトリ内のMarkdownレポート作成
- Out:
- 実環境での危険コマンド実行検証
- 具体的な攻撃手順の詳細化
- セキュリティ製品導入や組織ポリシーの策定そのもの

## Assumptions
- レポートの保存先は `docs/reports/` を新規作成して配置する。
- 主目的は防御・レビュー観点の整理であり、危険性の説明は高レベルに留める。

## Approach
- 既存ドキュメントと運用ルールを確認してrunを初期化する。
- 危険コマンドをカテゴリ分け（削除/破壊、権限変更、永続化、情報流出、ネットワーク変更、クラウド/DB/コンテナ、外部取得実行など）する。
- Markdownレポートを作成し、AIエージェント向けのレビュー観点・防止策を記載する。
- 体裁確認と簡易チェックを行い、runログとPROJECT_CONTEXTを更新する。

## Definition of Done
- 危険コマンドの種類と意味がカテゴリ別に整理されたMarkdownファイルが作成されている。
- レポートに代表例、危険性、AIエージェント運用上の注意が含まれている。
- runのPLAN/TASKS/REPORTが更新され、進捗が記録されている。
- 可能な範囲の品質チェック結果（該当設定なしを含む）が記録されている。

## Risks / Unknowns
- コマンド例が過度に具体的だと危険: 防御目的の説明に限定し、実行手順の詳細は避ける。
- 環境依存差分（Linux/Windows）: OS別に明記して誤用を減らす。

## Thinking Log
- 思考や判断の理由はここに逐次追記する（作業中に更新）。
- 不明点の整理、選択肢比較、決定理由を簡潔に記録する。
- 2026-02-26 23:11 (JST): 依頼はドキュメント作成中心。リポジトリに `docs/reports/` が未存在のため、新規作成して日付付きレポートを置く方針にする。AGENTSの運用に従いrunログを逐次更新する。
- 2026-02-26 23:18 (JST): 分類軸は「破壊・停止・改変・権限・永続化・外部実行・流出・クラウド/DB・コンテナ・VCS」に分ける。単体コマンド名だけでなく、危険フラグやパイプ実行パターンも併記する。
- 2026-02-26 23:23 (JST): `docs/PROJECT_CONTEXT.md` に `docs/reports/` を成果物置き場として追記する。今回はアーキテクチャ判断ではなく運用整理のためADR追加は不要と判断。
- 2026-02-26 23:31 (JST): フォローアップ質問は実装相談（ルール/ハーネス設計）。コード変更要求ではないため、回答は設計指針中心にしつつ、すぐ実装できる構成（allowlist + コマンド正規化 + リスク分類 + 承認フロー）を具体化して提示する。
- 2026-02-26 23:47 (JST): 新しい依頼は「Codex固有の設定方法を調査して実装計画を作る」。`docs/plans/` 配下に計画書を作る必要がある（AGENTS §9）。調査結果は local CLI help と OpenAI公式 docs を併用し、実装計画にはバージョン依存の確認タスクを含める。
- 2026-02-26 23:58 (JST): `codex-cli 0.104.0-alpha.1` で `execpolicy check` を利用可能と確認。計画では `AGENTS.md`（ソフトルール）+ `.codex/rules/*.rules`（判定）+ `requirements.toml`（最小要件）+ `config profile`（利用者設定）+ wrapper（強制導線）の多層構成を採用する。
- 2026-02-27 00:06 (JST): 計画レビューでの主な懸念は、wrapper の `--config`/`-c` による回避経路未定義、`.rules` の実行時適用確認不足、`requirements.toml` の適用条件を判定するゲート未定義。致命的ではないが、実装前にタスクへ落とすと安全性が上がる。
- 2026-02-27 00:13 (JST): 懸念点を計画に反映し、再レビューを実施。`-c/--config` 回避、`.rules` 実行時適用、`requirements.toml` 分岐、PowerShell回避ケース、タイトル識別性の課題は計画上で解消できたため、追加の計画修正は不要と判断。
- 2026-02-27 00:22 (JST): ユーザー指示により実装フェーズへ移行。計画書に沿って `.codex/rules`・`scripts/codex-safe.ps1`・（可能なら）`.codex/requirements.toml`・運用ドキュメント・検証レポートを実装する。実装中は `codex execpolicy check` でルールの inline test と判定結果を確認する。
- 2026-02-27 00:35 (JST): wrapper は引数許可リスト/拒否リスト方式とし、ユーザー指定の `-c/--config`・`--sandbox`・`--ask-for-approval`・`--profile`・`--add-dir`・`-C/--cd` を拒否、wrapper 側で安全値を固定注入する構成にした。project profile は `.codex/config.toml` に残すが wrapper の実行成立性を優先して実際の引数注入はしない。
- 2026-02-27 00:48 (JST): `.rules` の実行時自動読込の完全検証は今回未実施。代替として wrapper の preflight で `codex execpolicy check` による主要ケースの判定確認を毎回実行し、ルール破損/意図しない緩和を fail-fast で検知する実装にした。`requirements.toml` は schema に沿って作成しつつ、強制可否は運用依存として docs に明記する。
- 2026-02-27 01:09 (JST): 実装完全性レビューで、(1) wrapper ログ出力未実装、(2) PowerShell回避ケースの検証不足、(3) `.codex/logs` の git 汚染対策不足、(4) wrapper の残余引数パラメータ名 `CodexArgs` と `-c` の略称衝突バグを確認。ログ機能追加・テスト拡張・`.codex/logs/.gitignore` 追加・`PassthroughArgs` への改名で修正し、再検証を通した。
- 2026-02-27 01:19 (JST): GitHub Desktop の改行警告についての質問。`.gitattributes` と `core.autocrlf` を確認し、リポジトリ固有設定に基づいて説明する（設定変更は依頼されていないため未実施）。
- 2026-02-27 01:26 (JST): ユーザーの「調整してください」により改行方針を実装で調整。`.gitattributes` に拡張子別 `eol` を追加し、`.editorconfig` も新規追加。さらに `AGENTS.md` と `docs/PROJECT_CONTEXT.md` の混在改行を LF に正規化して GitHub Desktop の警告要因を減らす。
