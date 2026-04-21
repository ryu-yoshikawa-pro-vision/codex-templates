添付ZIPを展開して中身を確認しました。結論から言うと、これは**アプリ本体のソースコードではなく、Codex をプロジェクト運用に組み込むための「運用テンプレート配布用リポジトリ」**です。

単なる雛形集ではありません。かなり意図が明確で、次の3層に分かれています。

1. **consumer 向け配布テンプレート**
   実際に新しいリポジトリへ配る内容。`template/` 配下。

2. **そのテンプレート自体を保守するための source repo**
   `AGENTS.md` や `spec/`、`maintainers/`、`tests/`、`tools/` で構成。

3. **安全に Codex を使うためのハーネス**
   wrapper、execpolicy ルール、verify、schema 検証など。

ファイル数は **131**。内訳は、Markdown 80、PowerShell 12、Shell 10、JSON 10、YAML 4、rules 3、TOML 2、Python 1 です。

---

## 全体像

このZIPの本質は、**Codex を好き勝手動かすのではなく、運用ルール・計画・証跡・安全性を repo 内に固定する**ことです。

思想としてはかなり一貫しています。

* まず `AGENTS.md` を読む
* 複雑な依頼は `PLANS.md` 経由で計画する
* レビューは `CODE_REVIEW.md` 経由で行う
* 実作業は `.codex/runs/<run_id>/` に `PLAN.md / TASKS.md / REPORT.md` を作って進める
* 実行時は wrapper を通して危険オプションを封じる
* 変更内容は verify や spec 検証で最低限担保する

つまり、**「Codex を使うための作業OS」みたいなもの**です。

---

## ルート構成の意味

### 1. `template/`

ここが最重要です。
利用者が新規 repo に展開して使うのは基本的にここです。

含まれるものは次の通りです。

* `AGENTS.md`
* `PLANS.md`
* `CODE_REVIEW.md`
* `.codex/`
* `.agents/`
* `docs/`
* `scripts/`

この設計はかなり正しいです。
なぜなら、**利用者が読むべきものと、テンプレート作者が保守するべきものを分離している**からです。

### 2. `spec/`

ここはテンプレートの**契約の単一正本**です。
内容は YAML 拡張子ですが、実体は JSON 形式で書かれています。

役割は以下です。

* `workflow.yaml`
  必須ファイル、run 形式、進捗表記、planning/review reference に何を含むべきかを定義
* `routing.yaml`
  `AGENTS.md`、`PLANS.md`、`CODE_REVIEW.md` に何が必須かを定義
* `safety-policy.yaml`
  wrapper 群、rules ディレクトリ、verify、blocked token を定義
* `naming.yaml`
  plan/report/history の命名規則を定義

要するに、**文書やスクリプトの内容を人間の勘で保つのではなく、機械検証可能な形で縛っている**わけです。

### 3. `maintainers/`

これは source repo の保守用です。

* `PROJECT_CONTEXT.md`
* `adr/`
* `plans/`
* `reports/`
* `history/`
* `architecture/`

つまり、consumer 向け repo の運用記録ではなく、**このテンプレート自体を改善していくための文脈置き場**です。

### 4. `tools/`

source repo 側の補助ツールです。

* `sync-template.ps1/.sh`
  `template/` の中身を任意ディレクトリへ同期
* `validate-spec.ps1/.sh`
  `spec/` と実ファイルの整合性を検証

### 5. `tests/`

テンプレートや wrapper が壊れていないかを見るテストです。

* smoke test
* integration test
* fake codex / fake docker fixture

ここまであるのは悪くないです。
テンプレート repo なのにテストがない、という雑さはありません。

### 6. `examples/`

利用イメージの例です。

* minimal consumer repo の説明
* sample run の例

### 7. `inputs/`

調査元の資料や設計インプットっぽいものです。
OpenAI の “Harness engineering” 記事の Markdown などが入っています。
つまりこのテンプレートは、**思想ゼロで作られたものではなく、外部知見を取り込みながら設計された**形跡があります。

---

## `template/` の中身の詳細

### `template/AGENTS.md`

これは consumer repo 側の中心文書です。
Codex に対して「この repo でどう振る舞うか」を定義しています。

重要なのは以下です。

