# Example Flow Skill — Reference Template

> **This file is a template, not a working skill.** It exists to show you what a
> skill looks like in this harness. Copy it into your target project's
> `.claude/skills/` directory, rename it, and adapt the code to your domain.
> The harness's `test-architect` agent will read matching skill files in the
> target project before designing a test, and use them as the canonical
> templates for that operation.
>
> **What belongs in a skill:**
>
> A skill is a **reusable operation template** that multiple tests invoke. It can be:
>
> - A **business flow**: multi-step sequences tied to your app's domain
>   (create a case, submit a form, publish a timeline).
> - A **technical pattern**: recurring infrastructure steps that aren't
>   business-specific but are project-specific (login as a given role,
>   wait for AI processing to finish, upload via a connector).
>
> In all cases a skill should have:
> 1. A real, runnable code template that the coder can follow verbatim.
> 2. The naming conventions and parameter names the operation uses, so
>    generated tests stay consistent.
> 3. Pointers to the page-object methods that implement each step.
>
> **What does NOT belong in a skill:**
>
> - Generic Playwright rules (those go in `.claude/context/coding-rules.md`).
> - One-off patterns that only one test uses.
> - Project-wide naming conventions or coding style (those go in `CLAUDE.md`).
> - Project-level facts like feature flags or test data IDs (those go in `.claude/context/project-facts.md`).

---

# Login-And-Create-Record Skill (illustrative example)

A worked example of a typical "login → create a resource → verify it exists"
flow. Replace this with your project's real business flow when you adapt the
template.

## When to use

Invoke this skill when a test case requires:
- A signed-in user (any role)
- Creating a new record (case, project, account, document — whatever your app
  calls it)
- Verifying the record appears in the list view afterwards

## How to use

The architect agent should reference this skill in its Design Plan whenever
the spec mentions creating a new record. The coder agent will then follow the
code template below verbatim, substituting only the values that the spec calls
out (record name, role, optional metadata).

### Step 1: Parse intent

Look for keywords in the spec:

| Spec mentions | Implication |
|---|---|
| "as Admin" / "as User" | Pick the matching `RoleName.*` entry |
| "with file X" / "attach Y" | Add an upload step after creation |
| "in folder Z" / "under category Z" | Add a category-selection step |

### Step 2: Code template

```typescript
import { test, expect } from "<project-fixtures-import>";
import { RoleName } from "<project-constants-import>";

test.use({ loginRole: RoleName.{ROLE} });

test("{TEST_DESCRIPTION}", async ({ recordsPage }) => {
  // Step 1: navigate and create
  const recordName = `auto_${Date.now()}_example`;
  await recordsPage.load();
  await recordsPage.createRecord({
    name: recordName,
    // optional fields the architect adds based on spec keywords
    // category: "...",
    // attachments: [...],
  });

  // Step 2: verify the record appears
  await expect(recordsPage.rowByName(recordName)).toBeVisible();
});
```

### Step 3: Page-object expectations

This skill assumes the target project has a `recordsPage` page object with at
least these methods. If they don't exist yet, the architect should design them
in `design.md` and the coder should add them.

| Method | Purpose |
|---|---|
| `recordsPage.load()` | Navigate to the records list view |
| `recordsPage.createRecord({...})` | Open the create dialog, fill the form, submit, wait for completion |
| `recordsPage.rowByName(name)` | Locator for a row matching the given name |

### Step 4: Naming conventions

- Generated record names use the prefix `auto_` + timestamp so they're
  recognizable in the test database and easy to clean up.
- Test descriptions should include the case ID prefix when one is given:
  `"TC-050: create a record as admin"`.

---

## Adapting this template to your project

When you copy this file into your target project, update:

1. **The skill name** at the top — match the file name and the natural-language
   description of the flow.
2. **The "When to use" trigger phrases** — the architect uses these to decide
   whether your skill applies to the current spec.
3. **The code template** — replace the imaginary `recordsPage` with your real
   page object, the imaginary `createRecord` parameters with your real ones,
   and the imaginary verification step with your real success check.
4. **The page-object expectations table** — list the methods this flow relies
   on so the architect knows what to reuse vs. create.
5. **Any project-specific defaults** — if a particular role or category is
   used 90% of the time, list it as the default so the spec doesn't have to
   spell it out.

## Where skills live

| Location | Loaded by | Purpose |
|---|---|---|
| **This repo** (`.claude/skills/example-flow.md`) | Nothing. It's a template. | Reference for users adapting the harness. |
| **Target project** (`.claude/skills/<your-flow>.md`) | `test-architect` | Canonical code templates for your project's recurring business flows. |
