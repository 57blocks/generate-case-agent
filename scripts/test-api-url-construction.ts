/**
 * Test script to verify API URL construction from domain + path
 *
 * This validates that API URLs are correctly constructed from PORTAL_DOMAIN + API_BASE_PATH
 * instead of using a single AUTH_API_BASE_URL variable.
 */

import { initializeEnvironment, getCurrentEnvironment } from "../utils/env-loader";
import { ROLE_CONFIG, RoleName } from "../utils/constants";

async function testAPIUrlConstruction() {
  console.log("\n🧪 Testing API URL Construction\n");
  console.log("=".repeat(60));

  // Test all environments
  const environments = ["stg", "prod", "ca"];

  for (const env of environments) {
    console.log(`\n📦 Testing ${env.toUpperCase()} Environment`);
    console.log("-".repeat(60));

    // Set environment
    process.env.TEST_ENV = env;

    // Initialize environment
    await initializeEnvironment();
    const currentEnv = getCurrentEnvironment();

    // Get configuration
    const domain = process.env.PORTAL_DOMAIN;
    const apiBasePath = process.env.API_BASE_PATH;
    const portalEnv = process.env.PORTAL_ENV;

    console.log(`\n   Environment Variables:`);
    console.log(`   - PORTAL_DOMAIN: ${domain}`);
    console.log(`   - API_BASE_PATH: ${apiBasePath}`);
    console.log(`   - PORTAL_ENV: ${portalEnv}`);

    // Check a sample role configuration
    const sampleRole = RoleName.FIRM_ADMIN;
    const roleConfig = ROLE_CONFIG[sampleRole];

    console.log(`\n   ${sampleRole} Configuration:`);
    console.log(`   - baseUrl: ${roleConfig.baseUrl}`);
    console.log(`   - apiBaseUrl: ${roleConfig.apiBaseUrl}`);
    console.log(`   - domain: ${roleConfig.domain}`);

    // Verify API URL construction
    const expectedApiUrl = `https://${domain}/${apiBasePath}`;
    const actualApiUrl = roleConfig.apiBaseUrl;

    console.log(`\n   ✅ Verification:`);
    console.log(`   - Expected API URL: ${expectedApiUrl}`);
    console.log(`   - Actual API URL:   ${actualApiUrl}`);

    if (expectedApiUrl === actualApiUrl) {
      console.log(`   ✅ PASS: API URL correctly constructed`);
    } else {
      console.log(`   ❌ FAIL: API URL mismatch!`);
    }
  }

  console.log("\n" + "=".repeat(60));
  console.log("✅ API URL construction test completed\n");
}

testAPIUrlConstruction().catch(console.error);