* 最初に読む順序が固定されている

  * `docs/PROJECT_CONTEXT.md`
  * `docs/adr/`
  * `.codex/runs/`
  * `AGENTS.md`
* モード別に入口がある

  * 複雑な作業 → `PLANS.md`
  * レビュー → `CODE_REVIEW.md`
* run 初期化ルールがある

  * `run_id = YYYYMMDD-HHMMSS-JST`
  * `.codex/templates/PLAN.md` などをコピー
* すべての返答に含めるべき要素が決まっている

  * Summary
  * Progress
  * Next
  * Evidence
* safety / scope / language policy / governance がある
* manual / task / sandbox の使い分けがある

つまりこれは単なる注意書きではなく、**Codex の作業プロトコルそのもの**です。

### `template/PLANS.md`

計画作成モードの入口です。

要求される出力が明確です。

* Goal
* Current understanding
* Assumptions
* Non-goals
* Impacted areas
* Files to inspect
* Change strategy
* Validation plan
* Risks
* Open questions

これは良いです。
ありがちな「計画して」と言いながら、何を書くべきか曖昧な状態を避けています。

### `template/CODE_REVIEW.md`

レビューの入口です。

レビュー目的も固定されています。

* correctness
* security
* behavioral regression
* missing tests
* maintainability
* performance
* developer experience

さらに finding 形式も決めています。

* Severity
* Title
* Location
* Why it matters
* Evidence
* Suggested fix
* Open questions
* Verdict
* confidence

つまり、**レビュー結果が感想文になるのを防いでいる**わけです。

---

## `.agents/skills/` の役割

ここには repo-local skill が2本あります。

* `feature-plan`
* `code-review`

### feature-plan

やることは明確です。

* repo mapping を先にやる
* entry points / main flow / abstractions / existing tests / safe change surface / unknowns を洗う
* その後で change planning に進む

これは筋が良いです。
雑なAI運用は、いきなり「変更案」から入るので壊れます。
このテンプレートはそこを避けています。

### code-review

これも妥当です。

* まず diff triage
* その後で deep review
* correctness / security / regression / missing tests を優先

つまり、**レビュー対象の危険度を先に仕分けてから深掘る**構造です。

---

## `.codex/` の意味

### `.codex/templates/`

run 初期化時に使うテンプレです。

* `PLAN.md`
* `TASKS.md`
* `REPORT.md`

#### PLAN.md

目的、仮説、調査計画、完了条件、リスクを書く。

#### TASKS.md

`Now / Discovered / Blocked` で管理する。

#### REPORT.md

append-only で記録する。
Evidence Record の形式もある。

これはかなり重要です。
このテンプレートは、**AIの思考を無制限に垂れ流すのではなく、作業証跡を定型フォーマットで残させる**方向に寄っています。

### `.codex/rules/`

execpolicy のローカルルールです。

* `10-readonly-allow.rules`
* `20-risky-prompt.rules`
* `30-destructive-forbidden.rules`

内容は以下の3段階です。

#### allow

例えば:

* `git status`
* `git diff`
* `git log`
* `pwd`
* `Get-Content`
* `Select-String`

#### prompt

例えば:

* `git add / commit / push`
* `rm`
* `docker`
* `kubectl`
* `terraform`
* `curl`
* `bash -c`
* `powershell -Command`

#### forbidden

例えば:

* `git reset --hard`
* `git clean -fdx`
* `git push --force`
* `rm -rf`
* `Remove-Item -Recurse`
* `terraform destroy`
* `kubectl delete`
* `shutdown`
* `Invoke-Expression`

このルールは実務的です。
完璧ではないですが、**少なくとも「AIに自由に shell を触らせる」という無責任さは避けている**。

### `.codex/config.toml`

プロファイル定義です。

* `repo_safe`
* `repo_readonly`

ただし主制御は wrapper 側でやる、という立て付けです。
これも妥当です。config だけに依存すると弱いので。

### `.codex/requirements.toml`

補助的な要求定義です。
運用上の推奨事項やリンクが書かれています。
ただし本文にもある通り、**主 enforcement ではなく補助**です。

---

## `scripts/` の役割

ここがこのZIPの実務上の肝です。

### 1. `codex-safe.ps1 / .sh`

