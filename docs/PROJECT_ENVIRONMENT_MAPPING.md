# Project Environment Mapping

## Overview

Different Playwright projects automatically use different environments based on their purpose. This ensures that production-focused tests always run against production data, while development tests use staging.

## Project Environment Mapping

| Project | Default Environment | Override | CI Behavior |
|---------|-------------------|----------|-------------|
| **poc** | Production (`.env.prod`) | `TEST_ENV=stg npx playwright test --project=poc` | Not in "all", separate schedule |
| **democase** | Production (`.env.prod`) | `TEST_ENV=stg npx playwright test --project=democase` | Included in "all" |
| **connectors** | Production (`.env.prod`) | `TEST_ENV=stg npx playwright test --project=connectors` | Included in "all" |
| **ca** | CA (`.env.ca`) | `TEST_ENV=stg npx playwright test --project=ca` | Manual trigger only |
| **main** | Staging (`.env.stg`) | `TEST_ENV=prod npx playwright test --project=main` | Included in "all" |

## How It Works

### Automatic Detection

The system detects which project is running by parsing command-line arguments:

```typescript
// In utils/constants.ts
const projectArg = process.argv.find((arg) => arg.startsWith("--project="));
const projectName = projectArg ? projectArg.split("=")[1] : undefined;
initializeEnvironment(projectName);
```

### Environment Selection Logic

```typescript
// In utils/env-loader.ts
export function getEnvironmentForProject(projectName?: string): Environment {
  // 1. TEST_ENV takes highest priority
  if (process.env.TEST_ENV) {
    return getCurrentEnvironment(); // Uses TEST_ENV value
  }

  // 2. Check if project is in CA list
  if (isCAProject(projectName)) {
    return Environment.CA;
  }

  // 3. Check if project is in production list
  if (isProductionProject(projectName)) {
    return Environment.PROD;
  }

  // 4. Default to staging
  return Environment.STG;
}
```

### Project Environment Lists

```typescript
// CA environment projects
export const CA_PROJECTS = ["ca"];

// Production environment projects
export const PRODUCTION_PROJECTS = ["poc", "democase", "connectors"];
```

## Usage Examples

### Running Tests with Default Environments

```bash
# POC tests → automatically use production
npx playwright test --project=poc

# Demo case tests → automatically use production
npx playwright test --project=democase

# Connector tests → automatically use production
npx playwright test --project=connectors

# CA workflow tests → automatically use CA environment
npx playwright test --project=ca

# Main tests → automatically use staging
npx playwright test --project=main
```

**Console Output:**
```
Loaded configuration from .env.prod
Running tests in PROD environment (project: democase)
```

### Overriding Default Environments

```bash
# Run democase tests against staging (for development)
TEST_ENV=stg npx playwright test --project=democase

# Run main tests against production (for verification)
TEST_ENV=prod npx playwright test --project=main
```

**Console Output with Override:**
```
Loaded configuration from .env.stg
Running tests in STG environment (project: democase)
```

### Running Without Project Specification

```bash
# Uses default staging environment
npm test

# Uses specified environment
TEST_ENV=prod npm test
```

## Adding New Projects

### To Add a New Production Project

1. **Update the production projects list:**
```typescript
// utils/env-loader.ts
export const PRODUCTION_PROJECTS = ["poc", "democase", "connectors", "newproject"];
```

2. **Add project configuration:**
```typescript
// playwright.config.ts
{
  name: "newproject",
  testMatch: ["**/newproject/**/*.spec.ts"],
  // Automatically uses production environment
}
```

3. **Verify:**
```bash
npx playwright test --project=newproject --list
# Should show: "Running tests in PROD environment (project: newproject)"
```

### To Add a New Staging Project

1. **Add project configuration:**
```typescript
// playwright.config.ts
{
  name: "newstaging",
  testMatch: ["**/newstaging/**/*.spec.ts"],
  // Automatically uses staging environment (default)
}
```

2. **Verify:**
```bash
npx playwright test --project=newstaging --list
# Should show: "Running tests in STG environment (project: newstaging)"
```

## Environment Priority

The environment selection follows this priority order:

1. **Highest Priority**: `TEST_ENV` environment variable
   ```bash
   TEST_ENV=prod npx playwright test --project=democase
   # Uses PROD even though democase defaults to PROD
   ```

2. **Medium Priority**: Project name detection
   ```bash
   npx playwright test --project=democase
   # Uses PROD because democase is in PRODUCTION_PROJECTS
   ```

