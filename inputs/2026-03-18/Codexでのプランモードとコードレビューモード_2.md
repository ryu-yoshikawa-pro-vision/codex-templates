では、**そのまま置ける最小構成**で出します。
方針は公式に沿っていて、**常時守らせるルールは `AGENTS.md`**、**繰り返し使う手順は Skill**、**長い計画ルールやレビュー基準は別Markdownに分離**です。Codex は `AGENTS.md` を事前に読み、Skill は task-specific な再利用ワークフローとして使う設計です。さらにレビュー系は「所見を優先し、重大度順・ファイル参照付きで出す」方向が公式ガイドと整合しています。 ([OpenAI Developers][1])

## 推奨構成

```text
repo-root/
├─ AGENTS.md
├─ docs/
│  ├─ PLANS.md
│  └─ code_review.md
└─ .codex/
   └─ skills/
      ├─ plan-repo-mapper/
      │  └─ SKILL.md
      ├─ plan-change-planner/
      │  └─ SKILL.md
      ├─ review-diff-triage/
      │  └─ SKILL.md
      └─ review-risk-reviewer/
         └─ SKILL.md
```

この分け方にしている理由は単純です。
`AGENTS.md` に全部詰め込むと重くなり、plan と review の目的まで混ざります。公式も、`AGENTS.md` は常時ルール、Skill は再利用可能な専門ワークフローとして切り分ける前提です。 ([OpenAI Developers][1])

---

## 1. `AGENTS.md`

```md
# AGENTS.md

## Purpose
このリポジトリでは、Codex を「実装者」ではなく「計画・実装・レビューを分担する開発エージェント」として扱う。
目的は、変更の正確性・再現性・レビュー容易性を高めること。

## Global operating rules
- まず既存実装・既存テスト・既存ユーティリティを調べ、重複実装を避ける。
- 推測で実装を始めない。不明点は、コード・設定・テスト・ドキュメントから証拠を集めてから判断する。
- 変更は最小差分を優先する。無関係な整形やリネームを混ぜない。
- 1回の変更で複数の責務を混ぜない。必要なら段階分割する。
- 追加・修正したコードに対して、影響範囲に応じた検証手段を明示する。
- 既存の命名規則、ディレクトリ規約、テスト流儀に従う。
- 仕様が曖昧な場合、勝手に補完して実装確定しない。まず計画に落として前提・非目標・未確定事項を明記する。

## When planning is mandatory
以下のいずれかに当てはまる場合、いきなり実装せず、先に計画を作る。
- 変更対象ファイルが複数にまたがる
- 既存 API / DB / state / 認可 / 画面遷移に影響する
- 要求が曖昧で、複数解釈がありうる
- バグ修正で、再現条件や根本原因がまだ特定できていない
- テスト追加方針が自明でない

計画を作る場合は `docs/PLANS.md` を参照し、その形式で出力する。

## When reviewing code
レビュー時は感想ではなく、差分が新たに持ち込んだ問題を優先して指摘する。
レビュー基準は `docs/code_review.md` を参照する。

## Implementation defaults
- 既存の抽象化で足りるなら、新しい抽象化を増やさない。
- 副作用は境界に寄せる。
- pure な計算と I/O を分ける。
- エラーハンドリングは握りつぶさない。
- ログ、例外、戻り値の契約を曖昧にしない。

## Output style
- 計画時は、結論より先に「前提」「影響範囲」「実施ステップ」「検証方法」を出す。
- レビュー時は、要約より先に findings を重大度順で出す。
- 長文説明より、判断根拠を短く明確に書く。
- ファイル名・関数名・テスト対象を具体的に書く。

## Definition of done
実装タスクでは、以下を満たして完了とする。
- 要求を満たす
- 既存規約と整合する
- 影響範囲に応じたテストまたは検証内容が示されている
- 未解決の前提・制約・既知リスクが明記されている
```

---

## 2. `docs/PLANS.md`

これは **plan モード時の出力形式を固定するための文書** です。
公式でも、複雑作業では計画文書を先に作る運用が推されており、Goal / Context / Constraints / Done のような構造化が有効です。 ([OpenAI Developers][2])