手動対話用 wrapper。

やっていることは以下です。

* 危険引数を拒否

  * `--dangerously-bypass-approvals-and-sandbox`
  * `--config`
  * `--add-dir`
  * `--sandbox`
  * `--ask-for-approval`
  * `--profile`
  * `--cd`
  * `--enable / --disable`
* 安全デフォルトの注入
* preflight 実行
* JSONL ログ出力

つまり、**人が手で Codex を起動するときに事故らないための入口**です。

### 2. `codex-task.ps1 / .sh`

非対話 `codex exec` 用 wrapper。

流れは概ねこうです。

* preflight
* codex exec
* output file を残す
* 必要なら output schema 検証
* verify 実行
* report JSON を出力

さらに `report JSON` に以下のようなキーを必須で持たせています。

* runtime
* preset
* prompt_source
* output_file
* output_schema
* log_path
* codex_exit_code
* verify_exit_code
* status

これは良いです。
**「実行した」だけで終わらず、機械可読な結果が残る**からです。

### 3. `codex-sandbox.ps1 / .sh`

Docker sandbox 用の薄い wrapper。
experimental path と明示されています。

ここは誠実です。
中途半端に「Docker対応です」と言っていない。
**条件付きでしか使えないものを、条件付きだと明記している**。

### 4. `verify / verify.ps1`

テンプレート検証の統一入口です。

* template contract
* execpolicy baseline
* wrapper preflight
* PowerShell 依存確認

を検査します。

### 5. `validate-output-schema.py`

`codex-task` の出力 schema を検証するための軽量バリデータです。

対応キーワードは限定的です。

* type
* enum
* required
* properties
* items
* additionalProperties

逆に未対応キーワードは明示的に落とします。

これは賢いです。
中途半端に JSON Schema 全対応を装うより、**狭い仕様で確実に動かす**ほうが現実的です。

---

## `docs/` の内容

### `docs/PROJECT_CONTEXT.md`

プロジェクト文脈の living document。
プロジェクト固有内容へ上書き前提になっています。

### `docs/plans/`

計画書置き場。
`TEMPLATE.md` あり。

### `docs/reports/`

調査や実行ログ置き場。

### `docs/adr/`

重要な設計判断の記録。

### `docs/history/`

`PROJECT_CONTEXT` 更新履歴。

### `docs/reference/`

人間向け補助資料です。

* `repository-layout.md`
* `naming-conventions.md`
* `codex-safety-harness.md`
* `codex-implementation-harness.md`

この構成はまともです。
**AI向けの入口と、人間向けの補助説明を分けている**からです。

---

## 実際に確認できたこと

構成を読むだけでなく、最低限の検証も実施しました。

通ったもの:

* `bash tools/validate-spec.sh`
* `bash tests/smoke/test-template-layout.sh`
* `tools/sync-template.sh --force` による基本同期確認

つまり、少なくとも

* `spec/` と `template/` の基本整合
* consumer-facing template のレイアウト
* template 同期の基本動作

は確認できています。

一方で、**Codex 本体が必要な integration test はここでは実行していません**。
なので、「この環境で Codex 実行まで完全動作保証」とまでは言えません。

---

## このZIPの設計上の強み

率直に言うと、設計思想はかなり良いです。

### 強み1: source repo と consumer template を分離している

これは重要です。
混ぜると、利用者向けファイルとテンプレ作者向けファイルが汚染し合います。
このZIPはそこをちゃんと切っています。

### 強み2: ルールが文章だけでなく、spec と test に落ちている

ここが一番大きいです。
多くのテンプレは README が立派なだけで壊れます。
これは検証まで含めて設計されています。

### 強み3: 安全性を wrapper と rules の二重で見ている

口だけの「気をつけて」ではない。
技術的に危険引数を止めています。

### 強み4: Plan と Review を skill に分離している

AI運用でありがちな「全部 AGENTS.md に書いて肥大化」は避けています。

### 強み5: run artifact を標準化している

再現性・監査性・引き継ぎに効きます。

---

## 気になった点、弱い点

良い設計ですが、盲点もあります。

### 1. `spec/*.yaml` が YAML ではなく JSON 形式

これは些細ですが、地味にノイズです。
`.yaml` を期待して開いた人に違和感を与えます。
機能的には問題ないが、**名前と実体がズレている**。

