# MCP Login Skill

Inject authentication cookie for a given role into the MCP browser session, so you can use MCP tools without manual login.

## Usage

```
/mcp-login [ROLE] [URL]
```

- `ROLE` — one of the `RoleName` enum values (e.g. `OPS2_ADMIN`, `FIRM_ADMIN`, `NOTI_D_TESTCOP_ADMIN`). Defaults to `OPS2_ADMIN`.
- `URL` — the page to navigate to after login. Defaults to `https://stg-portal.supio.com`.

## Examples

```
/mcp-login
/mcp-login OPS2_ADMIN
/mcp-login NOTI_D_TESTCOP_ADMIN https://stg-portal.supio.com/timeline/3241064?t=flowsheets
/mcp-login FIRM_ADMIN https://stg-portal.supio.com/timeline
```

## Steps

Execute the following steps in order:

### Step 1: Get the cookie via tsx script

Run this bash command to fetch the auth cookie for the requested role:

```bash
TEST_ENV=stg npx tsx -e "
import { authAppLogin } from './utils/helper';
import { RoleName } from './utils/constants';
import { initializeEnvironment } from './utils/env-loader';
initializeEnvironment();
const role = '${ROLE}' as RoleName;
const envKey = role.replace(/-/g, '_');
const email = process.env[envKey + '_EMAIL']!;
const password = process.env[envKey + '_PASSWORD']!;
const companyId = process.env[envKey + '_COMPANY_ID']!;
authAppLogin(email, password, companyId, role).then(data => {
  console.log(JSON.stringify(data));
}).catch(e => { console.error(e); process.exit(1); });
" 2>&1 | grep '^{'
```

Parse the JSON output. It has the shape:
```json
{ "name": "id", "value": "<jwt>", "domain": "stg.supio.com", "path": "/", "baseUrl": "https://stg-portal.supio.com", "apiBasePath": "api/v1" }
```

### Step 2: Navigate to the base URL

```javascript
await mcp__playwright__browser_navigate({ url: "https://stg-portal.supio.com" });
```

### Step 3: Inject the cookie

```javascript
await mcp__playwright__browser_evaluate({
  function: `() => {
    document.cookie = 'id=<VALUE>; domain=stg.supio.com; path=/';
    return document.cookie.includes('id=');
  }`
});
```

Replace `<VALUE>` with the `value` field from Step 1.

Verify the result is `true`. If `false`, report an error — the cookie was not set.

### Step 4: Navigate to the target URL

```javascript
await mcp__playwright__browser_navigate({ url: "${URL}" });
```

### Step 5: Verify login succeeded

```javascript
await mcp__playwright__browser_evaluate({
  function: `() => ({
    url: window.location.href,
    isLoginPage: window.location.pathname === '/login',
    title: document.title,
  })`
});
```

If `isLoginPage` is `true`, the cookie injection failed (possibly expired or wrong domain). Report this to the user.

If `isLoginPage` is `false`, report success:
```
✅ MCP browser logged in as ${ROLE}
   URL: ${URL}
```

## Notes

- The cookie is a JWT that expires after ~7 days. If login fails with a valid-looking cookie, re-run the skill to get a fresh one.
- This sets the cookie on `stg.supio.com` domain. For prod or CA environments, change `TEST_ENV` and the domain accordingly.
- After calling this skill, you can use all MCP browser tools (`browser_snapshot`, `browser_click`, etc.) on the logged-in session.
- **Always call `mcp__playwright__browser_close()` when done with MCP inspection**, before running any Playwright tests.
