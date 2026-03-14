# Codex ハーネス/ルール実装計画

## 0. 依頼概要
- 依頼内容:
  - Codex で危険なコマンドを実行しないようにするための「ハーネス（実行制御）」および「ルール（方針・判定）」の設定方法を調査し、実装計画として整理する。
- 背景:
  - 既存レポート `docs/reports/2026-02-26_ai-agent-dangerous-commands.md` で危険コマンドの分類を整理済み。
  - 次段階として、Codex 実行環境に具体的な抑止策（設定・ポリシー・検証手順）を導入したい。
- 期待成果:
  - Codex CLI / リポジトリ運用に適用できる多層防御（AGENTS.md / Rules / config / sandbox / approval / wrapper）の実装計画
  - バージョン依存の確認ポイントと検証手順
  - 実装時に編集するファイル候補と段階的導入順

## 1. ゴール / 完了条件
- ゴール:
  - Codex の危険コマンド抑止を、`ルール（指示）` と `ハーネス（技術的強制）` の両面で導入できる状態にするための、具体的かつ実行可能な計画を定義する。
- 完了条件（DoD）:
  - Codex で使える制御手段（`AGENTS.md`、`--sandbox`、`--ask-for-approval`、`config.toml` profile、`Rules (.rules)`、`requirements.toml`）が整理されている。
  - このリポジトリでの実装ステップ（ファイル単位、順序、検証方法）が定義されている。
  - wrapper の引数ガバナンス（許可/拒否/固定注入。特に `-c/--config` 等の回避経路対策）が定義されている。
  - `.rules` の実行時適用確認手順、または未適用時の代替強制手段（fail-closed の fallback）が定義されている。
  - `requirements.toml` の適用可否判定と、未採用時の分岐方針が定義されている。
  - ロールアウト時のリスク（バージョン差、誤検知、迂回）と対策が含まれている。

## 2. スコープ
- In Scope:
  - Codex CLI（ローカル利用）における安全設定の導入計画
  - リポジトリ内で管理できるルール（`AGENTS.md`、`.codex/rules/`、`docs/agent/overrides.md` など）
  - ローカル/チーム配布向けのハーネス（例: `scripts/codex-safe.ps1`）導入計画
  - wrapper 回避経路（`-c/--config`, `--profile`, `--add-dir`, `-C`, `--dangerously-bypass-approvals-and-sandbox` など）の対策設計
  - `config.toml` / profile / `requirements.toml` を用いた安全デフォルト設計方針
  - 検証（`codex execpolicy check` を含む）計画
- Out of Scope:
  - 今回のターンでの実装・コード投入そのもの
  - 組織全体の端末管理（EDR, MDM, OSファイアウォール）設計
  - Codex 以外のエージェント製品全般の比較

## 3. 実行タスク
- [ ] 1. 現在利用中の Codex CLI バージョンと利用可能機能（`execpolicy` / `sandbox` / approval / config profile / managed policy）を固定化し、実装前提を明記する
- [ ] 2. `.rules` の実行時適用方式（自動読込/明示指定）を確認し、未適用時の fallback（wrapper 事前判定など）を含む強制経路を決める
- [ ] 3. `requirements.toml` の適用可否・配置場所（repo内/ユーザー設定/管理ポリシー）を確認し、採用/非採用の分岐条件を定義する
- [ ] 4. 制御レイヤーごとの役割分担を設計する（`AGENTS.md` / `.rules` / `requirements.toml` / `config profile` / wrapper）
- [ ] 5. リポジトリ変更案を作成する（追加・更新ファイル一覧、各ファイルの責務、命名規則、配置場所）
- [ ] 6. `execpolicy` ルールセット（禁止・要承認・許可）の初版仕様を定義する（危険コマンド、危険フラグ、prefix_rule 含む）
- [ ] 7. `codex-safe` wrapper（PowerShell想定）の仕様を定義する（引数許可リスト/拒否リスト、固定注入、危険フラグ拒否、ログ出力。profile注入は環境依存のため任意）
- [ ] 8. 検証計画を定義する（正常系/拒否系/承認系、`.rules` 実行時適用確認、PowerShell回避ケース、`codex execpolicy check` 手順）
- [ ] 9. 段階導入計画（PoC → チーム適用 → 強制化）とロールバック手順を定義する

