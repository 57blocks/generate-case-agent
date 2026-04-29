# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Full code examples and detailed explanations live in [docs/coding-rules.md](docs/coding-rules.md).

## Project Overview

Playwright-based UI automation framework for a legal case management portal. Supports multi-role testing across Firm Admin, Supio Admin, and various law firm roles with visual regression testing and database validation.

## Common Development Commands

```bash
# Run all tests
npm test

# Run specific project (auto-selects environment)
npx playwright test --project=main      # staging
npx playwright test --project=democase  # production
npx playwright test --project=ca        # CA environment

# Fast single-test development (no setup dependencies)
npx playwright test [file.spec.ts] --config=playwright.test-only.config.ts --grep "[test-name]"

# Override environment
TEST_ENV=prod npx playwright test --project=main

# Debug
npm run debug:stg
npm run debug:prod

# Verify environment config
npm run verify-env
```

| Project      | Default Env | CI           |
|--------------|-------------|--------------|
| `main`       | Staging     | Daily        |
| `democase`   | Production  | Daily        |
| `connectors` | Production  | Daily        |
| `poc`        | Production  | Separate     |
| `ca`         | CA          | Manual only  |

See [docs/PROJECT_ENVIRONMENT_MAPPING.md](docs/PROJECT_ENVIRONMENT_MAPPING.md) for full details.

## Architecture Overview

- **BasePage** (`pages/base.ts`) — common UI interactions, GraphQL, screenshots, file upload
- **`pages/firmadmin/`** — law firm administrator pages
- **`pages/supioadmin/`** — platform administrator pages
- **`fixtures.ts`** — fixture definitions; all fixtures share the same `page` instance
- **`test-data/factories/case.factory.ts`** — case create/update flows
- **`utils/`** — auth, database, constants, env-loader

Tests are organised by role: `tests/firmadmin/`, `tests/supioadmin/`, `tests/workflow/`.

## Key Development Patterns

### Creating New Tests

1. Use fixture injection: `async ({ casesPage, timelinePage }) => { ... }`
2. Set login role: `test.use({ loginRole: RoleName.OPS2_ADMIN })`
3. Follow naming: `feature_operation_test.spec.ts`
4. Every CSV step must have test code; every expected result must have an assertion

### TimelinePage.load() Already Lands on the Chrono Tab

`timelinePage.load(caseId)` navigates to `?t=timeline` — the Chrono tab. Calling `gotoMenu(MENU.Chrono)` immediately after is redundant.

```typescript
// ❌ WRONG: redundant gotoMenu
await timelinePage.load(caseId);
await timelinePage.gotoMenu(MENU.Chrono);

// ✅ CORRECT
await timelinePage.load(caseId);
```

Only call `gotoMenu(MENU.Chrono)` when switching back to Chrono from another tab.

### Case Create / Update: Factory First Rule

**Before implementing any case create or update, always check `test-data/factories/case.factory.ts` first.**

- `caseFactory.withName(...).withCaseType(...).create()` — full creation flow (navigates to `/cases` automatically)
- `caseFactory.withExistingCase(name).withCaseType(...).update()` — full update flow (does **not** navigate; works from any case page)
- Never reimplement create/update logic in a page object

```typescript
// ✅ CORRECT
await casesPage.caseFactory.withExistingCase(caseName).withCaseType("MVA").update();

// ❌ WRONG: reimplementing factory logic
async updateCaseType(caseType: string) {
  await this.page.getByRole("button", { name: "file-add Update case" }).click();
  // ... duplicating factory logic
}
```

`update()` does not call `casesPage.load()` — the "Update case" button exists on any case page (timeline, chrono, flowsheets). The caller controls the current page context.

### CaseOptions: Add Only What Is Needed

Default is no options. Add `checkDocumentProcessing: true` only when downstream steps require completed AI processing.

```typescript
// ✅ CORRECT: default
await casesPage.caseFactory.withName("test").create();

// ✅ CORRECT: AI pipeline needed
await casesPage.caseFactory.withName("test").create({ checkDocumentProcessing: true });

// ❌ WRONG: speculative flags
await casesPage.caseFactory.withName("test").create({ checkFileStatus: false });
```

---

## 🚨 Critical Coding Rules

### Element Interaction