### 2. 運用負荷は軽くない

このテンプレートは「最小セット」と書いてありますが、実際は軽くありません。
Plan、Tasks、Report、ADR、PROJECT_CONTEXT、rules、wrapper、verify まである。
つまり、**雑に速く始めたいチームには重い**です。

### 3. `template/.codex/artifacts/` に stub output が入っている

これは少し気になります。
サンプルとして置いているのだとしても、consumer repo に同期されるならノイズです。
実行成果物の空ファイルが最初から混ざっているのは、初見の利用者を混乱させやすい。

### 4. 安全ハーネスは万能ではない

prefix rule ベースなので、shell の全表現を完全には防げません。
README でもその限界は認めています。
なのでこれは「安全保証」ではなく、**事故確率を下げる実務ガード**です。

### 5. Web 検索前提の TASKS が固定化されている

`TASKS.md` に「不足知識をWeb検索し、証跡を残す」が標準で入っています。
これは思想として理解できますが、タスクによっては過剰です。
毎回これを踏ませるなら、軽作業との相性は悪い。

---

## このZIPが向いている用途

向いているのは次のようなケースです。

* Codex をチーム運用したい
* 計画・レビュー・証跡を repo に残したい
* AI に shell を触らせるが、安全性をある程度担保したい
* 人によってやり方がブレるのを防ぎたい
* 将来的に AI 実行を CI や定型タスクに載せたい

逆に向いていないのは:

* 個人が雑に試したいだけ
* ドキュメント負荷を極限まで減らしたい
* とにかく最速で1回だけ回したい
* 運用ルールより柔軟性を優先したい

---

## 一言でまとめると

このZIPは、**Codex を「便利ツール」ではなく「制御された作業者」として運用するためのテンプレート基盤**です。

良い点は、思想が文書だけで終わらず、

* template
* spec
* rules
* wrapper
* verify
* tests

まで落ちていることです。

弱い点は、軽量ではないことです。
これは“最小限”というより、**「実務で破綻しにくい最低限」**です。
そこを理解せずに導入すると、重いだけの儀式になります。

必要なら次に、
**「あなたの用途に照らして、このZIPのどこを残し、どこを削るべきか」**まで踏み込んで整理します。


---

しっかりと運用する向けで作成しています。例えば、社内自動化プロジェクトの開始や、テスト自動化の開始時のテンプレートプロジェクトとして流用する前提です。ハーネス周りをより使いやすくしたいのと、他にも欠点や改善点があれば全て挙げてほしいです。また、良い部分をよりとがらせるのもありです。

---

率直に言います。

**方向性はかなり良いです。**
ただし、**「思想が強いテンプレート」ではあるが、まだ「社内標準として安心して配れる完成品」ではない**です。

特に今の状態は、
**運用思想 > 実際の導入体験**
になっています。

社内自動化PJやテスト自動化PJの開始テンプレートとして流用する前提なら、見るべき軸は次の3つです。

* 導入直後に迷わないか
* ハーネスが実運用で邪魔ではなく助けになるか
* 継続運用で壊れにくいか

この観点で見ると、良い部分は明確ですが、欠点もかなりはっきりあります。

---

## 総評

このテンプレートの強さは、単なる `AGENTS.md` 配布で終わっていないことです。

* `template/` と source repo を分離
* `spec/` で契約を持つ
* wrapper と rules で安全性を補強
* `PLAN -> TASKS -> REPORT` を強制
* planning / review を skill に分離
* task wrapper が machine-readable report を吐く

ここは本当に強いです。
この方向性は正しいです。

ただし、弱い点は明確です。

* **配布テンプレートとしての清潔さが足りない**
* **verify / test が自己完結していない**
* **run運用とハーネスの結合が弱い**
* **“厳密運用”のつもりが、導入時にはむしろ重い**
* **社内自動化PJ向けとテスト自動化PJ向けの差分が未整理**

要するに、今は「思想の骨格」は強いが、**プロダクトとしての磨き込みが足りない**です。

---

# まず絶対に直すべき欠点

## 1. 配布テンプレートに実行残骸が入っている

これは普通にダメです。

