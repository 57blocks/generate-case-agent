# Playwright Test Harness

[![English](https://img.shields.io/badge/Language-English-blue)](./README.md)
[![简体中文](https://img.shields.io/badge/%E8%AF%AD%E8%A8%80-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-red)](./README.zh-CN.md)

> Generate a runnable Playwright test from a single test-case screenshot and a short trigger phrase.

This repository provides a Claude Code-based agent harness for Playwright projects. After you
install it into your Playwright codebase, you can provide either a screenshot of a test case
(from a CSV, spreadsheet, or document) or a natural-language description, and the harness will
run the full pipeline automatically:

**requirement breakdown → architecture design → MCP validation → code generation → automated debugging → knowledge capture**

The end result is a passing test in your repository context, plus reusable lessons captured for
future test generation.

---

## Quick Start

```bash
# 1. Copy the harness into the root of your Playwright project
git clone <this-repo> /tmp/playwright-test-harness
cp -r /tmp/playwright-test-harness/.claude/agents .claude/
cp -r /tmp/playwright-test-harness/.claude/skills .claude/
cp -r /tmp/playwright-test-harness/scripts .
chmod +x scripts/*.sh

# 2. Run preflight to verify that your project has the infrastructure this harness requires
bash scripts/preflight.sh
```

`preflight` scans your project and reports, item by item, what already exists, what is missing,
and what is optional but recommended because its absence would reduce generation quality.
**Fix the ❌ errors first, then decide whether to address the ⚠️ warnings.**
For details on what each missing item affects and how to provide it, see
["Placeholders and project contract"](#placeholders-and-project-contract-where-agents-read-from-in-your-project).

```bash
# 3. After preflight passes, trigger the harness in a Claude Code conversation
#    Drop in a test-case screenshot and add a trigger phrase, for example:
#       增加 SA-001 用例
#       add test for TC-050
#       更新 TC-050 用例
```

The orchestrator agent will run the pipeline automatically. On failure, it will retry and repair
issues iteratively, up to 5 times.

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

Writing Playwright tests by hand is repetitive: parse the test case → find or write a Page
Object → validate selectors against the real UI → write the spec → debug inevitable timing
issues. This harness assigns each step to a specialized agent and connects them using a
lightweight file protocol, so you can:

- Turn one screenshot into a runnable test.
- Let the agents **debug failures iteratively on their own** — including selector drift,
  spinner waits, virtual-scrolling quirks, and similar issues.
- Automatically write lessons learned from the current run back into your project's
  `CLAUDE.md`, so later test generation benefits from previous work.

---

## Architecture

The harness consists of 6 agents in total: 1 orchestrator and 5 pipeline stages. Each stage
writes its artifact to `/tmp/tc_{case_id}_{stage}.md`; the next stage **reads only that file**,
not the previous stage's chat output. This keeps each agent's context clean and narrowly scoped.

```
[1] test-analyst     →  /tmp/tc_{id}_requirement.md
[2] test-architect   →  /tmp/tc_{id}_design.md         (validates selectors with MCP Playwright)
[3] test-coder       →  writes spec + Page Object files
[4] test-runner      →  /tmp/tc_{id}_run_report.md     (iterates on failure; may return to step 1 / 2)
[5] test-summarizer  →  updates lessons back into your repo's CLAUDE.md / agent / memory
```

| Agent | Responsibility | Model |
|---|---|---|
| `add-test` | Orchestrator — routes between stages and guards artifacts | sonnet |
| `test-analyst` | Reads screenshots, clarifies requirements when needed, and breaks test cases into atomic units | sonnet |
| `test-architect` | Chooses Page Objects and validates new selectors with MCP | sonnet |
| `test-coder` | Writes code only; does not open browsers or invent selectors | haiku |
| `test-runner` | Runs tests, classifies failures from stack traces, repairs what it can, or escalates | haiku |
| `test-summarizer` | Audits successful runs and updates the project knowledge base | sonnet |

---

## Usage

### Trigger phrases

The orchestrator (`add-test` agent) recognizes multiple natural trigger phrases in both Chinese
and English:

| Phrase | Action |
|---|---|
| 增加 SA-001 用例 | Add a new test, ID = SA-001 |
| add test for TC-050 | Add a new test, ID = TC-050 |
| 更新 TC-050 用例 | Update an existing test |
| update test TC-050 | Update an existing test |
| 在 supioadmin 文件夹下增加用例 | Add a new test under a target directory |
| add a new test file | Add a new test (no specific case ID yet) |

Drop a test-case screenshot into the conversation (CSV / spreadsheet / document formats are all
fine as long as the content is readable), plus one trigger phrase. The orchestrator will run the
pipeline through to completion. If the screenshot does not clearly specify the role,
environment, or test data, the analyst will ask follow-up questions.

### What you'll see

- **Clarifying questions** from the analyst, when needed
- **Breaking-change warnings** from the architect, when newly proposed methods conflict with
  existing code
- **Iteration updates** from the runner (for example: `Iteration 2: fix selector issue…`)
- A final **session summary** describing what was implemented, what was reused, and what was
  written back into `CLAUDE.md`

### Automatic iteration

When a test fails, `test-runner` reads the stack trace, classifies the failure, and then:

- fixes timing, assertion, or page-context issues directly, or
- escalates to `test-architect` for selector errors (only architect has MCP to re-validate) or design issues — architect will further escalate to `test-analyst` if the root cause is a requirement misunderstanding

It will iterate up to 5 times before stopping and reporting back.

---

## Where project knowledge should live

The harness separates project knowledge into five categories, each with its own place. **Do not
mix them together.**

| Category | Example | Where it should live |
|---|---|---|
| **A. Generic Playwright / MCP rules** | "Don't gate clicks on `isVisible()`"; MCP validation workflow | The harness's `.claude/context/coding-rules.md` template (copied by users into their own project) |
| **B. Project-specific coding style** | "Files tab assertions omit file extensions"; "wait for `.ant-spin-spinning` to disappear" | The **target project's own** `CLAUDE.md` and/or `.claude/context/coding-rules.md` |
| **C. Reusable operation skills** | Business flows ("log in + create + verify") or recurring technical patterns ("login as role X", "wait for AI processing") that multiple tests invoke | The **target project's own** `.claude/skills/*.md` (the harness ships only one example) |
| **D. Project-level facts** | Feature flags that are on, stable test data IDs, env constraints | The **target project's** `.claude/context/project-facts.md` — written by summarizer, shared via git so the whole team benefits |
| **E. Real runnable code examples** | A passing spec and its Page Object | Your project's existing `tests/` and `pages/` — the architect will grep and reference them |

> This harness repository ships only **A** (template) and **C** (one example). **B** and **D**
> belong entirely to your own project, and **E** should be read directly from your codebase.

### The role of Skills (Category C)

A skill is a **reusable operation template** that multiple tests invoke. It can be:

- A **business flow**: multi-step sequences tied to your app's domain (create a case, submit a form, publish a timeline).
- A **technical pattern**: recurring infrastructure steps that are project-specific but not business-specific (login as a given role, wait for AI processing to finish, upload via a connector).

`example-flow.md` is a template showing what a skill should look like. Before designing a new
test, `test-architect` scans the target project's `.claude/skills/` directory and, when keywords
match, prefers code templates from those files rather than reinventing the flow.

To see how to write a skill, read
[`.claude/skills/example-flow.md`](.claude/skills/example-flow.md).

---

## Placeholders and project contract (where agents read from in your project)

Open `.claude/agents/test-coder.md` and you will see many placeholders like
`<project-fixtures-import>`, `{ROLE}`, and `{fixture1}`. **These are not meant to be replaced
manually** — they are templates for the LLM agent. At runtime, the agent scans your project for
the corresponding reference material and fills them in automatically.

That only works if **those reference artifacts actually exist in your project**. That is exactly
what `preflight` checks. The table below explains where each placeholder or configuration value
comes from, so you can fill in missing pieces systematically:

| Placeholder / Config | How the agent fills it | What your project should provide | What happens if missing |
|---|---|---|---|
| `<project-fixtures-import>` | Reads import paths from your existing specs | At least one runnable `*.spec.ts` | coder won't know how to import |
| `<project-constants-import>` | Same as above | Same as above | Same as above |
| `RoleName.{ROLE}` | Reads enums from `utils/constants.ts` (or similar) | A role-enum file in the project | analyst will keep asking what role to use |
| `{fixture1}, {fixture2}` | Reads exported fixture names from `fixtures.ts` | A fixtures file, with Page Objects injected through it | generated tests may directly `new XxxPage(...)` |
| `{module}` (new spec file location) | Globs your project's existing `tests/**` structure | At least one or two already-organized test directories | new files may land in the wrong place |
| `{snake_feature_name}` | Derived automatically from the case description | Nothing | - |
| `{CASE_ID}`, `{CASE_NAME}` | Extracted from your screenshot / prompt | Nothing | - |
| `<target-app-url>` (for architect MCP) | Taken from ROLE_CONFIG / env vars / a URL you provide | Project URL config, or a URL directly given to architect | architect can't validate selectors against the real UI |
| `MENU.{X}`, `gotoMenu(...)` style navigation | Reads navigation helpers from your BasePage / shared helpers | Preferably a BasePage and named navigation helpers | generated tests may use inconsistent navigation |
| Project coding style (assertions, loading waits) | Reads `.claude/context/coding-rules.md` + `CLAUDE.md` | At least one of those docs, with clear conventions | architect falls back to generic rules |

### Minimum project setup

Read the `preflight` results in two severity levels:

**❌ Errors (must fix)**
- `playwright.config.ts` exists — otherwise the harness cannot run
- `scripts/*.sh` are copied in and executable — otherwise runner / typecheck / lint all fail

**⚠️ Warnings (strongly recommended)**
- `playwright.test-only.config.ts` — without it, the runner executes full `globalSetup` on every
  iteration, which is an order of magnitude slower
- A fixtures file — otherwise generated code style will differ from the rest of your tests
- A role enum (`utils/constants.ts` or similar) — otherwise you must manually tell the analyst
  what role to use every time
- A Page Object directory — otherwise new methods may end up in odd places
- `CLAUDE.md` — without it, the architect lacks project context and accuracy drops noticeably
- `.claude/context/coding-rules.md` — without it, the architect falls back to generic Playwright rules, so
  component-library-specific wait / selector patterns will be wrong
- MCP Playwright server — without it, the architect can only guess selectors, and the runner
  will repeatedly iterate on selector failures

### What if my project has none of these?

You can handle that in two steps:

1. **First run** — fix the ❌ items first, then trigger one run. Let the architect create the
   initial fixtures, role enums, and Page Object skeletons. The generated code becomes the
   "seed reference" for future tests.
2. **Later runs** — by then `preflight` should be fully green. As you generate more tests, the
   agents will have "neighbors" to learn from, so style consistency improves significantly.

---

## What the target project needs

Required:

- A working Playwright setup (`@playwright/test` + one config file)
- A `playwright.test-only.config.ts` that can run a single named test without running global
  setup/teardown — `scripts/test-quick.sh` depends on it

Strongly recommended:

- A `CLAUDE.md` in the project root describing your coding conventions
- A `.claude/context/coding-rules.md` (start from the harness version — see
  [`.claude/context/coding-rules.md`](.claude/context/coding-rules.md))
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
capabilities: sub-agent orchestration, MCP Playwright tools, and routing between stages using
the `Agent` tool.

| IDE | Status | Notes |
|---|---|---|
| Claude Code | ✅ Native support | Full pipeline, automatic failure iteration, MCP selector validation |
| Cursor | ⚠️ Adaptable | Cursor 2.4+ (GA Jan 2026) has true sub-agent isolation via `.cursor/agents/*.md`; automatic failure routing is not natively supported |
| GitHub Copilot | ⚠️ Adaptable | Now supports MCP (GA July 2025) and agent mode, but the markdown-artifact pipeline architecture needs a full rewrite to adapt |

### Adapting to Cursor

As of Cursor 2.4 (January 2026, GA), Cursor has genuine sub-agent support via
`.cursor/agents/*.md` files — each sub-agent runs in its **own isolated context window**,
which is the correct migration target for this harness.

> **Important**: Do **not** use `.cursor/rules/*.mdc` for agent definitions — those are prompt
> injections into a shared context, not isolated sub-agents.

A rough migration path:

1. Define each pipeline stage as a `.cursor/agents/*.md` file with YAML frontmatter (`name`,
   `description`, `model`, `readonly`, `is_background`) followed by the agent's prompt body.
   Each sub-agent has an isolated context window and only receives what the orchestrator passes
   explicitly — it does not see the full conversation history.
2. Configure MCP Playwright in **project-level** `.cursor/mcp.json` (the global
   `~/.cursor/mcp.json` has known reliability issues and may be silently ignored).
3. The orchestrator can automatically delegate to sub-agents via LLM-driven intent matching —
   no manual trigger required for delegation itself. The `/tmp/tc_*.md` artifact protocol is
   physically workable, but you must instruct each agent explicitly in its prompt to write to
   and read from the correct artifact path.
4. **Automatic failure routing is not natively supported.** If `runner` fails and needs to
   escalate to `architect`, this must be a human decision. There is no built-in mechanism for a
   failed sub-agent to automatically re-invoke an earlier stage.

What you lose compared to Claude Code: deterministic pipeline routing, automatic failure
iteration, and reliable per-stage model switching (a known Cursor 2.4 bug causes sub-agents to
inherit the parent model rather than using their designated model).

### Adapting to Copilot

As of 2026, GitHub Copilot supports named agents via `.github/agents/*.agent.md` files (VS Code
and Visual Studio 2026+), MCP (including Playwright MCP), and shared filesystem access. A
migration is technically feasible, but the harness's automatic orchestration pattern is not
natively supported.

A rough migration path:

1. Define each pipeline stage as a `.github/agents/*.agent.md` file with YAML frontmatter
   (`name`, `description`, `model`, `tools`, `mcp-servers`) followed by the agent's prompt body.
2. Configure MCP Playwright in your workspace. The `/tmp/tc_*.md` artifact protocol is physically
   workable — the shared filesystem allows agents to read and write files — but you must instruct
   each agent explicitly in its prompt to write output to the correct artifact path.
3. Use the `handoffs` frontmatter property to create guided stage transitions. Note that handoffs
   require a **human click** in the UI — there is no mechanism for the orchestrator to
   autonomously spawn the next agent without user interaction.
4. Failure routing (e.g., runner escalating back to architect) is not automatic. You must
   manually decide which stage to re-invoke on failure.

What you lose compared to Claude Code: automatic stage routing, automatic failure iteration,
guaranteed per-stage context isolation, and per-stage model switching.

---

## Customization

- **Model strategy** — edit the table at the top of `.claude/agents/add-test.md` to change
  which stages use Sonnet vs. Haiku. This is the quality / cost tradeoff.
- **Iteration cap** — `test-runner` defaults to 5 iterations max. Change Step 4 in
  `add-test.md`.
- **Coding style** — the agent reads the target project's `.claude/context/coding-rules.md`. Write rules
  there (or in your project's `CLAUDE.md`) to teach the harness your conventions.
- **Directory structure** — the architect discovers `tests/**`, `pages/**`, `e2e/**`, etc. via
  globbing. No hardcoded paths need to be changed.

---

## Known limitations

- **Linux / macOS only** — artifacts use `/tmp/`. Windows users must modify the paths inside
  each agent.
- **TypeScript Playwright only** — the default output is `*.spec.ts` + `.ts` Page Objects +
  `expect()` assertions. JavaScript projects can still use it, but generated code will be in TS
  syntax.
- **Selector validation depends on MCP** — without an MCP Playwright server, the architect can
  only infer selectors from existing code, and accuracy drops noticeably.

---

## Repository files

```text
.claude/agents/              6 agents (orchestrator + 5 pipeline stages)
.claude/skills/              Skill templates (reusable operation templates — business flows or technical patterns)
.claude/context/coding-rules.md         Reference coding-rules template (for target projects to copy and adapt)
.claude/context/project-facts.md        (written by summarizer at runtime) Project-level facts shared across the team
scripts/preflight.sh         Run once after installation to check project readiness for the harness
scripts/test-quick.sh        Used by runner: runs a single test without global setup
scripts/typecheck.sh         Used by coder: `tsc --noEmit` gate
scripts/lint-patterns.sh     Used by coder: forbidden-pattern scan
scripts/cleanup-artifacts.sh Cleans up /tmp/tc_*.md after a session
CLAUDE.md                    Instructions for Claude when modifying the *harness itself*
README.md                    English README
README.zh-CN.md              Simplified Chinese translation
```