| Rule | Wrong | Right |
|------|-------|-------|
| Never use `isVisible()` to gate an interaction | `if (await btn.isVisible()) await btn.click()` | `await btn.click()` |
| Never use element-level timeouts | `await expect(el).toBeVisible({ timeout: 3000 })` | `await expect(el).toBeVisible()` |
| Never use `test.skip()` for missing elements | `if (!found) test.skip()` | Let the test fail with a clear error |

`isVisible()` is acceptable only for legitimate conditional logic where the element may legitimately not exist (e.g. checking if a drawer is already open).

### Selectors

- **No `data-testid`**: anchor on visible text, traverse up with `..`, find sibling button
- **Split-view top-right ellipsis**: always `.last()` — there is no wrapping testid
- **Actions behind caret**: click the `"down"` button first, then click the `menuitem`
- **Ant Design icons**: use `data-icon` attribute — `button:has([data-icon="info-circle"])`, not button name
- **Banner buttons**: scope to container class (`.ant-flex-gap-small`), use `getByRole("button", { name })`
- **Popover items** (e.g. Last Sync panel): use `button` role, not `menuitem`

### Virtual Scroll Tables

- Infer row type from `textContent()`, not child `isVisible()` (off-screen rows have no DOM children)
- Re-query the locator after each DOM mutation (expansion, collapse)
- Scroll the virtual holder into view before asserting off-screen rows
- Only use `evaluate(el => el.scrollTop +=)` inside dialogs/modals — never on top-level SPA containers (triggers URL navigation)

### Assertions

- **Toasts auto-dismiss** (1–3 s) — assert on the persistent UI state that follows, not the toast
- **`not.toBeVisible()` on multi-match locators** — always add `.first()` to avoid strict-mode violations
- **Checkbox/toggle** — check current state with `isChecked()` before clicking to avoid inverting pre-selected state
- **Files tab** — filenames display without extensions; match the bare name

### Loading States

- Wait for `.ant-spin-spinning` to detach before interacting with Ant Design components
- Wait for the generic spinner, not just feature-specific loading text

### Timeouts

- `test.setTimeout` only for AI processing or known slow connector APIs (SmartAdvocate: 300 s)
- Never increase timeout speculatively — reproduce with MCP first to confirm the cause

---

## MCP-Driven Test Development

**Always use MCP browser tools before writing selectors or interaction code.**

### Required workflow

1. `browser_navigate` → access the test page
2. `browser_snapshot` → understand page structure
3. `browser_click` / `browser_evaluate` → verify interactions work
4. `browser_close` → **mandatory** before running Playwright tests
5. Write test code only after MCP confirms all elements and interactions work

### Post-action verification rule

MCP validation must cover the **full action cycle**, not just element discovery. After performing an action (submitting a dialog, clicking a button), always observe the resulting page state:

1. Execute the action in MCP
2. Wait for completion signals (toast disappears, dialog closes)
3. Observe whether the target area updates automatically

Only add `page.reload()` if you observe the page does **not** auto-refresh. Never infer reload behaviour from code — the application's reactive update behaviour varies.

### Session management

`browser_close()` is mandatory after every MCP session. Leaving a session open causes "Browser is already in use" errors when running Playwright tests.

---

## Debugging

- **Pre-test structure**: use MCP (`browser_snapshot`, `browser_evaluate`)
- **Runtime debugging**: add temporary `console.log`, grep the test output — do not open MCP while a Playwright test may run
- **Stack traces**: always read the full trace — `grep -E "(Error:|at pages/|at tests/|at factories/)"` to find the exact failing layer
- **Failing phase**: identify which layer (factory, page object, test) before making any fix

---

## Environment Configuration

```
.env.stg    # Staging (default)
.env.prod   # Production
.env.ca     # CA
```

Control with `TEST_ENV`. Never hardcode URLs — use `ROLE_CONFIG` from `utils/constants.ts`.
See [docs/ENVIRONMENT_CONFIGURATION.md](docs/ENVIRONMENT_CONFIGURATION.md).

---

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Auth failures | Check env vars; verify global-setup completed |
| Screenshot mismatches | `--update-snapshots` |
| Test timeout | Reproduce with MCP to find the stuck step |
| Element not found | Validate selector in MCP first |
| Strict mode violation | MCP `evaluate` to count elements; add `.first()` |
| "Target page closed" | Check for SPA `scrollTop` on top-level containers; check for race between fixtures |
| "Element intercepts pointer events" | Wait for `.ant-spin-spinning` to detach |

Reports: `./playwright-report/index.html` · `./allure-results/`
