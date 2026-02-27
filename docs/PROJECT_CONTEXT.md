# Project Context

## 目的
- Codexが多様なタスクを実行する際に、計画（PLAN）→タスク（TASKS）→行動ログ（REPORT）を厳密に運用できるようテンプレートと規約を整備する。

## 運用の要点
- ユーザーが「計画を立てるように」と依頼した場合は、`docs/plans/TEMPLATE.md` をベースに `docs/plans/{yyyy-mm-dd}_{プラン名}.md` で計画書を新規作成する（JST日付）。
- 反復的な仮説検証タスクでは、PLANに「仮説」「検索ラウンド」「終了条件」を明記し、検索結果の採否理由をREPORTへ記録してTASKSへ反映する。
- 計画レビューでは、少なくとも「終了条件の明確性」「証跡フォーマット」「改善提案の承認フロー」を確認し、懸念があれば修正→再レビューを反復する。
- 自律運用タスクでは、`PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` を標準プロトコルとして運用し、Web検索はラウンド制で証跡を残す。
- 自己改善提案は `docs/agent/improvement-guardrails.md` の L1/L2/L3 承認境界に従う（L2/L3 はユーザー承認必須）。
- 並列マルチエージェントの追加要望は `docs/plans/2026-02-27_parallel-multi-agent-orchestration-plan.md` で別計画として管理し、必要時のみ段階的に実装する。
- 低リスク・小規模タスクでは `AGENTS.md` の Lightweight Execution Mode を適用できる（ただし安全制約・承認境界・run更新は省略しない）。
- セッション開始時に `.codex/runs/<run_id>/` を作成し、テンプレートをコピーする。
- 別セッションでは既存runへの追記をデフォルトで行わず、新しいrunを作成する（既存runの継続はユーザー明示時のみ）。
- 思考や判断理由は PLAN の Thinking Log に追記する。
- 実装・調査などの行動ログは REPORT に逐次追記する。
- 追加タスクは TASKS の Discovered に追記する。
- `docs/PROJECT_CONTEXT.md` は各プロジェクトの実態に合わせて調整し、開発の進行に伴って更新し続ける。
- 完了報告前の品質ゲートでは、プロジェクトで設定されている formatter / lint / typecheck を実行し、エラーがないことを確認してから報告する。
- 運用ドキュメントの言語方針として、`PLAN.md` / `TASKS.md` / `REPORT.md` は日本語で記述し、`AGENTS.md` は英語のみで管理する。

## ディレクトリ構成
- `.codex/templates/`: PLAN/TASKS/REPORT のテンプレート
- `.codex/runs/`: セッションごとの実行ログ
- `.codex/rules/`: Codex `execpolicy` のリポジトリローカルルール（`*.rules`）
- `.codex/logs/`: Codex安全ハーネスの実行ログ（JSONL、通常は `.gitignore` で管理）
- `.codex/config.toml`: Codex の project-scoped 設定プリセット（任意利用）
- `.codex/requirements.toml`: Codex の要件ドキュメント（管理配布/機能有効時の補助用途）
- `docs/adr/`: 運用や方針の意思決定記録
- `docs/plans/`: ユーザー向け計画書のテンプレートと成果物
- `docs/plans/README.md`: 計画書の命名規則と運用手順のガイド
- `docs/reports/`: 調査メモ、比較表、運用レポートなどの成果物（Markdown中心）
- `docs/agent/`: エージェント運用向け補助ドキュメント（例: Codex安全ハーネス）
- `docs/agent/templates/`: 役割別（Planner/Researcher/Executor/Reviewer）と改善提案のテンプレート
- `docs/agent/overrides.md`: AGENTS から常に読み込むプロジェクト共通規定（必須）
- `scripts/`: 補助スクリプト（例: `scripts/codex-safe.ps1`）
- `scripts/verify`: 品質ゲートを一括実行する統一エントリポイント

## 成果物配置メモ
- 計画書ではない調査・分析系のドキュメントは `docs/reports/` に日付付きMarkdownで配置すると整理しやすい。

## Codex安全運用メモ
- Codex の危険コマンド抑止は、`AGENTS.md`（ソフト制御）だけでなく、`.codex/rules/*.rules`（`execpolicy`）と `scripts/codex-safe.ps1`（wrapper）を組み合わせる多層防御で運用する。
- bash環境では `scripts/codex-safe.sh` を同等ポリシーの wrapper として利用する。
- `scripts/codex-safe.ps1` は、危険な CLI 引数の拒否、`sandbox/approval` の固定注入、`codex execpolicy check` による preflight を行う。
- `scripts/codex-safe.sh` は、PowerShell版と同様に危険引数拒否・preflight・JSONLログ出力を実行する。
- `scripts/codex-safe.ps1` は既定で `.codex/logs/codex-safe-YYYYMMDD.jsonl` にイベントログを書き出す（`-NoLog` で無効化可能）。
- `scripts/verify` で execpolicy判定、wrapperテスト、利用可能な検証を1コマンドで実行できる。
- `.codex/requirements.toml` は補助的な要件定義として保持し、実際の強制可否は Codex の利用形態（managed policy / feature 設定）に依存する。

## AGENTS拡張運用の指針
- プロジェクト固有のツール/スキル指示を分離したい場合は、ルート `AGENTS.md` に「追加指示ファイルの読込順」を明記し、詳細は別ファイル（例: `docs/agent/overrides.md`）に置く。
- 本リポジトリでは `docs/agent/overrides.md` を必須ファイルとして扱い、作業開始前に必ず読み込んで適用する。
- 上記の参照型は、共通ルール（AGENTS）と可変ルール（追加指示）を分離でき、更新差分を小さく保ちやすい。
- ディレクトリ単位で強い上書きが必要な場合は、対象配下に別の `AGENTS.md` を置く階層型を使う。スコープ境界が明確になる一方で、複数ファイル間の整合管理コストが増える。
- 運用推奨:
  - リポジトリ共通の方針変更が多い場合: 参照型を第一選択。
  - サブディレクトリごとに責務・技術栈が大きく異なる場合: 階層型を併用。

## 2026-02-27 監査知見（AIエージェント基本開発要件）
- 本リポジトリは、PLAN/TASKS/REPORTと安全ハーネスを中心に「基本的な開発運用」は満たす一方、汎用展開では一部改善余地がある。
- `AGENTS.md` §10 が要求する `Open Issues` / `Next Action` は、`.codex/templates/REPORT.md` に初期定義されておらず、テンプレート整合の改善余地がある。
- `.codex/templates/TASKS.md` の初期 `D1`/`B1` チェックボックスは、実タスクが無い初期状態でも進捗計算ノイズになり得る。
- 安全ハーネスは `scripts/codex-safe.ps1` で強力だが、PowerShell依存のため環境差（PATH/OS）により実行可能性がぶれる場合がある。
- 汎用性向上には、最小実行コマンド（例: `verify`）の標準化と、軽量タスク向け運用モードの追加が有効。
