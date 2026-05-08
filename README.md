# Playwright Test Harness

[简体中文说明 / Simplified Chinese](./README.zh-CN.md)

> One test case screenshot + one short keyword, automatically generates a runnable Playwright test.

A Claude Code-based agent harness. Install it into your Playwright project, drop in a
screenshot of a test case from a CSV / spreadsheet / document (or just provide a natural-
language description), and it will automatically complete the full pipeline of
**requirement breakdown → architecture design → MCP validation → code generation →
automated debugging → knowledge capture**, ultimately producing a passing test in your
repository.

---

## Quick Start

```bash
# 1. Copy the harness into the root of your Playwright project
git clone <this-repo> /tmp/playwright-test-harness
cp -r /tmp/playwright-test-harness/.claude/agents .claude/
cp -r /tmp/playwright-test-harness/.claude/skills .claude/
cp -r /tmp/playwright-test-harness/scripts .
chmod +x scripts/*.sh

# 2. Run preflight to check whether your project has the infrastructure this harness needs
bash scripts/preflight.sh
```

preflight scans your project and reports, item by item, what already exists, what is
missing, and what is optional but would reduce generation quality if absent. **Fix the ❌
errors first, then decide whether to address the ⚠️ warnings.**
For what each missing item affects and how to add it, see
["Placeholders and project contract"](#placeholders-and-project-contract-where-agents-read-from-in-your-project).

```bash
# 3. After preflight passes, trigger the harness in a Claude Code conversation
#    Drop in a test case screenshot and add a trigger phrase, for example:
#       增加 SA-001 用例
#       add test for TC-050
#       更新 TC-050 用例
```

The orchestrator agent will automatically run the pipeline. If it fails, it will iterate and
repair by itself up to 5 times.

---

```
"增加 SA-001 用例"                       analyst
        +              ─────────►   ┌────────►─────────► architect
   one screenshot                     │                       │
                                      │                       ▼
                                      │                    coder
                                      │                       │
                                      │       ┌────────────── ▼
                                      │       │           runner ◄──┐
                                      │       │             │       │
                                      │       │ on failure  │       │ auto-iterate
                                      └◄──────┴─────────────┤       │
                                                            ▼       │
                                                     summarizer ◄───┘
                                                            │
                                                            ▼
                                                one passing test in your repo
                                                + lessons written back into CLAUDE.md
```

---

## Why this exists

Writing Playwright tests by hand is repetitive work: parse the test case → find or write a
Page Object → validate selectors against the real UI → write the spec → debug the
inevitable timing problems. This harness assigns each step to a specialized agent and then
connects them through a lightweight file protocol, so you can:

- Drop in one screenshot and get back a runnable test.
- Let the agent **iteratively debug failures on its own** — selector drift, spinner waits,
  virtual scrolling quirks, and more.
- Automatically write the lessons learned from this run back into your project's
  `CLAUDE.md`, so the next test can benefit from them.

---

## Architecture

There are 6 agents total: 1 orchestrator + 5 pipeline stages. Each pipeline stage writes its
artifact to `/tmp/tc_{case_id}_{stage}.md`; the next stage **reads only that file**, not the
previous stage's chat output. This keeps every agent's context clean and tightly scoped.

```
[1] test-analyst     →  /tmp/tc_{id}_requirement.md
[2] test-architect   →  /tmp/tc_{id}_design.md         (validates selectors with MCP Playwright)
[3] test-coder       →  writes spec + Page Object files
[4] test-runner      →  /tmp/tc_{id}_run_report.md     (iterates on failure; may return to step 1 / 2)
[5] test-summarizer  →  updates lessons back into your repo's CLAUDE.md / agent / memory
```

| Agent             | Responsibility                                            | Model  |
|-------------------|-----------------------------------------------------------|--------|
| `add-test`        | Orchestrator — routes between stages and guards artifacts | sonnet |
| `test-analyst`    | Reads screenshots, clarifies when needed, breaks cases into atomic units | sonnet |
| `test-architect`  | Chooses Page Objects and validates new selectors with MCP | sonnet |
| `test-coder`      | Writes code only; does not open browsers or invent selectors | haiku  |
| `test-runner`     | Runs tests, classifies failures by stack trace, repairs or escalates | haiku  |
| `test-summarizer` | Audits successful runs and updates the project knowledge base | sonnet |

---

## Usage

### Trigger phrases

The orchestrator (`add-test` agent) recognizes multiple natural trigger phrases in both
Chinese and English:

| Phrase                            | Action                         |
|-----------------------------------|--------------------------------|
| 增加 SA-001 用例                  | Add a new test, ID = SA-001    |
| add test for TC-050               | Add a new test, ID = TC-050    |
| 更新 TC-050 用例                  | Update an existing test        |
| update test TC-050                | Update an existing test        |
| 在 supioadmin 文件夹下增加用例    | Add a new test under a target directory |
| add a new test file               | Add a new test (no specific case ID yet) |

Drop a test case screenshot into the conversation (CSV / spreadsheet / document is all fine
as long as it's readable), plus one trigger phrase. The orchestrator will run the pipeline
through to completion. If the screenshot does not clearly specify role / environment / test
data, the analyst will ask follow-up questions.

### What you'll see

- **Clarifying questions** from the analyst (only when needed)
- **Breaking-change warnings** from the architect (only when new methods conflict with
  existing code)
- **Iteration updates** from the runner (for example: "Iteration 2: fix selector issue…")
- A final **session summary** — what was implemented, what was reused, and what was written
  back into `CLAUDE.md`

### Automatic iteration

When a test fails, `test-runner` reads the stack trace, classifies the failure, and then:

- fixes selector / timing / assertion issues itself, or
- escalates to `test-architect` (design issue) or `test-analyst` (requirement issue)

It will iterate up to 5 times before stopping and reporting back.

---

## Where project knowledge should live

The harness separates project knowledge into 4 categories, each with its own home. **Do not
mix them together.**

| Category | Example | Where it should live |
|---|---|---|
| **A. Generic Playwright / MCP rules** | "Don't gate clicks on `isVisible()`"; MCP validation workflow | The harness's `docs/coding-rules.md` template (copied by users into their own project) |
| **B. Project-specific coding style** | "Files tab assertions omit file extensions"; "wait for `.ant-spin-spinning` to disappear" | The **target project's own** `CLAUDE.md` and/or `docs/coding-rules.md` |
| **C. Business-flow code templates** | "How to log in + create a record + verify"; "how to upload a file + wait for AI processing + publish" | The **target project's own** `.claude/skills/*.md` (the harness only ships one example) |
| **D. Real runnable code examples** | A passing spec and its Page Object | Your project's existing `tests/` and `pages/` — the architect will grep and reference them |

> The harness repo only ships **A** (template) and **C** (one example). **B** belongs entirely
> to your own project, and **D** should be read directly from your codebase rather than copied
> out separately.

### The role of Skills (Category C)

`example-flow.md` is a **template** showing what a skill should look like: when a certain
business flow is reused across multiple tests (for example, "log in → create → verify"), you
should turn that flow's **real code snippets, naming conventions, and parameter parsing** into
one skill file. Before designing a new test, `test-architect` scans the target project's
`.claude/skills/` directory and, when keywords match, prefers code templates from those skill
files instead of reinventing the flow.

To see how to write a skill, read
[`.claude/skills/example-flow.md`](.claude/skills/example-flow.md).

---

## Placeholders and project contract (where agents read from in your project)

Open `.claude/agents/test-coder.md` and you'll see many placeholders like
`<project-fixtures-import>`, `{ROLE}`, and `{fixture1}`. **These are not meant to be manually
replaced by you** — they are templates for the LLM agent. At runtime, the agent scans your
project for the corresponding reference material and fills them in automatically.

But that only works if **those reference artifacts actually exist in your project**. That is
exactly what preflight checks. The table below explains where each placeholder / configuration
value comes from, so you can patch the missing pieces systematically:

| Placeholder / Config                    | How the agent fills it                              | What your project should provide                 | What happens if missing |
|-----------------------------------------|----------------------------------------------------|--------------------------------------------------|-------------------------|
| `<project-fixtures-import>`             | Reads import paths from your existing specs         | At least one runnable `*.spec.ts`                | coder won't know how to import |
| `<project-constants-import>`            | Same as above                                       | Same as above                                    | Same as above |
| `RoleName.{ROLE}`                       | Reads enums from `utils/constants.ts` (or similar)  | A role-enum file in the project                  | analyst will keep asking what role to use |
| `{fixture1}, {fixture2}`                | Reads exported fixture names from `fixtures.ts`     | A fixtures file, with Page Objects injected through it | generated tests may directly `new XxxPage(...)` |
| `{module}` (new spec file location)     | Globs your project's existing `tests/**` structure  | At least one or two already-organized test directories | new files may land in the wrong place |
| `{snake_feature_name}`                  | Derived automatically from the case description     | Nothing                                          | - |
| `{CASE_ID}`, `{CASE_NAME}`              | Extracted from your screenshot / prompt             | Nothing                                          | - |
| `<target-app-url>` (for architect MCP)  | Taken from ROLE_CONFIG / env vars / a URL you provide | Project URL config, or a URL directly given to architect | architect can't validate selectors against the real UI |
| `MENU.{X}`, `gotoMenu(...)` style navigation | Reads navigation helpers from your BasePage / shared helpers | Preferably a BasePage and named navigation helpers | generated tests may use inconsistent navigation |
| Project coding style (assertions, loading waits) | Reads `docs/coding-rules.md` + `CLAUDE.md` | At least one of those docs, with clear conventions | architect falls back to generic rules |

### Minimum project setup

Read the preflight results in two severity levels:

**❌ Errors (must fix)**
- `playwright.config.ts` exists — otherwise the harness cannot run
- `scripts/*.sh` are copied in and executable — otherwise runner / typecheck / lint all fail

**⚠️ Warnings (strongly recommended)**
- `playwright.test-only.config.ts` — without it, the runner executes full globalSetup on every
  iteration, which is an order of magnitude slower
- A fixtures file — otherwise generated code style will differ from the rest of your tests
- A role enum (`utils/constants.ts` or similar) — otherwise you must manually tell the analyst
  what role to use every time
- A Page Object directory — otherwise new methods may end up in odd places
- `CLAUDE.md` — without it, the architect lacks project context and accuracy drops noticeably
- `docs/coding-rules.md` — without it, the architect falls back to generic Playwright rules,
  so component-library-specific wait / selector patterns will be wrong
- MCP Playwright server — without it, the architect can only guess selectors, and the runner
  will repeatedly iterate on selector failures

### What if my project has none of these?

You can do it in two steps:

1. **First run** — fix the ❌ items first, then trigger one run. Let the architect create the
   initial fixtures, role enums, and Page Object skeletons. The generated code becomes the
   "seed reference" for later tests.
2. **Later runs** — by then preflight should be fully green. When you generate more tests,
   the agents will have "neighbors" to learn from, so style consistency improves a lot.

---

## What the target project needs

Required:

- A working Playwright setup (`@playwright/test` + one config file)
- A `playwright.test-only.config.ts` that can run a single named test without running global
  setup/teardown — `scripts/test-quick.sh` depends on it

Strongly recommended:

- A `CLAUDE.md` in the project root describing your coding conventions
- A `docs/coding-rules.md` (start from the harness version — see
  [`docs/coding-rules.md`](docs/coding-rules.md))
- Page Objects placed somewhere globbable (`pages/**`, `tests/pageObjects/**`, etc.)
- Playwright fixtures that inject your Page Objects so generated tests can use destructuring:
  `async ({ pageA, pageB }) => { … }`

Optional but very useful:

- An MCP Playwright server attached in your Claude Code session — the architect uses it to
  validate selectors against the real UI before writing them. See the
  [Anthropic MCP docs](https://modelcontextprotocol.io) for setup.

---

## IDE compatibility

This harness is **designed for Claude Code** and depends on three Claude Code-specific
features: sub-agent orchestration, MCP Playwright tools, and routing between stages using the
`Agent` tool.

| IDE             | Status        | Notes |
|-----------------|---------------|-------|
| Claude Code     | ✅ Native support | Full pipeline, automatic failure iteration, MCP selector validation |
| Cursor          | ⚠️ Adaptable     | Rewrite each `.md` agent as `.cursor/rules/*.mdc`; trigger stages manually; lose automatic orchestration |
| GitHub Copilot  | ❌ Not practical | No sub-agents, no MCP, much lower accuracy |

### Adapting to Cursor

Cursor's Composer Agent is the closest counterpart to Claude Code in other IDEs, but it
**does not support sub-agents**. A rough migration path is:

1. Rewrite `.claude/agents/*.md` as `.cursor/rules/*.mdc`. Remove the frontmatter and keep
   the main prompt body.
2. Configure an MCP Playwright server in `~/.cursor/mcp.json` so the architect can still
   validate selectors.
3. Trigger the stages manually in Composer: `@analyst` → `@architect` → `@coder` → `@runner`.
   You lose **automatic failure iteration**, so you need to rerun `@runner` yourself (or go
   back to `@architect` for design issues).
4. Keep the `/tmp/tc_*.md` artifact protocol — any IDE that can access the filesystem can use
   it.

What you lose: automatic stage routing, automatic failure iteration, and per-stage model
switching (Claude Code's `model: haiku` / `model: sonnet`).

### Adapting to Copilot

Not recommended. Copilot Chat has no concept of sub-agents, and Copilot Workspace does not
support MCP. The accuracy of this pipeline depends heavily on **real-time MCP selector
validation** — without it, the architect can only guess selectors from class names, and the
runner can get stuck in loops of selector failures with no real fix.

If you absolutely must try it: merge the prompts from all 5 stages into one very long prompt
for Copilot Agent and accept a clear drop in accuracy.

---

## Customization

- **Model strategy** — edit the table at the top of `.claude/agents/add-test.md` to change
  which stages use Sonnet vs Haiku. This is the quality / cost tradeoff.
- **Iteration cap** — `test-runner` defaults to 5 iterations max. Change Step 4 in
  `add-test.md`.
- **Coding style** — the agent reads the target project's `docs/coding-rules.md`. Write rules
  there (or in your project's `CLAUDE.md`) to teach the harness your conventions.
- **Directory structure** — the architect discovers `tests/**`, `pages/**`, `e2e/**`, etc.
  via globbing. No hardcoded paths need to be changed.

---

## Known limitations

- **Linux / macOS only** — artifacts use `/tmp/`. Windows users must modify the paths inside
  each agent.
- **TypeScript Playwright only** — the default output is `*.spec.ts` + `.ts` Page Objects +
  `expect()` assertions. JavaScript projects can still use it, but generated code will be in
  TS syntax.
- **Selector validation depends on MCP** — without an MCP Playwright server, the architect can
  only infer selectors from existing code, and accuracy drops noticeably.

---

## Repository files

```
.claude/agents/        6 agents (orchestrator + 5 pipeline stages)
.claude/skills/        Skill templates (business-flow code examples)
docs/coding-rules.md   Reference coding-rules template (for target projects to copy and adapt)
scripts/preflight.sh   Run once after installation to check project readiness for the harness
scripts/test-quick.sh  Used by runner: runs a single test without global setup
scripts/typecheck.sh   Used by coder: `tsc --noEmit` gate
scripts/lint-patterns.sh Used by coder: forbidden-pattern scan
scripts/cleanup-artifacts.sh Cleans up /tmp/tc_*.md after a session
CLAUDE.md              Instructions for Claude when modifying the *harness itself*
README.md              This file
README.zh-CN.md        Simplified Chinese translation
```
