# VSCode Configuration Guide

## The Problem

VSCode Playwright extension uses `test-server` mode which cannot automatically detect which project is being run. This causes all environments (PROD + CA + STG) to be loaded when clicking the green play button.

## Solutions

### Option 1: Use Command Line (Recommended)

Don't use the green play button. Use terminal instead:

```bash
# Run connectors test
npx playwright test tests/firmadmin/cases/create_case_flow_with_connectors_prod.test.ts --project=connectors

# With debug mode
npx playwright test tests/path/to/test.ts --project=connectors --debug

# Run specific test
npx playwright test tests/path/to/test.ts --project=connectors --grep "test name"
```

**Benefits:**
- ✅ Automatic project detection
- ✅ Correct environment loaded
- ✅ Uses right credentials

### Option 2: Configure Default Project

In `.vscode/settings.json`, uncomment and set:

```json
{
  "playwright.env": {
    "PLAYWRIGHT_PROJECT": "connectors"  // Change per project type
  }
}
```

**Available values:**
- `"main"` - For most tests (uses staging)
- `"connectors"` - For connector tests (uses production)
- `"democase"` - For demo case tests (uses production)
- `"ca"` - For CA workflow tests (uses CA environment)

**Limitation:** Must change manually when testing different project types.

### Option 3: Accept Default Behavior

Continue using green play button, accept that it loads all environments.

**Result:**
- Loads PROD + CA + STG (slower)
- Account priority: CA > PROD > STG
- Example: `TESTCOP_PROD` uses CA account instead of PROD

## Comparison

| Method | Project Detection | Environment | Convenience |
|--------|------------------|-------------|-------------|
| **Command Line** | ✅ Automatic | ✅ Correct | ⭐⭐⭐⭐⭐ |
| **NPM Scripts** | ✅ Automatic | ✅ Correct | ⭐⭐⭐⭐⭐ |
| **VSCode + env var** | ⚠️ Manual | ✅ Correct | ⭐⭐⭐ |
| **Green Button (default)** | ❌ None | ⚠️ All loaded | ⭐⭐ |

## NPM Scripts Helper

Add to `package.json`:

```json
{
  "scripts": {
    "test:conn": "playwright test --project=connectors",
    "test:demo": "playwright test --project=democase",
    "test:main": "playwright test --project=main"
  }
}
```

Usage:
```bash
npm run test:conn tests/path/to/test.ts
```

## Why VSCode Can't Auto-Detect

When VSCode runs tests, the command is:
```bash
node playwright/test/cli.js test-server -c playwright.config.ts
```

This **doesn't include**:
- ❌ Test file path
- ❌ Project name
- ❌ Any runtime information

The global-setup runs **before** VSCode tells the test-server which test to run, so there's no way to know which project the test belongs to.

## Recommendation

Use command line for daily development:

```bash
# Create aliases in ~/.zshrc or ~/.bashrc
alias pt-conn="npx playwright test --project=connectors"
alias pt-demo="npx playwright test --project=democase"
alias pt-main="npx playwright test --project=main"

# Usage
pt-conn tests/firmadmin/cases/create_case_flow_with_connectors_prod.test.ts
```

This provides the best experience with automatic project detection.

---

For more information, see:
- [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) - Environment configuration
- [PROJECT_ENVIRONMENT_MAPPING.md](PROJECT_ENVIRONMENT_MAPPING.md) - Project mappings
