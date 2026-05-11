# CLAUDE.md — Playwright Test Harness (this repository)

This file is loaded into Claude Code's context whenever you work in **this**
repository. It governs how to modify the harness itself.

## What this repo is

This repo is the **Playwright Test Harness** — a set of Claude Code agents,
skills-style markdown specs, and helper scripts. When installed into a Playwright
project, it lets a user generate or update a Playwright test from a single
screenshot + one trigger phrase ("增加 SA-001 用例", "add test for TC-050", …).

> **This repo is *not* a Playwright test project.** Do not generate test code
> here. Do not run `npx playwright test` here. The harness is exercised by
> copying it into a real target project and triggering the `add-test` agent
> there.

## Layout

```
.claude/agents/        # The 6 agents — orchestrator + 5 pipeline stages
  add-test.md          #   Orchestrator (entry point)
  test-analyst.md      #   1. Requirement extraction
  test-architect.md    #   2. Design + MCP selector validation
  test-coder.md        #   3. Code generation
  test-runner.md       #   4. Test execution + failure repair
  test-summarizer.md   #   5. Knowledge extraction back into target project
.claude/skills/        # Skill templates (reusable operation templates — business flows or technical patterns)
  example-flow.md      #   Reference example — not a working skill
.claude/settings.local.json  # Local permission allowlist
.claude/context/coding-rules.md   # Reference template for target projects (not loaded by the harness itself)
scripts/               # Helper scripts the agents shell out to
  cleanup-artifacts.sh #   Removes /tmp/tc_*.md after a run
  test-quick.sh        #   Single-test runner used by test-runner
  typecheck.sh         #   tsc --noEmit gate used by test-coder
  lint-patterns.sh     #   Forbidden-pattern check used by test-coder
README.md              # User-facing docs
CLAUDE.md              # This file
```

## Architecture in one paragraph

The orchestrator (`add-test.md`) chains five sub-agents. Each stage **writes a
markdown artifact to `/tmp/tc_{case_id}_{stage}.md`**. The next stage reads
*only* that artifact, not the previous agent's chat output. This is how the
pipeline keeps each agent's context small and lets long-running iteration loops
(test-runner) work without drifting.

```
User screenshot + trigger phrase
        ↓
[1] test-analyst     → /tmp/tc_{id}_requirement.md
[2] test-architect   → /tmp/tc_{id}_design.md       (reads requirement.md, validates selectors via MCP)
[3] test-coder       → writes test + page-object code (reads requirement.md + design.md)
[4] test-runner      → /tmp/tc_{id}_run_report.md   (loops on failure, may escalate up to step 1 or 2)
[5] test-summarizer  → updates target project's CLAUDE.md / agent files / memory
```

## Where different kinds of knowledge live

The harness separates five kinds of knowledge. Keep them separate when editing.

| Kind | Example | Where it lives |
|---|---|---|
| **A. Generic Playwright/MCP rules** | "Don't gate clicks on `isVisible()`"; MCP workflow | This repo's `.claude/context/coding-rules.md` (a template the user copies into their project) |
| **B. Project-specific coding style** | "Files tab assertions omit the extension"; "wait for `.ant-spin-spinning`" | The **target project's** `CLAUDE.md` and/or `.claude/context/coding-rules.md` |
| **C. Reusable operation skills** | Business flows ("create record + verify"), or recurring technical patterns ("login as role X", "wait for AI processing to finish") that multiple tests invoke | The **target project's** `.claude/skills/*.md` (this repo only ships `example-flow.md` as a reference) |
| **D. Project-level facts** | Feature flags that are on, stable test data IDs, env constraints | The **target project's** `.claude/context/project-facts.md` — written by summarizer, read by architect, lives in git so the whole team shares it |
| **E. Real working examples** | A passing spec + its page-object methods | Already in the target project's `tests/` and `pages/` — the architect agent globs and reads them |

This repo only ships **A** (template) and **C** (one example). It must never
ship **B** or **D** (those belong to the user's project) and doesn't need to
ship **E** (lives in user code).

## Rules for modifying the harness

### 1. Keep agents project-agnostic

The harness is meant to drop into **any** Playwright project. Anything specific
to one application belongs in the target project's `CLAUDE.md` or
`.claude/context/coding-rules.md`, not in an agent file here.

**Forbidden in agent files:**
- Hardcoded absolute paths (`/Users/<name>/Workspace/<project>/…`).
- Specific business concepts from any one app (case names, connector vendors,
  role names like `OPS2_ADMIN`).
- Specific URLs, fixture names, or page-object names.

**Allowed in agent files:**
- Generic Playwright patterns (locator priority, wait strategies, virtual
  scroll handling).
- Ant Design / Material UI examples *as illustrations*, clearly marked.
- Placeholder syntax: `RoleName.{ROLE}`, `{fixture1}`, `<project-fixtures-import>`.

### 2. Respect the agent contract

Each agent has a defined **input artifact**, **output artifact**, and **scope**.
Don't move responsibility between them.

| Agent           | Reads                          | Writes                   | Scope                                     |
|-----------------|--------------------------------|--------------------------|-------------------------------------------|
| test-analyst    | User input                     | `requirement.md`         | What the user wants. No selectors.        |
| test-architect  | `requirement.md`               | `design.md`              | How to implement. MCP-validated selectors.|
| test-coder      | `requirement.md` + `design.md` | Test + page-object files | Code only. No MCP. No invented selectors. |
| test-runner     | `design.md` + code             | `run_report.md`          | Run, classify failures, fix or escalate.  |
| test-summarizer | All artifacts                  | Target project knowledge | Extract reusable lessons.                 |

If you add a rule about selectors to `test-coder.md`, it's in the wrong file —
move it to `test-architect.md`. The coder doesn't decide selectors.

### 3. Artifact protocol

- File names: `/tmp/tc_{case_id}_{stage}.md`. Lowercase, underscores. CASE_ID
  comes from user input; if absent, use `tc_draft`.
- An agent **must** write its artifact before completing — don't return content
  inline. The next stage reads from disk, not from chat history.
- The orchestrator never relays artifact *content* between agents; it only
  routes and gates.

### 4. Don't generate test code in this repo

If you find yourself opening `tests/` here, you're in the wrong directory. The
harness is exercised by:

1. Copying `.claude/agents/`, `scripts/`, and (optionally) `.claude/context/coding-rules.md`
   into a target Playwright project.
2. Triggering the `add-test` agent there.

If a change requires end-to-end validation, do it in a real target project,
not here.

### 5. When you change the pipeline

- Update the table in `add-test.md` (orchestration steps + agent
  responsibilities).
- Update the architecture diagram in `README.md`.
- Update the agent contract table in this file (CLAUDE.md).
- Keep artifact filenames consistent: `tc_{case_id}_{stage}.md`.

### 6. Don't treat `.claude/context/coding-rules.md` as a strong constraint

That file is a **reference template** for target projects to copy and adapt. It
is not loaded by any agent in this repo. Editing it changes what target
projects start from, but it doesn't affect the harness's behavior unless a
target project actually pulls it in.

## What "done" looks like for a harness change

A harness change is done when:

1. No agent file references absolute paths to a specific application repo.
2. No agent file references specific business concepts (cases, connectors,
   admin roles named after a real app).
3. The agent contract table above still matches what each agent does.
4. The orchestrator's pipeline table in `add-test.md` still matches reality.

Manual end-to-end validation in a real target project is recommended before
shipping a major change.