3. **Lowest Priority**: Default staging
   ```bash
   npx playwright test
   # Uses STG (default)
   ```

## Verification

### Check Which Environment Will Be Used

```bash
# List tests to see environment without running
npx playwright test --project=democase --list

# Output shows:
# Loaded configuration from .env.prod
# Running tests in PROD environment (project: democase)
```

### Check Account Configuration

```bash
# Verify production accounts
npm run test-setup:prod
# Shows: 2 accounts configured (DEMO_USER, TESTCOP_PROD)

# Verify staging accounts
npm run test-setup:stg
# Shows: 42 accounts configured
```

## Common Scenarios

### Scenario 1: Develop New Demo Case Feature

**Goal**: Test demo case feature against staging data

```bash
# Override democase to use staging
TEST_ENV=stg npx playwright test --project=democase tests/path/to/new-test.spec.ts
```

### Scenario 2: Validate Production Demo Cases

**Goal**: Run demo case tests against production (default behavior)

```bash
# Uses production by default
npx playwright test --project=democase
```

### Scenario 3: Run All Tests Against Staging

**Goal**: Full test suite in staging

```bash
# Override all projects to use staging
TEST_ENV=stg npm test
```

### Scenario 4: Run Specific POC Test in Production

**Goal**: Test POC feature in production

```bash
# Uses production by default
npx playwright test --project=poc tests/specific-poc-test.spec.ts
```

## Troubleshooting

### Issue: Wrong environment being used

**Check:**
1. Verify TEST_ENV is not set unexpectedly:
   ```bash
   echo $TEST_ENV
   ```

2. Check project name detection:
   ```bash
   npx playwright test --project=yourproject --list
   # First line shows which env is loaded
   ```

3. Verify project is in correct list:
   ```bash
   # Check utils/env-loader.ts
   grep "PRODUCTION_PROJECTS" utils/env-loader.ts
   ```

### Issue: Cannot override project environment

**Solution**: Ensure TEST_ENV is set before the command:
```bash
# ✅ Correct
TEST_ENV=stg npx playwright test --project=democase

# ❌ Wrong
npx playwright test --project=democase TEST_ENV=stg
```

### Issue: Environment not detected for new project

**Cause**: Project name doesn't match exactly

**Solution**:
1. Check actual project name in config
2. Ensure case-sensitive match
3. Add to PRODUCTION_PROJECTS if needed

## Best Practices

### 1. Keep Production Projects List Updated

```typescript
// When adding production tests, update this list
export const PRODUCTION_PROJECTS = ["poc", "democase", "connectors"];
```

### 2. Use Descriptive Project Names

```typescript
// ✅ Good: Clear purpose
{ name: "smoke-prod", testMatch: ["**/smoke/**/*.spec.ts"] }

// ❌ Bad: Ambiguous
{ name: "tests1", testMatch: ["**/tests1/**/*.spec.ts"] }
```

### 3. Document Project Purpose

```typescript
{
  name: "democase",
  testMatch: ["**/democase/**/*.spec.ts"],
  timeout: 120_000,
  // Demo case tests use production environment by default
  // These tests validate demo cases used for sales/training
}
```

### 4. Test Both Environments

```bash
# Before committing, test staging behavior
TEST_ENV=stg npx playwright test --project=yourproject

# Then test production behavior
npx playwright test --project=yourproject
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
# Run production projects against production
- name: Run production tests
  run: npx playwright test --project=democase --project=poc --project=connectors

# Run staging tests against staging
- name: Run staging tests
  run: npx playwright test --project=main

# Override for testing
- name: Run democase in staging (for development)
  env:
    TEST_ENV: stg
  run: npx playwright test --project=democase
```

## Summary

The project environment mapping provides:

- ✅ **Automatic Environment Selection**: Production projects → production env
- ✅ **Override Capability**: `TEST_ENV` can override any project default
- ✅ **Clear Logging**: Console shows which environment is loaded
- ✅ **Flexible Configuration**: Easy to add new projects
- ✅ **Safe Defaults**: Staging by default, production by opt-in

This ensures:
- Demo cases always test against production data
- Development tests safely use staging
- Flexibility to override when needed
- Clear visibility into which environment is active

For more information:
- [Environment Configuration Guide](ENVIRONMENT_CONFIGURATION.md)
- [Global Setup Guide](GLOBAL_SETUP_GUIDE.md)
- [Architecture Notes](ARCHITECTURE_NOTES.md)
