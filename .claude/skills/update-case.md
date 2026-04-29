# Update Case Skill

Generate Playwright test code for updating an existing case and write it to `tests/generated/update_case_temp.spec.ts`.

## How to Use

Invoke with a case name and optional update parameters. Examples:
- `/update-case deqtest_auto_UI_1773725413367` → update files only (add default files)
- `/update-case deqtest_auto_UI_1773725413367 files=MRnMB.pdf,Hospital Treatment Report.Pdf` → update with specific files
- `/update-case deqtest_auto_UI_1773725413367 caseType=NEC package=Chronology` → update case type and package
- `/update-case deqtest_auto_UI_1773725413367 caseType=MVA package=ChronologyDemand demandLetter=Liability economic=true` → full update

---

## Step 1: Parse Intent from `$ARGUMENTS`

### 1a. Case Name
Extract the case name from `$ARGUMENTS`.

### 1b. Role Selection

Update case requires navigating to the case first. Use the appropriate role:

| Scenario | `loginRole` | Notes |
|---|---|---|
| Default / file update | `RoleName.FIRM_ADMIN` | External firm user |
| Case type / package update | `RoleName.OPS2_ADMIN` | Internal user, needs `withInternalIdentity()` + `withCompany()` |

Use `OPS2_ADMIN` if `caseType` or `package` is specified. Otherwise default to `FIRM_ADMIN`.

### 1c. Navigation to Case

- **FIRM_ADMIN**: use `timelinePage.viewCase(caseName)` to navigate
- **OPS2_ADMIN** (internal): use `timelinePage.internalUserFindCaseInCompany(companyName, caseName)`

### 1d. Update Parameters

| Argument | Factory method | Notes |
|---|---|---|
| `files=file1,file2` | `.withFilePaths([...])` | Comma-separated file names |
| `caseType=MVA` | `.withCaseType("MVA")` | Any valid case type string |
| `package=Chronology` | `.withPackage(PackageCode.Chronology)` | See package mapping below |
| `package=ChronologyDemand` | `.withPackage(PackageCode.ChronologyDemand)` | Requires `demandLetter` |
| `demandLetter=Liability` | `.withDemandLetterType(DemandLetterType.Liability)` | Only with ChronologyDemand |
| `economic=true/false` | `.withEconomic(true/false)` | Optional |

**Package mapping:**
- `Chronology` → `PackageCode.Chronology`
- `ChronologyDemand` → `PackageCode.ChronologyDemand`
- `DeepDive` → `PackageCode.DeepDive`

### 1e. `checkDocumentProcessing` option

- Include `{ checkDocumentProcessing: true }` in `.update()` when files are uploaded (`.withFilePaths()` is used)
- Omit options (`.update()`) when only updating case type / package / economic with no file changes

---

## Step 2: Generate the Test Code

Write the complete spec to `tests/generated/update_case_temp.spec.ts`.

### Template — file update (FIRM_ADMIN)

```typescript
import { test, expect } from "fixtures";
import { PackageCode, RoleName } from "@utils/constants";
import { TimelinePage } from "@pages/firmadmin/timeline";

const caseName = "[CASE_NAME]";
const companyName = "QA Test CA Company";

test.describe("Update case", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.FIRM_ADMIN });

  test("update case files", async ({ casesPage }) => {
    test.setTimeout(300_000);

    const timelinePage = new TimelinePage(casesPage.page);
    await timelinePage.viewCase(caseName);

    await casesPage.caseFactory
      .withExistingCase(caseName)
      .withFilePaths(["Hospital Treatment Report.Pdf"])
      .withCompany(companyName)
      .update({ checkDocumentProcessing: true });

    expect(caseName).toBeTruthy();
  });
});
```

### Template — case type / package update (OPS2_ADMIN, internal)

```typescript
import { test, expect } from "fixtures";
import { DemandLetterType, PackageCode, RoleName } from "@utils/constants";
import { TimelinePage } from "@pages/firmadmin/timeline";

const caseName = "[CASE_NAME]";
const companyName = "QA Test CA Company";

test.describe("Update case", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.OPS2_ADMIN });

  test("update case type and package", async ({ casesPage }) => {
    test.setTimeout(180_000);

    const timelinePage = new TimelinePage(casesPage.page);
    await timelinePage.internalUserFindCaseInCompany(companyName, caseName);

    await casesPage.caseFactory
      .withExistingCase(caseName)
      .withCaseType("MVA")
      .withPackage(PackageCode.ChronologyDemand)
      .withDemandLetterType(DemandLetterType.Liability)
      .withEconomic(false)
      .update();

    expect(caseName).toBeTruthy();
  });
});
```

### Import rules

- Always import `TimelinePage` from `"@pages/firmadmin/timeline"`.
- Only import `DemandLetterType` if demand letter type is used.
- Only import `Connector` if a connector is used (rare for update).

---

## Step 3: Output

Write the generated file and show:

1. **Generated code** — full TypeScript code block.
2. **Notes**:
   - Run `/annotate <caseName>` after update if new files were uploaded and annotation is needed.
   - Run `/timeline-operation <caseName>` to regenerate and publish the timeline.

**Do not run the test.** Only write the file and output the code.
