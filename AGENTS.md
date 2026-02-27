# Codex Working Agreement

Codex must follow this document before doing any work in this repository.
(Reason: Codex reads AGENTS.md before starting tasks.) 

---

## 0. Always read first (in this order)
1) docs/PROJECT_CONTEXT.md
2) docs/adr/ (scan recent ADRs)
3) .codex/runs/ (if any recent run exists)
4) This AGENTS.md
5) `docs/agent/overrides.md` (project-common mandatory policy file; always read and apply)

> Keep `docs/PROJECT_CONTEXT.md` as a living document by updating it when new understanding is gained.
> Record significant architecture decisions as ADRs.
> In this repository, `docs/agent/overrides.md` is mandatory. If it is missing or unreadable, stop and report blocked status.

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
6) **Cross-session rule**: In a different/new conversation session, do **not** append to previous run folders by default. Create a new run folder unless the user explicitly designates an existing run folder to continue.

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
   - Always append thinking notes and decision reasons to the Thinking Log in `.codex/runs/<run_id>/PLAN.md`.
   - Always append action logs (investigation/editing/decision/execution) to `.codex/runs/<run_id>/REPORT.md`.
   - Always append newly discovered tasks to `## Discovered` in `.codex/runs/<run_id>/TASKS.md`.

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
- User-facing output: Japanese (summaries, progress reports, explanations, PR comments, and `.md` document updates).
- All run artifacts and working documents (for example, `PLAN.md`, `TASKS.md`, and `REPORT.md`) must be written in Japanese.
- `AGENTS.md` must be written in English only.
- Do NOT reveal chain-of-thought / internal reasoning. Only provide concise conclusions and evidence.
- Code: follow existing code style; do not translate identifiers unless the repo convention does.

---

## 5. Living documentation rule (do not skip)
- When you learn something new about the codebase (structure, gotchas, workflows, invariants):
  - Update `docs/PROJECT_CONTEXT.md` (add concise notes, keep it readable)
  - Keep `docs/PROJECT_CONTEXT.md` aligned to the real project state and continuously update it as development progresses.
- When you make a significant architectural decision (interfaces, data model, dependency direction, build/deploy strategy):
  - Add/update an ADR under `docs/adr/` (keep it short and decision-focused)

(ADR practice reference: store decisions with context + consequences.) 

---

## 6. Quality gates (before claiming done)
- Run relevant checks depending on the change:
  - unit/integration tests
  - formatter
  - lint
  - typecheck
  - build
- If a project configures formatter/lint/typecheck, run those checks and confirm there are no errors before sending a completion report.
- If tests are not available, state it explicitly in REPORT and in the user-facing report.

---

## 7. Safety / scope constraints
- Do not run destructive commands (delete/format disk, force push, etc.) unless explicitly requested
- Do not modify unrelated files; keep changes scoped
- Prefer small, reviewable commits (if committing)
- If assumptions are required, write them into PLAN.md and REPORT.md

## 7.1 Local Codex Safety Harness (repository-specific)
- For manual or CI Codex runs in this repository, prefer `scripts/codex-safe.ps1` instead of invoking `codex` directly.
- Do not use `--dangerously-bypass-approvals-and-sandbox` in this repository unless the user explicitly asks and the environment is externally sandboxed.
- Keep repository execpolicy rules under `.codex/rules/*.rules` and validate changes with `codex execpolicy check` (or wrapper preflight) before reporting completion.
- Treat user-provided `-c/--config` overrides, `--add-dir`, and unsafe sandbox/approval overrides as disallowed in the local safety wrapper.

---

## 8. “One-shot to the end” instruction (copy/paste for `codex exec`)
Use this prompt as-is when running Codex in non-interactive mode (or as the initial prompt).

PROMPT START
You are Codex working in this repository. Follow AGENTS.md strictly.

Goal: Implement the user request end-to-end.

