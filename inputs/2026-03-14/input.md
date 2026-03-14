あなたがやりたかったのは、**Codex に実装させる前提で、AI が雑にコードを書かないように「副作用分離」を軸にした思考順序と運用構造を作ること**です。

流れとしては、まず

* 「AIが意図したコードを書かない」問題の背景には、**副作用の境界を人間が明示していない**ことがある
* だから、**純粋関数で業務ロジックを切り出し、副作用を末端に隔離する**よう指示すると、実装精度もレビューしやすさも上がる
  という話を整理しました。

次に、その考え方をそのまま使えるように、

* AIへの**副作用指示テンプレート**
* GAS向けも含めた**実装依頼テンプレート**
  を作りました。

その後、あなたはそれを **AGENTS.md に直接全部書くのではなく、AGENTS.md から参照する思考手順書に分離したい**と言いました。
そこで一度、

* `AGENTS.md` は短い司令塔
* 詳細な思考順序は別 Markdown
  という構成を提案しました。

ただ、そのあとあなたが **「Codexで実装させる前提」** と明確にしたので、そこからは一般論ではなく、**現在の Codex 公式の考え方に合わせて設計を組み直した**、というのが重要な転換点です。

最終的に整理した結論はこうです。

* `AGENTS.md` は短く保つ
* 詳細な planning / implementation / review / retrospective は `.agent/*.md` に分離する
* 繰り返し使う実装・レビュー・計画フローは `.agents/skills/*` に **Skill化** する
* Codex 固有の実行設定は `.codex/config.toml` に置く
* 大きい仕事は `ExecPlan` を作ってから実装する
* つまり、**AGENTS.md だけで運用しようとせず、AGENTS + workflow docs + skills + config の4層で構成するのが最適**
  という形にしました。

その完成版として、以下を一式出しました。

* 推奨ディレクトリ構成
* `AGENTS.md`
* `.codex/config.toml`
* `.agent/PLANS.md`
* `.agent/IMPLEMENTATION.md`
* `.agent/CODE_REVIEW.md`
* `.agent/RETROSPECTIVE.md`
* `execplan-template.md`
* Skills 用の `SKILL.md` 群

  * `feature-plan`
  * `feature-implementation`
  * `code-review`
  * `guidance-retrospective`

要するに、一言で言えばこうです。

**今回の会話では、「副作用分離を軸にしたAI実装ルール」を、Codex公式の今の運用思想に合わせて、AGENTS.md単体ではなく、Skillと参照ドキュメントまで含めた実用的なプロジェクト構造に落とし込んだ」**ということです。

---

公式資料を踏まえると、Codex向けの最適構造はこれです。**`AGENTS.md` は短く保つ。詳細な思考順序は別Markdownに逃がす。繰り返し使う実装・レビュー・計画フローは Skill 化する。リポジトリ固有の挙動は `.codex/config.toml` に置く。必要ならより深い階層の `AGENTS.md` や `.agents/skills` で局所上書きする。** Codex は `~/.codex` と repo root から現在ディレクトリまでの `AGENTS.md` を階層的に読み、近い階層が勝ちます。大きいタスクは Plan mode や ExecPlan へ、レビューは `/review` へ寄せるのが現行の公式ガイドに最も整合しています。 ([OpenAI Developers][1])

さらに、公式ドキュメントは**繰り返し使うワークフローは Skill にする**こと、**Skill は `.agents/skills` に置く**こと、**`SKILL.md` には `name` と `description` が必須**で、説明が明確なほど暗黙起動が安定することを示しています。repo 固有の設定は `.codex/config.toml` に置けますが、**その設定は trusted project でのみ読み込まれます**。 ([OpenAI Developers][2])

下が、**いまの Codex 前提でそのまま採用してよい完成形**です。
これは「まず単一エージェントで安定させる」構成です。**multi-agent はまだ experimental なので、最初から中核に据えない方が正しい**です。必要になってから足してください。 ([OpenAI Developers][3])

