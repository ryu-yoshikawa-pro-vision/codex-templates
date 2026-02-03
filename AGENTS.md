# Codex Working Agreement

Codex must follow this document before doing any work in this repository.
(Reason: Codex reads AGENTS.md before starting tasks.) 

---

## 0. Always read first (in this order)
1) docs/PROJECT_CONTEXT.md
2) docs/adr/ (scan recent ADRs)
3) .codex/runs/ (if any recent run exists)
4) This AGENTS.md

> Keep `docs/PROJECT_CONTEXT.md` as a living document by updating it when new understanding is gained.
> Record significant architecture decisions as ADRs.

---

## 1. Run initialization (per request)
### Run ID
- Use `run_id = YYYYMMDD-HHMMSS-JST` (e.g., `20260118-143012-JST`)

### Create a new run folder
If no active run folder is specified by the user **and** you have not already created a run folder earlier in the same conversation/session:
1) Create: `.codex/runs/<run_id>/`
2) Copy templates:
   - `.codex/templates/PLAN.md`  -> `.codex/runs/<run_id>/PLAN.md`
   - `.codex/templates/TASKS.md` -> `.codex/runs/<run_id>/TASKS.md`
   - `.codex/templates/REPORT.md`-> `.codex/runs/<run_id>/REPORT.md`
3) Write the user request into PLAN.md (Objective / Scope / DoD)
4) Build TASKS.md as an executable checkbox list ordered top-to-bottom
5) **Same-session rule**: In the same conversation/session, keep updating the same PLAN/TASKS/REPORT files. Do not create a new run folder per turn unless the user explicitly asks to start a new run.

---

## 2. Execution loop (do this until done or blocked)
1) Execute tasks in `.codex/runs/<run_id>/TASKS.md` top-to-bottom
2) After completing a task:
   - Check the box in TASKS.md
   - Append a new entry to REPORT.md (JST timestamp)
   - Update progress percent (see §3) in the REPORT entry
3) If new tasks are discovered:
   - Add them under `## Discovered` in TASKS.md
   - Note why they appeared in REPORT.md
   - Continue execution
4) Stop only when:
   - All non-blocked tasks are done, or
   - You are blocked (then write a “Blocked” entry with concrete next actions)
5) Thinking/Logging rules:
   - 思考や判断理由は `.codex/runs/<run_id>/PLAN.md` の Thinking Log に必ず追記する
   - 行動ログ（調査/編集/判断/実行）は `.codex/runs/<run_id>/REPORT.md` に必ず追記する
   - 追加タスクは必ず `.codex/runs/<run_id>/TASKS.md` の `## Discovered` に追記する

---

## 3. Progress % definition (must be used in reporting)
### How to calculate
- Count tasks in `## Now` + `## Discovered` as the denominator
- Exclude tasks under `## Blocked` from the denominator
- Progress = round( done / total * 100 )

Where:
- total = number of checkboxes in Now + Discovered
- done  = number of checked boxes in Now + Discovered

### Required progress line format
- `Progress: <NN>% (<done>/<total>)`

---

## 4. User-facing report (MANDATORY in every response to the user)
Whenever you send a message to the user (chat reply / PR comment / final output), include:

1) **Summary (<= 5 bullets)**: what you changed / verified / decided
2) **Progress line** using §3 format
3) **Next** (if not 100%): next 1–3 tasks or what is blocked
4) **Evidence**: commands run + results, and/or key file paths changed

Example (format only):
- Summary:
  - ...
- Progress: 45% (5/11)
- Next:
  - ...
- Evidence:
  - `npm test` => PASS
  - Changed: path/to/file.ts

## Language policy (thinking in English, output in Japanese)
- Internal thinking: English.
- User-facing output: Japanese (summaries, progress reports, explanations, PRコメント、.mdドキュメントの追記を含む).
- Do NOT reveal chain-of-thought / internal reasoning. Only provide concise conclusions and evidence.
- Code: follow existing code style; do not translate identifiers unless the repo convention does.

---

## 5. Living documentation rule (do not skip)
- When you learn something new about the codebase (structure, gotchas, workflows, invariants):
  - Update `docs/PROJECT_CONTEXT.md` (add concise notes, keep it readable)
  - `docs/PROJECT_CONTEXT.md` は各プロジェクトの実態に合わせて調整し、開発の進行に伴って更新し続ける
- When you make a significant architectural decision (interfaces, data model, dependency direction, build/deploy strategy):
  - Add/update an ADR under `docs/adr/` (keep it short and decision-focused)

(ADR practice reference: store decisions with context + consequences.) 

---

## 6. Quality gates (before claiming done)
- Run relevant checks depending on the change:
  - unit/integration tests
  - lint
  - typecheck
  - build
- If tests are not available, state it explicitly in REPORT and in the user-facing report.

---

## 7. Safety / scope constraints
- Do not run destructive commands (delete/format disk, force push, etc.) unless explicitly requested
- Do not modify unrelated files; keep changes scoped
- Prefer small, reviewable commits (if committing)
- If assumptions are required, write them into PLAN.md and REPORT.md

---

## 8. “One-shot to the end” instruction (copy/paste for `codex exec`)
Use this prompt as-is when running Codex in non-interactive mode (or as the initial prompt).

PROMPT START
You are Codex working in this repository. Follow AGENTS.md strictly.

Goal: Implement the user request end-to-end.

Process requirements:
- If no active run exists, create `.codex/runs/<run_id>/` using `run_id = YYYYMMDD-HHMMSS-JST` and copy from `.codex/templates/{PLAN,TASKS,REPORT}.md`.
- Fill `.codex/runs/<run_id>/PLAN.md` (Objective/Scope/Assumptions/DoD) and create an ordered checkbox list in `.codex/runs/<run_id>/TASKS.md`.
- Execute tasks top-to-bottom. After each completed task:
  - Check the box in TASKS.md
  - Append an entry to REPORT.md with JST timestamp
  - Include `Progress: <NN>% (<done>/<total>)` using AGENTS.md §3
- If you discover new tasks, add them under `## Discovered` and continue.
- Continuously update `docs/PROJECT_CONTEXT.md` with any new understanding.
- For significant architectural decisions, add/update an ADR under `docs/adr/`.
- Run relevant checks (tests/lint/typecheck/build) before finishing.

User-facing output requirement (every time you respond):
- Provide <=5 bullet summary + progress percent + next steps (if not done) + evidence (commands/results and key file paths).

Now perform the work.
PROMPT END

---

## Notes (source pointers)
- Codex reads AGENTS.md before doing work; use it to encode project-specific norms.
- `codex exec` can run non-interactively; GitHub Action can run it in CI.