```md
# PLANS.md

この文書は、複雑な変更を着手前に計画化するためのテンプレートである。
計画の目的は、「何を変えるか」より先に、「何を壊しうるか」「何を確認してから着手すべきか」を固定すること。

---

## Plan template

### 1. Goal
この変更で最終的に達成したいことを1〜3文で書く。
実装手段ではなく、利用者またはシステム上の結果で書く。

### 2. Current understanding
現時点でコードベースから確認できた事実を書く。
推測は禁止。確認できたファイル、設定、既存実装、既存テストを書く。

### 3. Assumptions
まだ未確定だが、現時点で置いている前提を書く。
前提が崩れた場合に計画を見直す必要があるものだけを書く。

### 4. Non-goals
今回やらないことを書く。
将来やるかもしれない改善と、今回の対象を分離する。

### 5. Impacted areas
影響が及ぶ可能性のある領域を書く。
例:
- API / contract
- DB / schema / migration
- state / cache
- auth / permission
- UI / UX
- background jobs
- observability
- tests

### 6. Files to inspect
読むべきファイルを列挙し、理由を1行ずつ書く。

### 7. Change strategy
変更方針を段階化して書く。
各段階で以下を明記する。
- 何を変えるか
- なぜその順番か
- 失敗すると何が起きるか

### 8. Validation plan
変更後にどう確認するかを書く。
以下を必要に応じて含める。
- unit test
- integration test
- e2e test
- manual verification
- log / metrics confirmation
- rollback confirmation

### 9. Risks
今回の変更で起こりうる主要リスクを書く。
各リスクについて、検知方法と軽減策も書く。

### 10. Open questions
着手前または実装中に解決が必要な未確定事項を書く。

---

## Planning rules
- 既存コードを読む前に設計案を確定しない。
- 影響範囲が曖昧なまま「軽微変更」と判断しない。
- 変更対象ファイルだけでなく、呼び出し側・利用側・テスト側も確認する。
- 既存の似た実装を最低1件は探す。
- 仕様変更とリファクタリングを同時に進めない。
- テスト戦略が書けない変更は、計画不足とみなす。

---

## Required plan output format

以下の見出しを必ずこの順で出力すること。

1. Goal
2. Current understanding
3. Assumptions
4. Non-goals
5. Impacted areas
6. Files to inspect
7. Change strategy
8. Validation plan
9. Risks
10. Open questions
```

---

## 3. `docs/code_review.md`

レビュー側は、**「差分が持ち込んだ actionable な問題だけを挙げる」** ように固定した方が強いです。
これは公式のレビュー指針とかなり一致していて、correctness / performance / security / maintainability / DX を見つつ、所見優先・重大度順・場所特定で返すのが基本です。 ([OpenAI Developers][3])

```md
# code_review.md

この文書は、Codex にコードレビューをさせるときの基準である。
レビューの目的は、差分に対する感想を述べることではなく、
「この変更が新たに持ち込んだ問題」を優先順位付きで発見すること。

---

## Review objective
以下を優先して確認する。
1. Correctness
2. Security
3. Behavioral regression
4. Missing or insufficient tests
5. Maintainability
6. Performance
7. Developer experience

---

## What to report
報告するのは、以下の条件を満たすものに限る。
- 差分に起因する
- 再現または論理的説明が可能
- 修正可能な形で説明できる
- 重要度が低すぎない

以下は原則として報告しない。
- 単なる好み
- 既存コードに元からある問題で、この差分が増悪させていないもの
- ファイル全体の感想
- 「たぶん」レベルで根拠の弱い推測

---

## Severity levels
- P0: 本番障害、重大なセキュリティ欠陥、データ破壊、認可破綻
- P1: 高確率の不具合、主要フロー破壊、重大な回帰
- P2: 中程度の不具合、保守性悪化、見逃せないテスト不足
- P3: 軽微な改善提案。通常は報告優先度を下げる

---

## Required review format

### Findings
各 finding は以下の形式で出す。

- Severity: P0 | P1 | P2 | P3
- Title: 問題を一文で要約
- Location: `path/to/file.ext` + 関数名または行付近
- Why it matters: 何が壊れるか
- Evidence: 差分・呼び出し関係・条件分岐・型・テスト不足などの根拠
- Suggested fix: 修正の方向性を短く示す

### Open questions
確信度を下げる未確定事項があれば最後にまとめる。

### Verdict
最後に次のいずれかを出す。
- patch is correct
- patch is incorrect

さらに confidence を high / medium / low で明示する。

---

## Review heuristics
以下を重点確認する。

### Correctness
- 条件分岐の抜け
- null / undefined / empty の扱い漏れ
- 境界値の破綻
- 非同期処理の順序問題
- 例外時の契約不一致
- 変更前後で戻り値や副作用が変わっていないか

### Security
- 権限チェックの抜け
- 機密情報の露出
- 入力検証不足
- インジェクション、SSRF、XSS、CSRF に相当する経路
- 安全でないログ出力

### Regression
- 既存フローの前提を壊していないか
- 呼び出し元の期待契約が変わっていないか
- feature flag の ON/OFF 両方で成立するか
- キャッシュや state の整合性が保たれるか

### Tests
- 変更内容に対して必要なテストが足りているか
- 失敗系・境界値・権限差分が未検証ではないか
- 既存テストの意図が変更で崩れていないか

### Maintainability
- 責務混在
- 副作用の散乱
- 不自然な抽象化
- 将来の修正を難しくする分岐や暗黙ルール

---

## Review rules
- 要約より finding を先に出す。
- 重大度順に並べる。
- ファイルと場所を特定する。
- 提案は短く、修正案の方向だけ示す。
- 根拠が弱い場合は finding にしない。Open questions に回す。
```