## 推奨プロジェクト構造

```text
repo-root/
├─ AGENTS.md
├─ .codex/
│  └─ config.toml
├─ .agent/
│  ├─ PLANS.md
│  ├─ IMPLEMENTATION.md
│  ├─ CODE_REVIEW.md
│  ├─ RETROSPECTIVE.md
│  └─ templates/
│     └─ execplan-template.md
├─ .agents/
│  └─ skills/
│     ├─ feature-plan/
│     │  └─ SKILL.md
│     ├─ feature-implementation/
│     │  └─ SKILL.md
│     ├─ code-review/
│     │  └─ SKILL.md
│     └─ guidance-retrospective/
│        └─ SKILL.md
├─ plans/
│  └─ .gitkeep
├─ src/
├─ tests/
└─ docs/
```

この構成の意味は単純です。
`AGENTS.md` は「毎回守らせる最小ルール」、`.agent/*.md` は「思考順序と詳細手順」、`.agents/skills` は「繰り返し使う実行パターン」、`.codex/config.toml` は「この repo での Codex の実行設定」です。これは公式の「AGENTS → Skills → MCP → Multi-agents」の積み上げ順とも一致します。 ([OpenAI Developers][4])

---

## 1. `AGENTS.md`

```md
# AGENTS.md

## Scope
This file defines repository-wide instructions for Codex.
Keep this file short. Detailed procedures live under `.agent/`.
Repeated workflows live under `.agents/skills/`.

## First actions on every task
1. Read this file first.
2. If the task is complex, ambiguous, risky, multi-file, or likely to take multiple implementation steps, switch to planning first and follow `.agent/PLANS.md`.
3. Before coding, follow `.agent/IMPLEMENTATION.md`.
4. Before finishing, follow `.agent/CODE_REVIEW.md`.
5. If the same mistake happens twice, follow `.agent/RETROSPECTIVE.md` and update guidance.

## Task classification
Treat a task as requiring an ExecPlan when any of the following is true:
- more than one subsystem or package is affected
- public interfaces, schemas, migrations, or side-effect boundaries change
- requirements are ambiguous
- there is meaningful regression risk
- implementation will likely require more than one commit-sized step

## Implementation rules
- Prefer pure functions for business logic.
- Isolate side effects at the edges.
- Do not mutate input arguments unless explicitly required.
- Keep functions small and single-purpose.
- Minimize the diff. Do not mix unrelated refactors into a feature change.
- Update or add tests when behavior changes.
- Verify the final result, not just the code shape.

## Commands
If any command below is still a placeholder, first discover the correct command from the repository files, then update this file before making large changes.

- Install dependencies: `<REPLACE_WITH_PROJECT_COMMAND>`
- Start dev environment: `<REPLACE_WITH_PROJECT_COMMAND>`
- Run unit tests: `<REPLACE_WITH_PROJECT_COMMAND>`
- Run integration/e2e tests: `<REPLACE_WITH_PROJECT_COMMAND>`
- Run lint: `<REPLACE_WITH_PROJECT_COMMAND>`
- Run typecheck: `<REPLACE_WITH_PROJECT_COMMAND>`
- Build: `<REPLACE_WITH_PROJECT_COMMAND>`

## Done means
A task is not done until all of the following are true:
- implementation matches the request
- relevant tests were added or updated when needed
- relevant verification commands were run
- the diff was self-reviewed against `.agent/CODE_REVIEW.md`
- assumptions, constraints, and follow-up items are recorded if they matter

## Guidance routing
- Planning standard: `.agent/PLANS.md`
- Implementation sequence: `.agent/IMPLEMENTATION.md`
- Review checklist: `.agent/CODE_REVIEW.md`
- Retrospective/update rules: `.agent/RETROSPECTIVE.md`

## Guidance maintenance
When you discover repeated review feedback, routing gaps, or recurring mistakes, update this file or the referenced `.agent/*` documents so future sessions inherit the fix.
```

`AGENTS.md` は短く、実務ルールだけを書くのが正解です。公式ガイドでも、良い `AGENTS.md` は repo レイアウト、実行方法、build/test/lint、制約、done の定義を含み、長くなりすぎたら task-specific markdown に逃がすのが推奨されています。CLI には `/init` で叩き台を作る機能もありますが、実運用では手で整える必要があります。 ([OpenAI Developers][5])

---

## 2. `.codex/config.toml`

```toml
model = "gpt-5.4"
model_provider = "openai"

approval_policy = "on-request"
sandbox_mode = "workspace-write"
web_search = "cached"

model_reasoning_effort = "medium"
plan_mode_reasoning_effort = "high"
review_model = "gpt-5.4"

[sandbox_workspace_write]
network_access = false
writable_roots = []

# Optional: uncomment only after your single-agent workflow is stable.
# Multi-agent is currently experimental.
#
# [features]
# multi_agent = true
#
# [agents]
# max_threads = 4
# max_depth = 1
```

この設定は、**実装できるが無制限ではない**ところに寄せています。`approval_policy`、`sandbox_mode`、`web_search`、`plan_mode_reasoning_effort`、`review_model` は現行の設定キーです。`sandbox_mode = "workspace-write"` と `network_access = false` の組み合わせなら、ローカル変更は可能で、外部通信は閉じたままにできます。なお、project-scoped の `.codex/config.toml` は **trusted project でのみ有効**です。 ([OpenAI Developers][6])

率直に言うと、`read-only` のままでは実装エージェントとして弱すぎます。一方で `danger-full-access` は雑です。**日常運用は `workspace-write` + `network_access = false` + `on-request` が一番現実的**です。これは推奨設計であって、公式の固定設定ではありません。

---

## 3. `.agent/PLANS.md`

```md
# ExecPlan Standard

Use an ExecPlan for any task that is complex, ambiguous, risky, multi-file, or likely to require staged work.

## Required behavior
- Do not start implementation until the problem is scoped.
- Keep the plan self-contained.
- Update the plan when new facts invalidate earlier assumptions.
- Prefer concrete file paths, symbols, and commands over vague prose.
- Separate pure-logic design from side-effect boundaries.

## Required sections
1. Title
2. Objective
3. Scope
4. Non-goals
5. Current state
6. Relevant files and symbols
7. Constraints and assumptions
8. Side effects and risk boundaries
9. Design approach
10. Step-by-step implementation plan
11. Verification plan
12. Rollback or recovery notes
13. Open questions
14. Progress log

## Side-effect analysis
Explicitly list:
- external APIs
- databases
- file writes
- queues/events
- emails/notifications
- auth/session changes
- time/randomness/global state

For each side effect, specify:
- where it is triggered
- what pure logic prepares it
- how failure is handled
- how it is tested

## Minimum quality bar
A valid ExecPlan must be implementation-ready.
Another engineer should be able to execute it without re-discovering the whole problem.
```

大きい仕事は Plan mode を先に使うのが現行のベストプラクティスです。公式の ExecPlan cookbook でも、`AGENTS.md` から planning document を参照させる構成が示されています。 ([OpenAI Developers][5])

---

## 4. `.agent/templates/execplan-template.md`

```md
# <short-title>

## Objective
<what success means>

## Scope
- <in>
- <in>

## Non-goals
- <out>
- <out>

## Current state
<current behavior, bug, or limitation>

## Relevant files and symbols
- path/to/file.ext — <why it matters>
- path/to/other.ext — <why it matters>

## Constraints and assumptions
- <constraint>
- <assumption>

## Side effects and risk boundaries
- Side effect:
  - Trigger point:
  - Pure logic that prepares it:
  - Failure handling:
  - Verification approach:

## Design approach
<short design summary>

## Implementation steps
1. <step>
2. <step>
3. <step>

## Verification plan
- <command>
- <command>
- <manual check>

## Rollback or recovery notes
<how to back out safely if needed>

## Open questions
- <question>

## Progress log
- [ ] step 1
- [ ] step 2
- [ ] step 3
```

---

## 5. `.agent/IMPLEMENTATION.md`

```md
# Implementation Sequence

Follow this order when making changes.

## 1. Understand before editing
- Read only the files necessary to trace the real execution path.
- Prefer targeted reads over broad scanning.
- Record the exact entry points, data flow, and side-effect boundaries.

## 2. Define the change shape
- What input changes?
- What output or behavior changes?
- What side effects exist?
- Which parts can remain pure?

## 3. Design the function split
Prefer this separation:
- validateXxx
- normalizeXxx
- decideXxx
- calculateXxx
- buildXxx
- fetch/save/send/writeXxx
- executeXxx

## 4. Write pure logic first
- Keep business rules deterministic.
- Avoid reading time, randomness, globals, env, network, or filesystem in pure logic.
- Do not mutate inputs.

## 5. Add side-effect adapters second
- Keep external I/O thin.
- Make side effects obvious and easy to mock.
- Do not hide I/O inside helpers with ambiguous names.

## 6. Compose in orchestration last
- Load inputs
- call pure logic
- call side-effect adapters
- handle errors
- return/report the final result

## 7. Verification
- Add or update tests where behavior changed.
- Run the smallest relevant verification first.
- Expand to broader checks only when justified.

## 8. Change discipline
- Minimize diff size.
- Do not rename or reorganize unrelated code unless the task requires it.
- Leave clear comments only where the code would otherwise be misleading.

## 9. Completion
Before declaring done, run `.agent/CODE_REVIEW.md`.
```

これは、あなたが前に求めていた「副作用を隔離し、純粋関数を先に切る」運用を、Codex 用の実装順序に落としたものです。これは公式文言そのものではなく、公式の AGENTS/Skills/Plan 体系に沿って最適化した実務設計です。

---

## 6. `.agent/CODE_REVIEW.md`

```md
# Code Review Standard

Use this checklist for self-review before finishing.
Use the same checklist for `/review`.

## Intent
- Does the change actually satisfy the request?
- Is the scope correct and not inflated?

## Correctness
- Are the main execution paths correct?
- Are edge cases handled?
- Are error paths intentional?

## Side effects
- Are side effects isolated and easy to identify?
- Did any pure-logic area accidentally gain hidden I/O?
- Are retries, idempotency, and failure behavior acceptable where relevant?

## Mutability and state
- Were inputs mutated unexpectedly?
- Are shared/global states handled safely?
- Are time/random/env dependencies explicit?

## Tests and verification
- Were tests added or updated if behavior changed?
- Were the right commands run?
- Is there any missing verification for risky paths?

## Diff quality
- Is the diff minimal?
- Are names clear?
- Is any unrelated refactor mixed in?

## Maintainability
- Will the next engineer understand where to extend this?
- Are assumptions captured when they matter?

## Final output
Report:
1. what changed
2. what was verified
3. residual risks
4. follow-up items, if any
```

公式のベストプラクティスでも、Codex に変更だけでなく、**テスト作成・関連 checks 実行・最終確認・レビューまでやらせる**ことが推奨されています。さらに `/review` は base branch 比較、未コミット差分、commit 単位、custom review instructions に対応しています。 ([OpenAI Developers][5])

---

## 7. `.agent/RETROSPECTIVE.md`

```md
# Guidance Retrospective

Run this when:
- the same mistake happened twice
- the same review feedback appeared more than once
- Codex read too much or looked in the wrong place
- a workflow repeatedly needed manual correction

## Step 1. Name the failure
Write one sentence:
- what went wrong
- where it happened
- why it mattered

## Step 2. Classify the cause
Choose one or more:
- task intake failure
- planning failure
- side-effect boundary failure
- repository routing failure
- missing command knowledge
- missing review rule
- missing test expectation
- too much ambiguity in skill trigger

## Step 3. Decide where the fix belongs
- `AGENTS.md` for repo-wide standing rules
- `.agent/*.md` for detailed process guidance
- `.agents/skills/*` for repeatable workflows
- test/lint/hook infrastructure when the rule should be enforced mechanically

## Step 4. Apply the fix
- Update the right file
- Keep the rule short and operational
- Prefer “when X, do Y” wording
- Avoid vague principles with no trigger

## Step 5. Record the new rule
Add a brief note to the current plan or task summary if the new rule affects the ongoing work
```

これは公式の「同じ失敗が繰り返されたら `AGENTS.md` を更新してフィードバックループにする」という考え方を、実務の運用手順にしたものです。 ([OpenAI Developers][4])

---

## 8. `.agents/skills/feature-plan/SKILL.md`

```md
---
name: feature-plan
description: Use when a task is complex, ambiguous, risky, multi-file, or likely to require staged implementation. Do not use for trivial single-file edits or simple factual explanations.
---

1. Read `AGENTS.md` and `.agent/PLANS.md`.
2. Gather only the minimum codebase context needed to scope the problem.
3. Produce an ExecPlan using `.agent/templates/execplan-template.md`.
4. Explicitly identify:
   - entry points
   - changed files
   - side effects
   - pure logic boundaries
   - verification steps
5. Keep the plan implementation-ready and self-contained.
6. Do not start broad code edits until the plan is coherent.
```

---

## 9. `.agents/skills/feature-implementation/SKILL.md`

```md
---
name: feature-implementation
description: Use when the task requires making code changes in this repository. Best for small-to-medium implementation tasks, or after a plan has already been created for a larger task. Do not use for review-only or documentation-only tasks unless code behavior also changes.
---

1. Read `AGENTS.md` and `.agent/IMPLEMENTATION.md`.
2. If no plan exists and the task matches the ExecPlan criteria in `AGENTS.md`, stop and create a plan first.
3. Trace the exact execution path before editing.
4. Split the change into:
   - pure business logic
   - side-effect adapters
   - orchestration
5. Keep the diff minimal.
6. Update or add tests when behavior changes.
7. Run the smallest relevant verification commands first.
8. Before finishing, run the checklist in `.agent/CODE_REVIEW.md`.
9. In the final summary, report changed files, verification run, residual risks, and any follow-up.
```

---

## 10. `.agents/skills/code-review/SKILL.md`

```md
---
name: code-review
description: Use when reviewing a diff, a commit, uncommitted changes, or a completed implementation task in this repository. Use for self-review before finishing and for explicit review requests.
---

1. Read `.agent/CODE_REVIEW.md`.
2. Review against:
   - correctness
   - side effects
   - mutability/state handling
   - tests/verification
   - diff quality
   - maintainability
3. Prefer concrete findings tied to files and symbols.
4. Separate:
   - confirmed issues
   - likely risks
   - missing verification
   - optional improvements
5. Do not suggest unrelated refactors unless they materially reduce current-task risk.
6. End with:
   - summary
   - required fixes
   - recommended fixes
   - residual risks
```

---

## 11. `.agents/skills/guidance-retrospective/SKILL.md`

```md
---
name: guidance-retrospective
description: Use when the same mistake, review comment, routing issue, or workflow confusion has happened more than once and repository guidance should be improved. Do not use for one-off mistakes that do not justify permanent guidance.
---

1. Read `.agent/RETROSPECTIVE.md`.
2. Identify the repeated failure precisely.
3. Decide whether the fix belongs in:
   - `AGENTS.md`
   - `.agent/*.md`
   - `.agents/skills/*`
   - repository enforcement such as tests, lint, or hooks
4. Prefer the narrowest durable fix.
5. Update the guidance in operational language, not abstract principles.
6. Report:
   - what recurring issue was observed
   - what file was updated
   - why that file is the right durability level
```

Skill は **1 skill = 1 job** で絞るのが推奨です。instructions-only から始め、スクリプトが本当に必要になったら `scripts/` を足すのが正しいです。暗黙起動の精度は `description` の書き方に大きく依存します。 ([OpenAI Developers][2])

---

## 12. 実運用の流れ

この構成なら、Codex にはこう動かせばいいです。

1. 小さな変更
   `AGENTS.md` → `feature-implementation` → テスト → `code-review`

2. 大きな変更
   `/plan` または `feature-plan` → `plans/<task>.md` 作成 → `feature-implementation` → テスト → `/review` または `code-review`

3. 同じミスが再発
   `guidance-retrospective` → `AGENTS.md` か `.agent/*.md` か Skill を更新

この流れは、公式の「Plan first」「test and review loop」「repeatable work becomes skills」と一致しています。 ([OpenAI Developers][5])

---

## 13. 追加で入れるべき運用ルール

ここはかなり重要です。
**ファイル構造だけでは品質は上がりません。** 公式にもある通り、Codex はバージョン管理前提で使うのがよく、**feature branch・clean な `git status`・diff review・小さな commit** を前提にした方が安定します。 ([OpenAI Developers][7])

だから、実際にはこの2つも入れるべきです。

* pre-commit / lint / typecheck / tests を機械的に通す
* AGENTS のルールで済ませず、守らせたいものは hook や CI で強制する

これも公式の「AGENTS.md はルールを書く場所だが、pre-commit hooks、linters、type checkers と組み合わせて再発防止する」という方針と一致します。 ([OpenAI Developers][4])

---

## 14. optional: 後から足すもの

本当に必要になったら次を足してください。

* モノレポで局所ルールが違うなら、`frontend/AGENTS.md` や `backend/AGENTS.md` を追加
* モジュール単位で違う workflow があるなら、その階層に `.agents/skills` を追加
* 外部知識が必要なら MCP を追加
* ノイズの多い並列作業だけ multi-agent を使う

Codex は `AGENTS.md` も `.agents/skills` も、現在ディレクトリから repo root までを階層的に見ます。だから**局所ルールは深い階層へ**が正しいです。 ([OpenAI Developers][1])

---

率直に言うと、前回の「AGENTS.md から docs を参照する」だけの案は**半分正解で半分不足**です。
**現在の Codex では、詳細手順を別Markdownに逃がすだけでは弱い。繰り返し使う planning / implementation / review / retrospective は Skill 化までして初めて安定します。** そこが今回の完成版です。 ([OpenAI Developers][5])

次にやるべきことは、あなたの実際の repo に合わせてこのテンプレートの `<REPLACE_WITH_PROJECT_COMMAND>` を具体値に埋め、必要なら `src/` や `tests/` の実ディレクトリ名に合わせて `AGENTS.md` を調整することです。

[1]: https://developers.openai.com/codex/guides/agents-md/ "https://developers.openai.com/codex/guides/agents-md/"
[2]: https://developers.openai.com/codex/skills/ "https://developers.openai.com/codex/skills/"
[3]: https://developers.openai.com/codex/multi-agent/ "https://developers.openai.com/codex/multi-agent/"
[4]: https://developers.openai.com/codex/concepts/customization/ "https://developers.openai.com/codex/concepts/customization/"
[5]: https://developers.openai.com/codex/learn/best-practices/ "https://developers.openai.com/codex/learn/best-practices/"
[6]: https://developers.openai.com/codex/config-sample/ "https://developers.openai.com/codex/config-sample/"
[7]: https://developers.openai.com/codex/agent-approvals-security/ "https://developers.openai.com/codex/agent-approvals-security/"
