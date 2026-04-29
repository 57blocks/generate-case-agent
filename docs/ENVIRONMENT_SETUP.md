# Environment Setup Guide

## Overview

This project uses separate environment files for staging, production, and CA regions. Each environment is automatically loaded based on the project being run.

## Environment Files

```
.env.stg      # Staging environment (default)
.env.prod     # Production environment
.env.ca       # CA region environment
.env.example  # Template for new environments
```

## Quick Setup

1. **Create environment files from template:**

   ```bash
   cp .env.example .env.stg
   cp .env.example .env.prod
   cp .env.example .env.ca
   ```

2. **Fill in credentials for each environment**

3. **Verify configuration:**
   ```bash
   npm run verify-env        # Check all environments
   npm run verify-env:stg    # Check staging only
   npm run verify-env:prod   # Check production only
   npm run verify-env:ca     # Check CA only
   ```

## Project-Environment Mapping

Projects automatically use their designated environment:

| Project      | Environment | Auto-loaded File |
| ------------ | ----------- | ---------------- |
| `connectors` | Production  | `.env.prod`      |
| `democase`   | Production  | `.env.prod`      |
| `poc`        | Production  | `.env.prod`      |
| `ca`         | CA          | `.env.ca`        |
| `main`       | Staging     | `.env.stg`       |
| Others       | Staging     | `.env.stg`       |

## Running Tests

### Automatic Environment Selection

```bash
# Automatically uses production environment
npx playwright test --project=connectors

# Automatically uses CA environment
npx playwright test --project=ca

# Automatically uses staging environment
npx playwright test --project=main
```

### Manual Environment Override

```bash
# Force staging for production project
TEST_ENV=stg npx playwright test --project=connectors

# Force production for staging project
TEST_ENV=prod npx playwright test --project=main
```

### NPM Scripts

```bash
npm test              # Default (auto-detects environment)
npm run test:stg      # Force staging for all
npm run test:prod     # Force production for all
npm run test:ca       # Force CA for all

npm run debug         # Debug with auto-detect
npm run debug:stg     # Debug in staging
npm run debug:prod    # Debug in production
npm run debug:ca      # Debug in CA
```

## Mixed Environment Mode

When running multiple projects with different environment requirements, the system automatically enters **mixed environment mode**:

```bash
# Runs projects from different environments
npx playwright test --project=democase --project=main

# Output:
# 📦 Mixed environment mode detected
# ✅ Loaded production configuration
# ✅ Loaded staging configuration
# ✅ Initialized accounts from both environments
```

**How it works:**

- Loads all required environments
- Merges credentials from all environments
- Uses correct URLs for each account based on its environment
- Ensures no conflicts between environments

## VSCode Configuration

### Option 1: Use Command Line (Recommended)

Instead of clicking the green play button, use terminal:

```bash
npx playwright test tests/path/to/test.ts --project=connectors
```

### Option 2: Set Default Project

In `.vscode/settings.json`, uncomment and set:

```json
{
  "playwright.env": {
    "PLAYWRIGHT_PROJECT": "connectors" // or "main", "democase", etc.
  }
}
```

**Note:** You'll need to change this manually when testing different projects.

## Required Environment Variables

Each environment file must contain:

### Authentication & URLs

```bash
API_BASE_PATH=api/v1
PORTAL_ENV=https://stg-portal.supio.com
PORTAL_DOMAIN=stg.supio.com
```

### Database (Staging only)

```bash
DB_HOST=...
DB_PORT=5432
DB_USER=...
DB_PASSWORD=...
DB_NAME=users
TRAINING_DB_NAME=training
```

### Test Accounts

Each role requires `EMAIL`, `PASSWORD`, and `COMPANY_ID`:

```bash
# Example: Firm Admin
FIRM_ADMIN_EMAIL=admin@example.com
FIRM_ADMIN_PASSWORD=password123
FIRM_ADMIN_COMPANY_ID=123

# Repeat for all required roles
```

See `.env.example` for complete list of required variables.

## Troubleshooting

### Authentication Failures

**Problem:** Tests fail with "cannot found Cookie"

**Solution:**

1. Verify environment file exists: `ls .env.stg .env.prod .env.ca`
2. Verify credentials are correct: `npm run verify-env`
3. Check console output to see which environment was loaded

### Wrong Environment Loaded

**Problem:** Test uses wrong environment (e.g., staging instead of production)

**Solution:**

1. Check project mapping in `utils/env-loader.ts` → `PROJECT_ENVIRONMENT_MAP`
2. Use explicit override: `TEST_ENV=prod npx playwright test --project=yourproject`

### VSCode Green Button Issues

**Problem:** VSCode test runner loads all environments instead of specific one

**Solution:**

- Use command line instead: `npx playwright test path/to/test.ts --project=connectors`
- Or configure `PLAYWRIGHT_PROJECT` in `.vscode/settings.json`

See [VSCODE_PROJECT_CONFIGURATION.md](VSCODE_PROJECT_CONFIGURATION.md) for details.

## Adding New Environments

To add a new region (e.g., AU):

1. **Create environment file:**

   ```bash
   cp .env.example .env.au
   # Fill in AU-specific credentials
   ```

2. **Update environment enum** in `utils/env-loader.ts`:

   ```typescript
   export enum Environment {
     PROD = "prod",
     CA = "ca",
     STG = "stg",
     AU = "au", // Add new environment
   }
   ```

3. **Update project mapping:**

   ```typescript
   export const PROJECT_ENVIRONMENT_MAP = {
     [Environment.PROD]: ["poc", "democase", "connectors"],
     [Environment.CA]: ["ca"],
     [Environment.AU]: ["au"], // Add new mapping
     [Environment.STG]: [],
   };
   ```

4. **Add project in `playwright.config.ts`:**

   ```typescript
   {
     name: "au",
     testMatch: ["**/workflow_au/**/*.spec.ts"],
   }
   ```

5. **Update GitHub Actions** to include new environment file in artifacts.

Done! The new environment will work automatically.

## Best Practices

### ✅ Do

- Keep environment files separate
- Use project-specific commands: `--project=connectors`
- Verify configuration before committing: `npm run verify-env`
- Use `.env.example` as reference for required variables

### ❌ Don't

- Commit `.env.*` files to git (they're ignored)
- Hardcode URLs in tests
- Mix credentials from different environments
- Share production credentials in staging files

## CI/CD Integration

The environment system works seamlessly with CI/CD:

```yaml
# GitHub Actions example
- name: Create environment files
  run: |
    echo "${{ secrets.STAGING_ENV }}" > .env.stg
    echo "${{ secrets.PROD_ENV }}" > .env.prod
    echo "${{ secrets.CA_ENV }}" > .env.ca

- name: Run tests
  run: npx playwright test --project=democase --project=main
  # Automatically loads production + staging environments
```

The system automatically:

- Detects which projects are running
- Loads required environments
- Initializes only needed accounts
- Uses correct URLs for each environment

---

For more details, see:

- [PROJECT_ENVIRONMENT_MAPPING.md](PROJECT_ENVIRONMENT_MAPPING.md) - Project mapping details
- [VSCODE_PROJECT_CONFIGURATION.md](VSCODE_PROJECT_CONFIGURATION.md) - VSCode setup
- [ADDING_NEW_REGIONS.md](ADDING_NEW_REGIONS.md) - Adding new regions
