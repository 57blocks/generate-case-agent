# Timeline Operation Skill

Generate Playwright test code for timeline generation and/or publishing on an existing annotated case,
and write it to `tests/generated/timeline_temp.spec.ts`.

## How to Use

Invoke with a case name and desired target state. Examples:
- `/timeline-operation deqtest_auto_UI_1773725413367` → generate + publish timeline (full flow)
- `/timeline-operation deqtest_auto_UI_1773725413367 generate only` → generate timeline only (stop at "Pending timeline review")
- `/timeline-operation deqtest_auto_UI_1773725413367 publish only` → publish an already-generated timeline

---

## Step 1: Parse Intent from `$ARGUMENTS`

### 1a. Case Name
Extract the case name from `$ARGUMENTS`.

### 1b. Target State

| Trigger in `$ARGUMENTS` | Steps to include |
|---|---|
| No state / default | Generate timeline + publish timeline |
| "generate only" / "pending review" | Generate timeline only (ends at "Pending timeline review") |
| "publish only" | Publish only (assumes timeline already generated) |

---

## Step 2: Generate the Test Code

### Configuration constants

```
company_job_id = 3014918   // QA Test CA Company
```

### Full template (generate + publish)

```typescript
import { test, expect } from "fixtures";
import { RoleName } from "@utils/constants";

const company_job_id = 3014918;
const caseName = "[CASE_NAME]";

test.describe("Timeline operation", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.SUPIO_ADMIN });

  test("generate timeline", async ({ annotatePage }) => {
    test.setTimeout(240_000);
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.generateTimeline();
    await expect(annotatePage.viewTimelineLink()).toBeVisible();
  });

  test("publish timeline", async ({ annotatePage, timelinePage }) => {
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.gotoTimelinePage();
    await expect(timelinePage.timelineStatusTag).toHaveText(/Pending timeline review/);
    await timelinePage.completePublishTimeline();
    await expect(timelinePage.timelineStatusTag).toHaveText(/Timeline published/);
  });
});
```

### Generate only (trim "publish timeline" test)

Remove the `"publish timeline"` test entirely — end after `viewTimelineLink()` is visible.

### Publish only (trim "generate timeline" test)

Remove the `"generate timeline"` test:

```typescript
test("publish timeline", async ({ annotatePage, timelinePage }) => {
  annotatePage.setCaseName(caseName);
  await annotatePage.load(company_job_id);
  await annotatePage.gotoTimelinePage();
  await expect(timelinePage.timelineStatusTag).toHaveText(/Pending timeline review/);
  await timelinePage.completePublishTimeline();
  await expect(timelinePage.timelineStatusTag).toHaveText(/Timeline published/);
});
```

---

## Step 3: Output

Write the generated code to `tests/generated/timeline_temp.spec.ts` (create `tests/generated/` if needed) and show:

1. **Generated code** — full TypeScript code block.
2. **Notes**:
   - `company_job_id = 3014918` is for "QA Test CA Company". Update if the case belongs to a different company.
   - The annotate workflow must be complete (case in "Annotate in review" state) before running "generate timeline".

**Do not run the test.** Only write the file and output the code.
