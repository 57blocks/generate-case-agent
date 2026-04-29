# Test Strategy: Case Create / Update Revamp (AI First)

> Feature: Simplified Case Create & Update Experience  
> Linear Ticket: SUP-7154 (Case Stage update) and related  
> Last updated: 2026-04-20

---

## 1. Background & PRD Summary

### Why this change

The existing case creation flow was designed around the operations team's needs, leading to a question-heavy wizard (med chron, econ, demands, HitL options). In the AI-first world these questions are unnecessary and create friction. This initiative:

- Simplifies case create to a **full-page single experience** (no more modal/wizard)
- Splits case update into **file upload only** vs. a separate **Edit Case Details** flow
- Introduces **Case Stage** (per case type) replacing the litigation question
- Adds an **AI First case flag** to skip legacy Airtable webhooks
- Cleans up backend logic (Airtable hooks remain but are bypassed for new cases)

### Key decisions from Linear

- New experience is **gated by two conditions**: company-level flag AND user opt-in
- Entry point for user opt-in is **TBD** — assume an activation mechanism exists
- `Product Liability` and `Sexual Abuse` case types are edge cases for MT/SI stage mapping (customer-specific)
- Demand Intake content has moved to **Demands module** and **Case Details component**
- Case Stage can be changed at any time via Edit Case Details (SUP-7154)

---

## 2. Scope

| Area | In Scope | Out of Scope |
|------|----------|--------------|
| Case Create (new full-page UX) | ✅ | Old wizard/modal (regression only) |
| Case Update → file upload only | ✅ | File upload internals (unchanged) |
| Edit Case Details modal | ✅ | Archive/Unarchive flow (unchanged) |
| Case Stage field | ✅ | Stage reporting/analytics dashboards |
| AI First flag + Airtable webhook skip | ✅ | Full Airtable integration tests |
| Feature gate (company flag + user opt-in) | ✅ | Gate admin UI (TBD) |
| Connector/CMS/DMS logic | Regression only | No new changes |

---

## 3. Feature Gate Logic

This is the highest-risk area because it controls **which experience the user sees**.

### Conditions for new experience

```
Show new AI-first case create experience IF:
  company.aiFirstEnabled === true
  AND user.aiFirstOptIn === true
```

### Test Matrix

| Company Flag | User Opt-in | Expected Experience |
|-------------|-------------|---------------------|
| OFF | N/A | Old modal/wizard |
| ON | OFF / not set | Old modal/wizard (or opt-in prompt) |
| ON | ON | New full-page experience |

### Test Cases

- `TC-GATE-01` — Company flag OFF: clicking "New Case" opens old modal
- `TC-GATE-02` — Company ON, user not opted in: old experience shown
- `TC-GATE-03` — Company ON, user opts in: new full-page experience shown
- `TC-GATE-04` — Opt-in persists after page refresh / re-login
- `TC-GATE-05` — Switching between users with different opt-in states on same company

---

## 4. Case Create (New Full-Page Experience)

### 4.1 Page Structure

- Full page, not a modal
- No wizard steps / no "Next" button
- Connector selector at the top (first decision point)
- Single scrollable form with file upload at bottom
- No Case Builder panel
- No Demand Intake form

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CC-01` | Page renders as full page | No modal overlay; URL changes to case create route |
| `TC-CC-02` | No wizard steps present | No step indicator / "Next" button visible |
| `TC-CC-03` | Case Builder panel absent | Element for Case Builder does not exist in DOM |
| `TC-CC-04` | Demand Intake form absent | Form section not present |

### 4.2 Required Fields & Validation

| Field | Required | Notes |
|-------|----------|-------|
| Case Name | Yes | Blank submit shows error |
| Case Type | Yes | Drives Case Stage options |
| Case ID / Connector ID | Conditional | Existing logic unchanged |

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CC-10` | Submit with empty Case Name | Validation error shown, no submission |
| `TC-CC-11` | Submit with empty Case Type | Validation error shown |
| `TC-CC-12` | Submit with all required fields filled | Case created successfully |
| `TC-CC-13` | Case Name accepts special characters / long strings | No truncation or crash |

### 4.3 Optional Fields

Handling Attorney, Team, Support Staff — logic unchanged from current implementation.

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CC-20` | Create case without optional fields | Success |
| `TC-CC-21` | Team field only appears when teams feature enabled | Field absent when teams disabled |

### 4.4 Case Stage

Stage options depend on Case Type (SI vs MT mapping). Default: no selection.

**SI stages:** Intake → Treatment → Demand & Negotiation → Settlement → Litigation  
**MT stages:** Intake → Qualification → Claim Filed → Litigation → Settlement

**Edge cases:** Product Liability and Sexual Abuse are mapped per customer config.

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CS-01` | Select SI case type | SI stage options displayed |
| `TC-CS-02` | Select MT case type | MT stage options displayed |
| `TC-CS-03` | Switch case type after selecting a stage | Stage selection resets / correct options shown |
| `TC-CS-04` | Default state | No stage pre-selected |
| `TC-CS-05` | Single select enforcement | Cannot select more than one stage |
| `TC-CS-06` | Create without selecting stage | Case created successfully (not required) |
| `TC-CS-07` | Create with stage selected | Stage saved and visible on Overview |
| `TC-CS-08` | Product Liability type | Correct MT or SI stages shown per company config |
| `TC-CS-09` | Sexual Abuse type | Correct MT or SI stages shown per company config |