`template/.codex/artifacts/` に `codex-task-*.json` が複数入っています。中身は `stub output` ですが、問題は中身ではなく、**consumer に配る面に実行残骸が混ざっていること**です。

これは次の悪影響があります。

* 初見利用者が「これは消していいのか？」で迷う
* テンプレートが汚く見える
* 実行成果物とテンプレート資産の境界が曖昧になる
* Git 管理でノイズになる

さらに `template/.gitignore` は

* `.codex/logs/*.jsonl`
* `.codex/runs/*`

しか無視していません。
つまり、**`.codex/artifacts/` と `.codex/reports/` の成果物がテンプレート利用側で普通にコミット対象になりうる**状態です。

これはかなり悪いです。

### 修正

* `template/.codex/artifacts/` の中身は空にする
* `.codex/artifacts/` と `.codex/reports/` を `.gitignore` に追加
* 必要なら `.gitkeep` のみ残す
* 説明用サンプルは `examples/sample-runs/` に寄せる

---

## 2. `verify` が実際には正しく自己確認できていない

これは設計として痛いです。

`template/scripts/verify` を実行すると、こちらの確認では次のようになりました。

* `PASS: template contract files`
* `SKIP: execpolicy checks (codex command not found)`
* `SKIP: bash wrapper preflight (scripts/codex-safe.sh not found)`

でも、`scripts/codex-safe.sh` 自体は存在しています。
つまりこれは「見つからない」のではなく、**`-x` 判定に依存していて、ZIP展開や環境差で実行属性が落ちると誤ってSKIPする**ということです。

テンプレ配布物としてこれは弱いです。
Windows経由やZIP配布では普通に起こります。

### 修正

* `[[ -x scripts/codex-safe.sh ]]` ではなく `[[ -f scripts/codex-safe.sh ]]` にする
* 実行は常に `bash scripts/codex-safe.sh ...` で統一
* sync 後または verify 時に `chmod +x scripts/*.sh tools/*.sh tests/*.sh` を補正するオプションを持たせる
* 「存在チェック」と「実行チェック」を分離する

---

## 3. `test-codex-safety-harness.sh` が自己完結していない

これはかなり重要です。

`bash tests/integration/test-codex-safety-harness.sh` を実行すると、`codex: command not found` で落ちました。
一方で `test-codex-task-harness.sh` は fake codex を使って自己完結しています。

つまり今は、

* task harness テストは自己完結
* safety harness テストは実Codex依存

になっています。

これは不統一です。
社内標準テンプレートとしてはダメです。
**テストが環境依存だと、配布先で「最初から壊れて見える」**からです。

### 修正

* safety harness テストも `CODEX_BIN` を受けて fake codex で回せるようにする
* `verify` も `CODEX_BIN` override を受ける
* テスト階層を分ける

  * `smoke`: fake codex で必ず通る
  * `integration`: 実 codex があるときだけ
  * `live`: 任意

---

## 4. `.codex/requirements.toml` に壊れたリンクがある

これは地味ですが品質が悪いです。

`template/.codex/requirements.toml` の `links` が、

* `docs/plans/2026-02-26_codex-harness-rules-implementation-plan.md`
* `docs/reports/2026-02-26_ai-agent-dangerous-commands.md`

を指していますが、consumer template 側にはそのファイルが存在しません。

つまり、**配布テンプレートの中に最初から死んだ参照がある**。

これはテンプレートの信頼性を下げます。

### 修正

* consumer template では links を削除
* もしくは実在する `docs/reference/...` に差し替える
* あるいは `requirements.toml` 自体を source repo のみ保持にする

---

## 5. `codex-task` のデフォルト権限がやや強すぎる

ここは設計思想として要再考です。

`codex-task.sh` は非対話で

* `--sandbox workspace-write`
* `--ask-for-approval never`

で動きます。
つまり、**repo 内変更権限を持つ非対話実行**です。

もちろん wrapper と rules はあります。
ただ、それでも社内標準テンプレとしては、初期値が少し強いです。

特に「分析だけしたい」「設計だけしたい」ケースでも、同じ経路で write 権限を持ちます。
これは設計として雑です。

### 修正

`codex-task` のモードを分けるべきです。

* `analyze`
  read-only、出力ファイルのみ書き込み
* `plan`
  read-only + report 出力