---

## 4. `.codex/skills/plan-repo-mapper/SKILL.md`

Skill は **description が重要** です。
公式でも、Skill は task-specific capability で、必要時に読み込まれる形です。だから `description` で「いつ使うか」を明確にしないと発火が雑になります。 ([OpenAI Developers][4])

```md
---
name: plan-repo-mapper
description: Use this when the task requires understanding an unfamiliar code area before planning changes. Especially useful when multiple files, modules, routes, handlers, or tests may be involved and the safe change surface is not yet clear.
---

# plan-repo-mapper

## Goal
変更計画の前に、関連コード・実行経路・既存テスト・設定の地図を作る。

## Use this skill when
- どこを変えるべきかまだ曖昧
- 類似実装を探したい
- 影響範囲が複数ファイルにまたがる
- 初見のコード領域を読む必要がある

## Do not use this skill when
- 変更対象が1ファイルで明確
- 既に影響範囲が特定済み
- 単純な typo 修正のみ

## Workflow
1. 要求から主語となる概念を抽出する
   - 画面
   - API
   - hook / service / util
   - state
   - test
   - config

2. 既存実装を探索する
   - 名前一致
   - 類似責務
   - 呼び出し元
   - テスト
   - 設定ファイル

3. 関連ファイルを分類する
   - 直接変更候補
   - 読むだけでよい依存先
   - 挙動確認に必要なテスト
   - 影響確認対象

4. 最終的に以下を出力する
   - Entry points
   - Main flow
   - Key abstractions
   - Existing tests
   - Safe change surface
   - Unknowns

## Output format
### Entry points
### Main flow
### Key abstractions
### Existing tests
### Safe change surface
### Unknowns

## Rules
- 推測でアーキテクチャを断定しない。
- 類似実装を最低1件は探す。
- 「直接変更候補」と「影響確認対象」を分ける。
- 長い説明より、ファイル単位で短く整理する。
```

---

## 5. `.codex/skills/plan-change-planner/SKILL.md`

```md
---
name: plan-change-planner
description: Use this when the user wants a plan before implementation, or when the task is ambiguous, cross-cutting, risky, or likely to require staged execution and validation. Produces a concrete execution plan rather than code.
---

# plan-change-planner

## Goal
実装前に、変更内容を段階化し、前提・非目標・リスク・検証方法を固定する。

## Use this skill when
- ユーザーが plan を求めている
- 複数ファイルを触る見込みがある
- 不具合修正だが根本原因がまだ確定していない
- 権限、状態管理、API 契約、永続化に関わる
- テスト戦略を先に決めるべき

## Workflow
1. 要求を Goal に言い換える
2. コードベースから確認できた Current understanding を分ける
3. Assumptions を明示する
4. Non-goals を切る
5. Impacted areas を列挙する
6. Files to inspect を整理する
7. Change strategy を段階化する
8. Validation plan を定義する
9. Risks と Open questions を出す

## Output requirement
出力は必ず `docs/PLANS.md` の見出し順に合わせること。

## Rules
- 実装案を1つに早く閉じすぎない。
- 曖昧な要求を勝手に確定仕様にしない。
- テスト方針がない計画を完成扱いしない。
- 「ついでの改善」は Non-goals に逃がす。
- リファクタリングと仕様変更は分けて記述する。
```

---

## 6. `.codex/skills/review-diff-triage/SKILL.md`