Process requirements:
- If no active run exists, create `.codex/runs/<run_id>/` using `run_id = YYYYMMDD-HHMMSS-JST` and copy from `.codex/templates/{PLAN,TASKS,REPORT}.md`.
- In a new/different conversation session, always start a new run folder by default; continue an old run folder only when the user explicitly specifies it.
- Fill `.codex/runs/<run_id>/PLAN.md` (Objective/Scope/Assumptions/DoD) and create an ordered checkbox list in `.codex/runs/<run_id>/TASKS.md`.
- Write `PLAN.md`, `TASKS.md`, and `REPORT.md` entries in Japanese (while keeping `AGENTS.md` in English only).
- Execute tasks top-to-bottom. After each completed task:
  - Check the box in TASKS.md
  - Append an entry to REPORT.md with JST timestamp
  - Include `Progress: <NN>% (<done>/<total>)` using AGENTS.md §3
- If you discover new tasks, add them under `## Discovered` and continue.
- Continuously update `docs/PROJECT_CONTEXT.md` with any new understanding.
- For significant architectural decisions, add/update an ADR under `docs/adr/`.
- Run relevant checks (tests/formatter/lint/typecheck/build) before finishing.
- If formatter/lint/typecheck are configured in the project, run them and verify there are no errors before sending a completion report.

User-facing output requirement (every time you respond):
- Provide <=5 bullet summary + progress percent + next steps (if not done) + evidence (commands/results and key file paths).

Now perform the work.
PROMPT END

---


## 9. Plan document rule (when user asks for a plan)
- If the user asks you to create a plan, you MUST create a plan document under `docs/plans/`.
- File name format: `{yyyy-mm-dd}_{plan_name}.md` (example: `2026-02-19_release-plan.md`).
- The date part must use JST (`Asia/Tokyo`) calendar date.
- When creating the plan file, use `docs/plans/TEMPLATE.md` as the base template.

---

## 10. Autonomous research loop (PLAN -> SEARCH -> TASKS -> EXECUTE -> REPORT)
- For requests with unknowns, define hypotheses in PLAN before implementation.
- Run web research in rounds and record evidence using:
  - `Record ID`, `Round`, `Query`, `Source`, `Supports/Refutes`, `Confidence`, `Decision`, `Rationale`, `Open Issues`, `Next Action`
- Use at least 2 rounds when uncertainty remains after the first pass.
- Move actionable findings into `TASKS.md` (`Now` / `Discovered`) and execute top-to-bottom.
- Treat REPORT as append-only execution trace; every major action must be logged with evidence.
- Exit the loop only when major hypotheses have support/refute evidence and open issues have next actions.

---

## 11. Skills and self-improvement governance
- Skill discovery and installation must follow `docs/agent/skill-discovery-workflow.md`.
- Role-oriented execution (Planner/Researcher/Executor/Reviewer) should follow `docs/agent/agent-role-design.md` and templates under `docs/agent/templates/`.
- Improvement proposals must follow `docs/agent/improvement-guardrails.md`.
- `docs/agent/overrides.md` is project-common mandatory guidance and must be enforced for every request.
- Approval boundary:
  - L1 (low risk): self-approval allowed with REPORT log.
  - L2/L3 (medium/high risk): explicit user approval required before execution.
- Every improvement proposal must include rollback planning before applying changes.

---

## Notes (source pointers)
- Codex reads AGENTS.md before doing work; use it to encode project-specific norms.
- `codex exec` can run non-interactively; GitHub Action can run it in CI.

---

## 12. Lightweight Execution Mode (for small low-risk tasks)

Use this mode only when all conditions are true:
- The request is narrowly scoped and can be completed in one short edit or one short verification pass.
- No architectural decision, policy change, or safety-sensitive change is involved.
- No unresolved unknowns require multi-round research.

Minimum requirements in lightweight mode:
- Still create or continue the session run and update `PLAN/TASKS/REPORT`.
- Keep tasks minimal (typically 1-3 concrete checkboxes).
- Record at least one evidence command and one progress line.
- Keep safety constraints, approval boundaries, and non-destructive rules unchanged.

Lightweight mode is not allowed when:
- Changes touch `AGENTS.md`, safety harness, approval/sandbox behavior, or other L2/L3 areas.
- The request requires web research rounds by rule.
- The request has significant ambiguity, cross-file refactor risk, or external dependency uncertainty.