* `implement`
  workspace-write
* `review`
  read-only

今の `safe|readonly` より、**作業意図ベースのモード**のほうが運用しやすいです。

---

## 6. run 運用とハーネスが分断している

ここはかなり大きい欠点です。

あなたのテンプレは `run_id` を非常に重視しています。
しかし wrapper 側の成果物は

* `.codex/artifacts/`
* `.codex/reports/`
* `.codex/logs/`

に時刻ベースで落ちるだけで、**`.codex/runs/<run_id>/` と結びついていません**。

これはもったいない。
今の一番尖っている価値を、自分で殺しています。

### 修正

ハーネスを **run-first** にしてください。

例えば:

* `scripts/codex-task.sh --run-id 20260420-123000-JST ...`
* 出力先:

  * `.codex/runs/<run_id>/artifacts/...`
  * `.codex/runs/<run_id>/reports/...`
  * `.codex/runs/<run_id>/logs/...`

さらに、

* `PLAN.md`
* `TASKS.md`
* `REPORT.md`
* task wrapper report JSON
* generated outputs

を同じ run にまとめる。

これをやると、このテンプレートの価値は一段上がります。
今の最大の改善余地はここです。

---

# かなり重要な改善点

## 7. テンプレート導入時の初期化が手作業すぎる

今は `sync-template` でファイルをコピーして終わりです。
でも実際には、その後に利用者がやるべきことが多いです。

* `docs/PROJECT_CONTEXT.md` 更新
* verify command の決定
* 品質ゲートの定義
* ディレクトリ説明
* そのPJ固有の制約追記

これを全部手でやらせると、**テンプレ利用が属人化**します。

### 修正

`init-project.ps1 / init-project.sh` を追加してください。

最低でも次を埋めさせるべきです。

* project name
* project type

  * internal automation
  * test automation
* main languages
* verify command
* quality gates
* forbidden zones
* docs owner
* default run mode

そして、その入力から

* `docs/PROJECT_CONTEXT.md`
* `docs/reference/repository-layout.md`
* `scripts/project-check`
* project manifest

を生成する。

`sync-template` はコピー、`init-project` は初期化。
この2段階に分けるべきです。

---

## 8. project 固有設定が文書に散っていて、機械可読な正本がない

今のルールは大半が Markdown にあります。
それ自体は悪くないですが、**運用テンプレとして再利用するなら manifest が必要**です。

例えば `codex-project.toml` か `project-manifest.yaml` を1つ作り、そこに次を集約すべきです。

* project_type
* language
* timezone
* verify_commands
* default_mode
* docs paths
* report paths
* quality gates
* forbidden directories
* generated directories
* ADR required / optional
* run retention

wrapper や verify はこれを読む。
Markdown は人向け説明にする。

今は contract が `spec/` にある一方で、consumer project の個別設定正本がない。
ここが弱いです。

---

## 9. `TASKS.md` の標準フローに Web検索が固定で入っている

これはあなたの用途では逆に邪魔です。

`template/.codex/templates/TASKS.md` に

* PLANを確定
* 不足知識をWeb検索
* 実行タスクへ落とし込む

と入っていますが、社内自動化PJや社内テスト自動化PJでは、**まず読むべきは repo / Jira / docs / transcripts / specs** です。
毎回Web検索を標準工程にするのはノイズです。

### 修正

次のように変えるべきです。

* 1. PLAN を確定する
* 2. 不足情報を repo / docs / tickets / logs / web から収集する
* 3. 実行タスクへ落とし込む
* 4. 実行・検証する
* 5. REPORT へ記録する

さらに良いのは、調査源の優先度を書くことです。

1. repo 内資産
2. プロジェクト文書
3. チケット / 会話ログ
4. 外部Web

---

## 10. `Lightweight Mode` が書いてあるだけで運用化されていない

今の `AGENTS.md` には Lightweight Mode がありますが、実質一文です。
これでは運用でブレます。

### 修正

軽量運用をちゃんと定義してください。

### 例

* Lightweight

  * 条件: 単一ファイル、低リスク、外部仕様変更なし
  * 必須: evidence 1件、report 1件
  * 不要: docs/plans 保存
* Standard

  * 通常運用