## 4. マイルストーン
- M1: 調査と要件整理完了
  - Codex CLI の機能確認、公式 docs の制御手段整理、制約（バージョン差・環境差）の明記
  - `.rules` 実行時適用方式と `requirements.toml` 適用可否の確認完了
- M2: 実装仕様（ルール + ハーネス）確定
  - `.rules` / `requirements.toml` / wrapper / AGENTS 追記内容の仕様とテストケース確定
  - wrapper の引数ガバナンス（`-c/--config` 等）と fallback 経路確定
- M3: 導入準備完了
  - 実装タスク分割、検証手順、ロールアウト方針、運用ルール（承認フロー）確定

## 5. リスクと対策
- リスク:
  - Codex CLI のバージョン差により docs 記載機能が未搭載/挙動差異を持つ可能性
  - `.rules` の判定が厳しすぎて通常開発作業を阻害する可能性（誤検知）
  - ユーザーが wrapper を使わず直接 `codex` を実行して迂回する可能性
  - wrapper 経由でも `-c/--config` などの上書き引数で安全設定が回避される可能性
  - `AGENTS.md` のみでは技術的強制にならないため、遵守依存になる可能性
  - Windows/PowerShell のトークン分解と想定ルールがズレる可能性
  - `.rules` が実行時に読まれない/想定と違う優先順位で適用される可能性
  - `requirements.toml` の配置/適用条件が環境依存で、期待どおりに強制できない可能性
  - 対策:
    - 導入前に `codex --version` と `codex execpolicy --help` を必ず記録し、バージョン依存機能を明示する
    - ルールは `forbidden` / `prompt` / `allow` の3段階で開始し、いきなり全面禁止にしない
    - wrapper をチーム標準起動方法にし、`AGENTS.md` / docs / alias で導線を一本化する
    - wrapper は引数許可リスト方式を採用し、`-c/--config`・`--add-dir`・`--dangerously-bypass-approvals-and-sandbox` 等を既定で拒否する
    - 重要操作は `sandbox + approval + rules` の多層で防ぐ（単独層に依存しない）
    - `.rules` の実行時適用を PoC で確認し、未適用なら wrapper で `codex execpolicy check` を事前実行する fallback を採用する
    - `requirements.toml` は「採用可否判定タスク」を先に実施し、未採用時は wrapper + profile + rules で fail-closed を維持する
    - `codex execpolicy check` に加えて、PowerShell 実コマンド例・引用/エスケープ・連結記号でスモークテストを行う

