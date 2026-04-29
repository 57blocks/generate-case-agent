# Annotate Skill

Generate Playwright test code for the annotation workflow on an existing case, and write it to
`tests/generated/annotate_temp.spec.ts`.

The annotation workflow brings a case from "In Progress" through to "Annotate in review" (ready to generate timeline).

## How to Use

Invoke with a case name and optional flags. Examples:
- `/annotate deqtest_auto_UI_1773725413367` → wait for AI auto-annotation, then complete + review
- `/annotate deqtest_auto_UI_1773725413367 files=Police Report.Pdf,bill sutter.pdf` → specify files to wait on
- `/annotate deqtest_auto_UI_1773725413367 manual` → manually annotate each file (populate records per document)

---

## `assignCaseTo` Rules

1. **`assignCaseTo` internally calls `openCaseFolder()`** — never call `openCaseFolder()` immediately after `assignCaseTo`, it will open the folder twice.
2. **Call `assignCaseTo` only once per test flow** — it assigns the annotator for the entire case. Only call it again if a new file is uploaded mid-flow (pass the `fileName` argument in that case).
3. **Role → annotator name mapping** — use the display name that matches the logged-in role:

| `loginRole` | `annotator` |
|---|---|
| `RoleName.SUPIO_ADMIN` | `"AutoTest supioadmin"` |
| `RoleName.OPS_ADMIN` | `"OPS admin"` |
| `RoleName.OPS2_ADMIN` | `"OPS Admin2"` |
| `RoleName.BULK_OP` | `"bulk OP"` |

---

## Step 1: Parse Intent from `$ARGUMENTS`

### 1a. Case Name
Extract the case name from `$ARGUMENTS`.

### 1b. Annotation Mode

| Trigger in `$ARGUMENTS` | Mode |
|---|---|
| No trigger (default) | **Auto** — wait for AI annotation then verify status, complete, review |
| "manual" | **Manual** — open each file, pre-process, add records, populate, finish |

### 1c. File Names
- If `files=<name1>,<name2>,...` is provided, use those file names.
- Default for auto mode: `"Police Report.Pdf"`, `"bill sutter.pdf"`, `"Hospital Treatment Report.Pdf"`.
- Default for manual mode: same defaults unless specified.

---

## Step 2: Generate the Test Code

### Configuration constants

```
company_job_id = 3014918   // QA Test CA Company
annotator = "AutoTest supioadmin"
```

---

### Mode A — Auto annotation (default)

Wait for AI annotation to complete for each file, then complete and review.
Pattern from `annotate_test.spec.ts`:

```typescript
import { test, expect } from "fixtures";
import { RoleName } from "@utils/constants";

const company_job_id = 3014918;
const caseName = "[CASE_NAME]";
const annotator = "AutoTest supioadmin";

test.describe("Annotate case", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.SUPIO_ADMIN });

  test("wait for AI annotation", async ({ annotatePage }) => {
    test.setTimeout(420_000);
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.assignCaseTo(annotator);
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "Police Report.Pdf");
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "bill sutter.pdf");
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "Hospital Treatment Report.Pdf");
  });

  test("complete annotation", async ({ annotatePage }) => {
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.completeAnnotate();
    await expect(annotatePage.reviewAnnotateButton()).toBeVisible();
  });

  test("review annotation", async ({ annotatePage }) => {
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.reviewAnnotate();
    await expect(annotatePage.generateTimelineButton()).toBeVisible();
  });
});
```

**Adjust per `files=` argument**: one `waitForFileAnnotationGenerated` call per file.

---

### Mode B — Manual annotation

Per-file: `waitForFileAnnotationGenerated` → `annotateSingleDoc` → `openQuestionWindow` →
`preProcessingAndSubmitType` → `deleteAllRecords` → `addAnewRecord` → `populateDocument` → `finishAnnotateTheDoc`.
Pattern from `case_econ_test.spec.ts` "generate pure bill data":

```typescript
import { test, expect } from "fixtures";
import { RoleName } from "@utils/constants";

const company_job_id = 3014918;
const caseName = "[CASE_NAME]";
const annotator = "AutoTest supioadmin";

test.describe("Annotate case (manual)", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.SUPIO_ADMIN });

  test("manually annotate Police Report.Pdf", async ({ annotatePage }) => {
    test.setTimeout(420_000);
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.assignCaseTo(annotator);
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "Police Report.Pdf");
    await annotatePage.annotateSingleDoc("Police Report.Pdf");
    await annotatePage.openQuestionWindow();
    await annotatePage.preProcessingAndSubmitType("Bill");
    await annotatePage.deleteAllRecords();
    await annotatePage.addAnewRecord("Police Report");
    await annotatePage.populateDocument();
    await annotatePage.finishAnnotateTheDoc();
  });

  test("manually annotate bill sutter.pdf", async ({ annotatePage }) => {
    test.setTimeout(420_000);
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "bill sutter.pdf");
    await annotatePage.annotateSingleDoc("bill sutter.pdf");
    await annotatePage.openQuestionWindow();
    await annotatePage.preProcessingAndSubmitType("Bill");
    await annotatePage.deleteAllRecords();
    await annotatePage.addAnewRecord("Bills");
    await annotatePage.populateDocument();
    await annotatePage.finishAnnotateTheDoc();
  });

  test("manually annotate Hospital Treatment Report.Pdf", async ({ annotatePage }) => {
    test.setTimeout(420_000);
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.waitForFileAnnotationGenerated(company_job_id, caseName, "Hospital Treatment Report.Pdf");
    await annotatePage.annotateSingleDoc("Hospital Treatment Report.Pdf");
    await annotatePage.openQuestionWindow();
    await annotatePage.preProcessingAndSubmitType("Bill");
    await annotatePage.deleteAllRecords();
    await annotatePage.addAnewRecord("Bills");
    await annotatePage.populateDocument();
    await annotatePage.finishAnnotateTheDoc();
  });

  test("complete annotation", async ({ annotatePage }) => {
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.completeAnnotate();
    await expect(annotatePage.reviewAnnotateButton()).toBeVisible();
  });

  test("review annotation", async ({ annotatePage }) => {
    annotatePage.setCaseName(caseName);
    await annotatePage.load(company_job_id);
    await annotatePage.reviewAnnotate();
    await expect(annotatePage.generateTimelineButton()).toBeVisible();
  });
});
```

**Adjust per `files=` argument**: generate one test block per file. Use record type appropriate to
the file type (e.g. `"Police Report"` for police report files, `"Bills"` for billing files).

---

## Step 3: Output

Write the generated code to `tests/generated/annotate_temp.spec.ts` (create `tests/generated/` if needed) and show:

1. **Generated code** — full TypeScript code block.
2. **Notes**:
   - `company_job_id = 3014918` is for "QA Test CA Company". Update if the case belongs to a different company.
   - In manual mode, adjust `addAnewRecord` type per document (e.g. `"Bills"`, `"Police Report"`, `"Liens"`).
   - Use `/timeline-operation <caseName>` after annotation is complete to generate and publish the timeline.

**Do not run the test.** Only write the file and output the code.