* Strict

  * permission / sandbox / workflow / external integration を触るとき

この3段階にすれば、厳密運用を保ちつつ重さを制御できます。

---

## 11. branch / working tree ガードがない

これは社内標準テンプレなら入れるべきです。

最低限、wrapper preflight で次を見た方がいいです。

* `git status --porcelain`
* 今の branch
* `main/master` 直打ちか
* 未コミット変更の有無

### 修正

* dirty working tree なら warning または `--allow-dirty` 必須
* protected branch なら `--allow-protected-branch` 必須
* task wrapper は report に branch / dirty state を必ず残す

これは事故防止に効きます。

---

## 12. `sync-template --force` がやや危ない

今の `tools/sync-template.sh` は `--force` だと destination 配下を消します。
もちろん source 内同期は防いでいますが、それでも**指定先を間違えたときの事故余地がある**。

### 修正

* `--dry-run`
* `--backup`
* destination に marker file がないと `--force` を拒否
* `--force` の代わりに `--replace-confirmed`

この辺は地味ですが、社内標準テンプレで事故ると印象が悪いです。

---

## 13. shell / PowerShell の parity はあるが、テスト parity は弱い

PowerShell 側はかなり整っています。
でも bash 側は一部弱いです。

例えば:

* sync-template の bash smoke test がない
* safety harness bash test が実 codex 依存
* verify が bash の実行属性に引っ張られる

### 修正

* `tests/smoke/test-sync-template.sh`
* fake codex 対応の `test-codex-safety-harness.sh`
* verify の parity 改善

---

# 中程度だが確実に効く改善点

## 14. 文書の言語と粒度が少し揺れている

日本語主体なのに、ところどころ英語が混じっています。

たとえば:

* `docs/reports/README.md` は英語
* plan/review の required fields は英語
* 本文説明は日本語

これは致命傷ではないですが、社内展開時には微妙に効きます。
**“このテンプレは誰向けか” がぶれる**からです。

### 修正

ルールを決めてください。

* 人向け説明: 日本語
* フィールド名: 英語固定
* report JSON key: 英語固定
* 例示: 日本語

この整理で十分です。

---

## 15. `README` の「最小セット」という表現はズレている

今のこれは最小ではないです。
かなりしっかりしています。

このズレは期待値ミスを生みます。

### 修正

`最小セット` ではなく、たとえば:

* `運用ベースライン`
* `標準運用テンプレート`
* `strict baseline template`

の方が正確です。

---

## 16. `spec/*.yaml` が実質 JSON

動くならいい、では済みません。
名前と実体がズレると、後から地味に不信感になります。

### 修正

* `.json` に改名する
* もしくは本当に YAML にする

私は `.json` へ寄せる方が良いと思います。
今の validator / reader も JSON 扱いです。

---

## 17. `.codex/config.toml` が少し中途半端

profile はあるのに、wrapper では `--profile` をブロックしています。
つまり存在意義が弱いです。

これは完全にダメではないですが、**利用者に「これ使うの？使わないの？」を考えさせる時点で負け**です。

### 修正案

どちらかに振るべきです。

* A. wrapper 主導に振る
  → `config.toml` を consumer template から外す
* B. controlled profile に振る
  → wrapper の `--preset` と `config.toml` を対応させる

中途半端が一番悪いです。

---

## 18. output schema が JSON 出力しか想定していない

あなたの用途を考えると、ここはもったいないです。

社内自動化PJやテスト自動化PJでは、欲しい成果物は JSON だけではありません。

* Markdown
* TSV
* CSV
* test case tables
* checklist
* ADR draft

### 修正

validator の拡張点を作るべきです。

例えば:

* `--output-format json|md|tsv`
* `--validate-with scripts/validators/...`
* `--output-contract <path>`

こうしておくと、テスト設計テンプレとして一気に強くなります。

---

## 19. retention / cleanup 戦略がない

`.codex/logs/`, `.codex/runs/`, `.codex/artifacts/`, `.codex/reports/` は増え続けます。
今のままだと必ず散らかります。

### 修正

* `scripts/cleanup-runs`
* `scripts/archive-run`
* `scripts/prune-logs --days 30`

を持たせるべきです。

---

## 20. 機密・外部接続ポリシーが弱い