## 6. 検証方法
- 実施する確認:
  - `codex execpolicy check -r <rulefile> ...` によるルール判定テスト（危険コマンド/安全コマンドの両方）
  - `.rules` が実運用の Codex 起動経路で読み込まれること（実行時適用）を確認するテスト
  - `.rules` の実行時適用が不安定/未対応の場合、wrapper fallback（事前 `execpolicy check`）で fail-closed になること
  - wrapper 経由起動時に `--sandbox` / `--ask-for-approval` が強制されること（`--profile` は環境依存のため任意）
  - wrapper がユーザー指定の `-c/--config`, `--profile`（未許可値）, `--add-dir`, `-C`, `--dangerously-bypass-approvals-and-sandbox` を拒否または無効化すること
  - wrapper が `--dangerously-bypass-approvals-and-sandbox` を拒否すること
  - 承認が必要なコマンド群が `prompt` 扱いになること（例: 削除・delete系・force系）
  - 読み取り中心コマンド（例: `rg`, `git status`, `git diff`）が許可されること
  - `requirements.toml` を採用する場合、想定どおり最低限ポリシーが強制されること（採用しない場合は分岐仕様どおり代替強制が機能すること）
  - PowerShell 回避ケース（空白パス、引用符、`;`, `|`, `&&`, `` ` `` エスケープ、`--%`, 環境変数展開、ワイルドカード）で wrapper 判定が崩れないこと
- 成功判定:
  - 事前定義した危険コマンドテストケースがすべて、少なくとも1つの強制層（rules / wrapper / approval）で `forbidden` または `prompt` 相当に制御される
  - 想定する日常作業コマンドが過度にブロックされない（PoCで許容範囲の誤検知率）
  - Codex 起動方法がチーム内で再現可能（README/運用手順どおりに実行できる）

## 7. 成果物
- 変更ファイル:
  - `AGENTS.md`（安全起動ポリシー、wrapper 利用必須化の追記）
  - `docs/agent/overrides.md`（存在する場合。危険コマンド方針の上書き/補足）
  - `.codex/rules/*.rules`（execpolicy ルール定義）
  - `.codex/requirements.toml` または所定の管理ポリシー配置先（採用時。配置場所は事前確認で確定）
  - `scripts/codex-safe.ps1`（Codex 安全起動 wrapper）
  - （任意）`scripts/tests/` または `docs/reports/` 配下の policy/wrapper 検証ケース
  - `docs/PROJECT_CONTEXT.md`（運用方法/ファイル配置の追記）
- 付随ドキュメント:
  - `docs/plans/2026-02-26_codex-harness-rules-implementation-plan.md`（本計画書）
  - `docs/reports/2026-02-26_ai-agent-dangerous-commands.md`（前提となる危険コマンド分類）
  - （任意）`docs/reports/` 配下の検証結果レポート

## 8. 備考
- 調査メモ（ローカル CLI で確認した項目）
  - `codex --help` で `--sandbox`, `--ask-for-approval`, `--config`, `--profile`, `--dangerously-bypass-approvals-and-sandbox` を確認
  - `codex sandbox --help` で OS別 sandbox 実行（Windows 含む）を確認
  - `codex execpolicy --help` / `codex execpolicy check --help` で `.rules` 検証機能を確認
  - `codex --version` は `codex-cli 0.104.0-alpha.1`（調査時点）
- 公式 docs で確認した主要情報（調査時点）
  - Codex docs 目次（CLI / Config / Rules / AGENTS / Security）: `https://developers.openai.com/codex/`
  - `AGENTS.md` の適用範囲と優先順位: `https://developers.openai.com/codex/agents-md`
  - Rules（`.rules`, `forbidden/prompt/allow`, `prefix_rule`, `codex execpolicy check`）: `https://developers.openai.com/codex/rules`
  - Config（`sandbox_mode`, `approval_policy`, `requirements.toml`, `managed_policy`）: `https://developers.openai.com/codex/config-reference`
  - Config profiles / priority: `https://developers.openai.com/codex/config`
  - Security（sandbox/approval 組み合わせ推奨）: `https://developers.openai.com/codex/security`
- 実装時の推奨方針（初期値）
  - 既定は `sandbox=workspace-write` 以上を前提にし、`danger-full-access` は wrapper で明示許可制にする
  - approval は `untrusted` または `on-request` を用途別 profile で分ける
  - 破壊系コマンドは `.rules` で `forbidden`、グレーゾーンは `prompt` に振り分ける
  - wrapper は引数許可リスト方式を採用し、ユーザー入力の `-c/--config` を原則拒否。必要な設定は wrapper 内で固定注入する
  - `.rules` の実行時適用が不確実な間は、wrapper に `codex execpolicy check` の事前判定を組み込み、未判定時は実行しない（fail-closed）
  - `requirements.toml` は最初から必須前提にせず、適用可否確認後に採用判断する（使えない場合は代替強制で進める）