```md
---
name: review-diff-triage
description: Use this when reviewing a patch, PR, or local diff to quickly classify the changed areas, identify risky change types, and determine where deep review is needed. Best for pre-review triage before giving final findings.
---

# review-diff-triage

## Goal
差分を分類し、深掘りすべき危険領域を特定する。

## Use this skill when
- PR / patch / local diff のレビューを始めるとき
- 変更量が多く、どこから見るべきか決めたいとき
- 最終レビュー前の初期仕分けをしたいとき

## Workflow
1. 差分を変更種類ごとに分類する
   - 仕様変更
   - バグ修正
   - リファクタリング
   - テスト変更
   - 設定変更
   - 依存更新
   - ドキュメント変更

2. リスク軸でマーキングする
   - 認可
   - 永続化
   - 非同期
   - 契約変更
   - 例外処理
   - キャッシュ / state
   - フラグ分岐

3. 深掘り対象を決める
   - correctness high risk
   - regression high risk
   - security high risk
   - test gap risk

## Output format
### Diff classification
### High-risk areas
### What needs deep review
### Potential missing tests
### Open questions

## Rules
- この段階では感想を書かない。
- 問題断定より、危険箇所の仕分けを優先する。
- 変更量ではなく、影響の大きさで優先度を決める。
```

---

## 7. `.codex/skills/review-risk-reviewer/SKILL.md`

```md
---
name: review-risk-reviewer
description: Use this when the task is to perform a real code review and produce actionable findings. Focus on correctness, security, regressions, and missing tests introduced by the diff. Findings should come before any summary.
---

# review-risk-reviewer

## Goal
差分が新たに持ち込んだ問題を、修正可能な形で指摘する。

## Use this skill when
- ユーザーがレビューを求めている
- PR / patch / commit diff に対して findings を出す必要がある
- 実装の危険性や回帰を評価したい

## Review standard
`docs/code_review.md` に従う。

## Workflow
1. 差分の主目的を把握する
2. 呼び出し元・利用側・テストを確認する
3. correctness を最優先で見る
4. security と regression を確認する
5. テスト不足を確認する
6. actionable な finding のみを残す
7. 最後に verdict と confidence を出す

## Output rules
- findings first
- severity order
- exact file reference
- concise evidence
- short fix direction
- weak confidence issues go to Open questions

## Hard rules
- 好みベースの指摘を主 findings にしない
- 既存不具合を差分起因のように扱わない
- 行儀の悪い要約でごまかさない
- 「多分危ない」で終わらせない。理由を書く
```

---

## 使い分け

ここが一番大事です。
**plan と review は別人格で運用した方がいい** です。Skill も混ぜない方がいい。理由は、公式の設計でも Skill は task-specific で、レビューは findings-first、計画は structured planning に寄せるほど精度が上がるからです。 ([OpenAI Developers][4])

* **プラン時**
  `plan-repo-mapper` → `plan-change-planner`
* **レビュー時**
  `review-diff-triage` → `review-risk-reviewer`

---

## あなた向けの率直な助言

今のあなたの進め方で危ないのは、**「Codex に賢くやってもらう」期待がまだ少し強いこと**です。
そこは甘いです。Codex は強いですが、強いからこそ **役割と出力形式を固定しないと、器用にブレます**。特に plan と review を同じ思想で扱うと失敗します。plan で重箱レビューを始めたり、review で設計相談を始めたりするからです。

先に整える優先順位はこれです。

1. **root `AGENTS.md` を短く固定する**
   ここで全部語ろうとしない。

2. **`docs/PLANS.md` と `docs/code_review.md` を分ける**
   これをやらないと mode の分離が曖昧なままです。

3. **Skill を4つだけに絞って入れる**
   最初から増やしすぎると運用不能になります。

4. **レビュー結果を評価する基準を決める**
   「有用な finding が何件出たか」「ノイズ率は何%か」を見ないと改善できません。公式も Skill を eval で改善する方向を勧めています。 ([OpenAI Developers][5])

次にやるべきことは、これをあなたの実際のリポジトリ構成に合わせて具体化することです。
たとえば Next.js / GAS / Playwright 前提で、`AGENTS.md` と各 Skill をあなたのプロジェクト向けに最適化した版まで落とせます。

[1]: https://developers.openai.com/codex/guides/agents-md/?utm_source=chatgpt.com "Custom instructions with AGENTS.md"
[2]: https://developers.openai.com/codex/learn/best-practices/?utm_source=chatgpt.com "Best practices"
[3]: https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide/?utm_source=chatgpt.com "Codex Prompting Guide"
[4]: https://developers.openai.com/codex/skills/?utm_source=chatgpt.com "Agent Skills"
[5]: https://developers.openai.com/blog/eval-skills/?utm_source=chatgpt.com "Testing Agent Skills Systematically with Evals"