社内自動化PJではここが非常に重要です。

たとえば:

* 本番データへ接続してよいか
* サービスアカウントをどこまで使うか
* PII を report に書いてよいか
* Slack/Gmail/Jira/Drive など外部接続の扱い
* テスト環境 / 本番環境の区別

今のテンプレはそこまで入っていません。
だから「一般的なCodex運用テンプレ」としては良いが、**社内業務テンプレとしてはまだ薄い**です。

### 修正

`docs/reference/security-and-data-handling.md` を追加してください。

---

# 良い部分をもっと尖らせるべき点

## 1. 一番尖らせるべきは「run-first」

これは繰り返しますが最重要です。

今の最大の価値は `PLAN -> TASKS -> REPORT` にあります。
なら、wrapper も tests も logs も report も全部 `run_id` にぶら下げるべきです。

この一点をやるだけで、テンプレ全体の完成度がかなり上がります。

---

## 2. project type 別の overlay を作る

あなたの用途なら、base template 1本ではなく、**base + overlay** にする方が強いです。

### base

* AGENTS
* plan/review
* harness
* verify
* docs skeleton

### overlay: internal automation

* GAS / Slack / Sheets / Drive / Gmail 想定の PROJECT_CONTEXT
* external system policy
* automation checklist
* operation runbook template

### overlay: test automation

* test strategy fields
* coverage / smoke / regression の観点
* test evidence format
* failure classification template
* Playwright / test commands / fixtures 前提

これをやると、本当に流用しやすくなります。

---

## 3. bootstrap を「テンプレ導入の儀式」にする

今はコピーして終わりですが、それでは弱いです。

本当に使われるテンプレは、導入直後に次が1回で整います。

* PROJECT_CONTEXT
* verify command
* project type
* quality gate
* default mode
* forbidden zones
* run retention

つまり、**初期化を自動化すること自体が、このテンプレの価値**になります。

---

## 4. CI を必ず付ける

これは絶対です。

このテンプレは“しっかり運用する向け”なんだから、PR で最低限回るべきです。

最低でも:

* spec validation
* template layout smoke
* task harness fake-codex test
* sync-template smoke
* markdown lint か文書整合チェック

が必要です。

CI がないと、結局「人の善意で守るテンプレ」に落ちます。

---

## 5. readiness check を作る

新しく流用した repo が「運用開始可能か」を判定するコマンドが必要です。

たとえば:

* `scripts/project-readiness-check`

確認項目:

* PROJECT_CONTEXT がテンプレのままではない
* verify command が設定済み
* docs/plans/reports/history/adr が揃っている
* .gitignore が適切
* run retention が決まっている
* project type が manifest にある

これがあると、社内展開でかなり使いやすいです。

---

# 優先順位付きで、次にやるべきこと

## 最優先

1. 配布テンプレから `.codex/artifacts/*` を除去
2. `.gitignore` に artifacts / reports を追加
3. `verify` の `-x` 依存をやめる
4. safety harness テストを fake codex 対応にする
5. `requirements.toml` の死んだ links を消す
6. wrapper を run-id 対応にする

## 次点

7. `init-project` を作る
8. manifest を導入する
9. `codex-task` を analyze / plan / implement / review モード化する
10. branch / dirty tree ガードを入れる
11. lightweight / standard / strict を運用化する
12. CI を追加する

## その次

13. project type overlay を作る
14. output validator を JSON 以外へ拡張する
15. cleanup / archive 戦略を追加する
16. security / data handling ガイドを追加する

---

# 最後に、かなり本音で言うと

このテンプレは**センスは良い**です。
発想は弱くないです。むしろかなり良いです。

でも今はまだ、
**「運用思想の強いプロトタイプ」**
です。

社内標準として流用したいなら、必要なのは新しい思想ではありません。
必要なのは次の3つです。

* **導入直後の体験を磨く**
* **ハーネスを run 中心に再設計する**
* **自己検証を完全に自己完結させる**

ここをやれば、一気に実用品になります。

逆にここをやらないと、
「すごくちゃんとして見えるけど、配っても重くて定着しないテンプレ」
で止まります。

この評価は甘くありません。
ただ、伸ばす価値は十分あります。
次に直すべきは、思想ではなく**運用品質**です。