### 4.5 Connector / CMS / DMS

No logic changes — regression only.

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CC-30` | Company with connector: connector selector shown first | Connector options appear at top of form |
| `TC-CC-31` | No connector: standard form shown | No connector selector |
| `TC-CC-32` | Select connector → auto-populate name/case type | Fields populated from connector data |

### 4.6 Post-Create Navigation

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CC-40` | Successful case create | Redirected to case Overview page |
| `TC-CC-41` | Overview page shows newly created case data | Name, type, stage (if set) all visible |

---

## 5. Case Update → File Upload Only

Case update is now **file upload only** and can **only be launched from the Files page**.

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-CU-01` | Access Files page → Update case button present | Button visible |
| `TC-CU-02` | Update case modal contains only file upload | No case details fields in modal |
| `TC-CU-03` | CMS/DMS selector present in modal | Selector visible at top of uploader |
| `TC-CU-04` | Upload file via modal → file appears in Files list | File upload succeeds |
| `TC-CU-05` | "Update case" entry point NOT available outside Files page | Button absent on Timeline, Chrono, Overview pages |

---

## 6. Edit Case Details Modal

Launched from: **Overview page → Case Details component → Edit button → dropdown → "Edit Case Details"**

### Field Permissions

| Field | External User | Internal User |
|-------|--------------|---------------|
| Stage | ✅ | ✅ |
| Handling Attorney | ✅ | ✅ |
| Support Staff | ✅ | ✅ |
| Team | ✅ (if enabled) | ✅ (if enabled) |
| Notes | ✅ | ✅ |
| Case Type | ❌ | ✅ |

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-ED-01` | Overview → Edit button → dropdown shows 2 options | "Edit Case Details" and "Archive/Unarchive" visible |
| `TC-ED-02` | Click "Edit Case Details" → modal opens | Modal appears with correct fields |
| `TC-ED-03` | External user: Case Type field absent | Field not in modal |
| `TC-ED-04` | Internal user: Case Type field present | Field visible and editable |
| `TC-ED-05` | Change Stage → save → Overview reflects new stage | Stage updated |
| `TC-ED-06` | Change Notes → save | Notes updated |
| `TC-ED-07` | Team field only visible when teams enabled | Field absent when feature off |
| `TC-ED-08` | Archive/Unarchive option still works | No regression |
| `TC-ED-09` | Stage can be changed multiple times | Each update persists correctly |

---

## 7. AI First Case Flag & Airtable Webhook

### Expected behavior

- All new cases created via the new experience → `aiFirsCase: true` in metadata
- AI First cases: Airtable webhook calls are **skipped**
- Legacy cases: Airtable webhooks continue as before

### Test Cases

| ID | Scenario | Assertion |
|----|----------|-----------|
| `TC-AI-01` | Create case via new experience | Network: no Airtable webhook request fired |
| `TC-AI-02` | Update (file upload) an AI First case | No Airtable webhook fired |
| `TC-AI-03` | Update a legacy case | Airtable webhook fires as expected |
| `TC-AI-04` | AI First flag present in case metadata | Backend/DB check: flag is set to true |

> **Note:** Verifying webhook skip requires either network request interception in Playwright or backend log inspection. Confirm implementation approach with dev team.

---

## 8. Regression Scope

| Area | Risk | What to Check |
|------|------|---------------|
| Old case create (non-AI-first users) | High | Modal/wizard flow unchanged |
| File upload component | Medium | Same behavior, just moved context |
| Connector auto-populate | Medium | Name/case type still populate |
| Archive/Unarchive | Low | Entry point changed to dropdown, functionality same |
| Handling Atty / Team / Support Staff | Low | Logic unchanged |

---

## 9. Open Questions (Confirm Before Test Execution)

| # | Question | Owner |
|---|----------|-------|
| 1 | What is the user opt-in entry point (UI element/route)? | Product |
| 2 | Product Liability / Sexual Abuse MT/SI mapping per test company? | Michael / Dev |
| 3 | How to verify Airtable webhook skip — network intercept or log? | Dev |
| 4 | Is "Update case" button completely removed from non-Files pages, or just hidden? | Dev |
| 5 | Which test accounts have AI First company flag enabled? | QA / DevOps |
| 6 | Demand Intake content migration — confirmed removed from case create? (Kosta's team) | Product |

---

## 10. Test Execution Order (Suggested)

1. Feature Gate (gate must work before anything else)
2. Case Create — page structure & removed elements
3. Case Create — required field validation
4. Case Create — Case Stage (SI/MT, single select, optional)
5. Case Create — post-create navigation
6. Case Update — entry point & modal content
7. Edit Case Details — permissions & field behavior
8. AI First flag — webhook skip verification
9. Regression — old experience, file upload, connector
