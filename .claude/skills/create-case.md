# Create Case Skill

Generate Playwright test code for creating a case and write it to `tests/generated/create_case_temp.spec.ts`.

## How to Use

Invoke with a natural language description. Examples:
- `/create-case` → local case with default settings
- `/create-case a SmartAdvocate case` → CMS connector case
- `/create-case use OneDrive connector with file Hospital Treatment Report.Pdf` → DMS connector with specific file

> **Annotation and timeline steps are separate skills**: `/annotate` and `/timeline-operation`.
> This skill only generates the case creation code.

---

## Step 1: Parse Intent from `$ARGUMENTS`

### 1a. Connector Selection

**DMS connectors** (document management): OneDrive, SharePoint, Dropbox
**CMS connectors** (case management): Litify, GrowPath, SmartAdvocate, Filevine

| Mention | Connector |
|---|---|
| "OneDrive" | `Connector.ONEDRIVE` |
| "SharePoint" | `Connector.SHAREPOINT` |
| "Dropbox" | `Connector.DROPBOX` |
| "Litify" | `Connector.LITIFY` |
| "GrowPath" / "Growpath" | `Connector.GROWPATH` |
| "SmartAdvocate" | `Connector.SMARTADVOCATE` |
| "Filevine" | `Connector.FILEVINE` |
| nothing | `Connector.DEFAULT` (local upload) |

### 1b. Role, Identity, and Company Selection

#### `.withInternalIdentity()` rule

The factory's `handleSetup` shows the company selector **only** when `isInternal === true`.

**Internal roles** (Supio platform accounts, company_id 27 or 50 in `.env`) → must use `.withInternalIdentity()` + `.withCompany()`:
- `SUPIO_ADMIN`, `FIRM_ADMIN`, `TEAM_ADMIN`, `MEMBERSHIP_OP`
- All `OPS*_ADMIN` and `*_OP` roles

**External firm roles** → do NOT use `.withInternalIdentity()` or `.withCompany()` (single-company accounts).

**Why local cases use `SUPIO_ADMIN` + `withInternalIdentity()`:**
Firm companies may enforce required fields (e.g. mandatory team assignment) that vary by configuration.
`SUPIO_ADMIN` as internal user creating for "QA Test CA Company" bypasses these firm-specific requirements reliably.

#### Connector → role/company mapping

| Connector | `loginRole` | `companyName` | `withInternalIdentity()` |
|---|---|---|---|
| `Connector.DEFAULT` (local) | `RoleName.SUPIO_ADMIN` | `"QA Test CA Company"` | Yes |
| `Connector.ONEDRIVE` | `RoleName.TESTCOP_CREATOR` | n/a | No |
| `Connector.SHAREPOINT` | `RoleName.TESTCOP_CREATOR` | n/a | No |
| `Connector.SMARTADVOCATE` | `RoleName.TESTCOP_CREATOR` | n/a | No |
| `Connector.LITIFY` | `RoleName.TESTCOP_CREATOR` | n/a | No |
| `Connector.DROPBOX` | `RoleName.JCHRISP_CREATOR` | n/a | No |
| `Connector.GROWPATH` | `RoleName.WHITLEY_CREATOR` | n/a | No |
| `Connector.FILEVINE` | `RoleName.CSS_CREATOR` | n/a | No |

### 1c. File Selection

- **Local (DEFAULT)**: default files = `["Police Report.Pdf", "bill sutter.pdf", "Hospital Treatment Report.Pdf"]`. Use specific files if mentioned.
- **Connector**: omit `.withFilePaths()` unless specific files are mentioned — factory calls `pickAFileFromConnector()` automatically.

### 1d. Case Name

Derive a short descriptive name from `$ARGUMENTS` to pass to `.withName()`:
- If a connector is mentioned, use the connector name as the base (e.g. `"SmartAdvocate"`, `"OneDrive"`, `"Filevine"`).
- If a topic/keyword is mentioned (e.g. "bill", "econ", "timeline"), use that as the base.
- If nothing descriptive is mentioned, use `"placeholder"`.

Examples: `"SmartAdvocate"` → `.withName("SmartAdvocate")`, `"Advocate"` → `.withName("SmartAdvocate")`, no hint → `.withName("placeholder")`.

### 1e. Case Settings (unless specified otherwise)

- Case type: `"MVA"`
- Package: `PackageCode.Chronology`
- If input mentions "demand letter" or "ChronologyDemand": use `PackageCode.ChronologyDemand` + `.withDemandLetterType(DemandLetterType.Liability)`

---

## Step 2: Generate the Test Code

Write the complete spec to `tests/generated/create_case_temp.spec.ts` (create `tests/generated/` if needed).

### Template — local (DEFAULT) case

```typescript
import { test, expect } from "fixtures";
import { Connector, PackageCode, RoleName } from "@utils/constants";

const companyName = "QA Test CA Company";
let caseName: string;

test.describe("Create case", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.SUPIO_ADMIN });

  test("create a case", async ({ casesPage }) => {
    test.setTimeout(180_000);

    ({ caseName } = await casesPage.caseFactory
      .withInternalIdentity()
      .withName("placeholder")
      .withConnector(Connector.DEFAULT)
      .withFilePaths(["Police Report.Pdf", "bill sutter.pdf", "Hospital Treatment Report.Pdf"])
      .withCaseType("MVA")
      .withPackage(PackageCode.Chronology)
      .withCompany(companyName)
      .create());

    expect(caseName).toBeTruthy();
  });
});
```

### Template — connector case (e.g. SmartAdvocate)

```typescript
import { test, expect } from "fixtures";
import { Connector, PackageCode, RoleName } from "@utils/constants";

let caseName: string;

test.describe("Create case", () => {
  test.describe.configure({ mode: "serial" });
  test.use({ loginRole: RoleName.TESTCOP_CREATOR });

  test("create a SmartAdvocate case", async ({ casesPage }) => {
    test.setTimeout(180_000);

    ({ caseName } = await casesPage.caseFactory
      .withName("SmartAdvocate")
      .withConnector(Connector.SMARTADVOCATE)
      .withDataID("4")
      .withCaseType("MVA")
      .withPackage(PackageCode.Chronology)
      .create());

    expect(caseName).toBeTruthy();
  });
});
```

### Connector chain snippets

**DMS (OneDrive / SharePoint / Dropbox):**
```typescript
.withConnector(Connector.ONEDRIVE)  // adjust as needed
// omit .withFilePaths() — auto-picked; or add .withFilePaths([...]) if specified
```

**CMS (Litify / GrowPath / SmartAdvocate / Filevine) — known dataID values:**
```typescript
.withConnector(Connector.SMARTADVOCATE).withDataID("4")
.withConnector(Connector.FILEVINE).withDataID("987654321")
.withConnector(Connector.GROWPATH).withDataID("987654321")
.withConnector(Connector.LITIFY).withDataID("a0123456789ABCDEFG")
```

---

## Step 3: Output

Write the generated file and show:

1. **Generated code** — full TypeScript code block.
2. **Notes** — remind the user that:
   - The `company_job_id` for "QA Test CA Company" is `3014918` (needed by `/annotate`).
   - Use `/annotate <caseName>` to run the annotation workflow.
   - Use `/timeline-operation <caseName>` to publish the timeline.
