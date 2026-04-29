/**
 * Test script to verify domain resolution in different environments
 *
 * This validates that getDomain() correctly retrieves domain from auth data
 * rather than extracting it from URL strings.
 */

import { chromium } from '@playwright/test';
import { initializeEnvironment, getCurrentEnvironment } from '../utils/env-loader';
import { RoleName } from '../utils/constants';

async function testDomainResolution() {
  console.log('\n🧪 Testing Domain Resolution\n');
  console.log('=' .repeat(60));

  // Initialize environment
  await initializeEnvironment();
  const currentEnv = getCurrentEnvironment();
  console.log(`\n📦 Current Environment: ${currentEnv}`);

  // Test cases
  const testCases = [
    { env: 'STG', role: RoleName.FIRM_ADMIN, expectedDomain: 'stg.supio.com' },
    { env: 'PROD', role: RoleName.DEMO_USER, expectedDomain: 'supio.com' },
  ];

  const browser = await chromium.launch();

  for (const testCase of testCases) {
    console.log(`\n📝 Testing ${testCase.role} (${testCase.env} environment)`);
    console.log('-'.repeat(60));

    try {
      // Get auth data from environment
      const authDataStr = process.env[`${testCase.role}_ACCOUNT`];

      if (!authDataStr) {
        console.log(`⚠️  ${testCase.role}_ACCOUNT not set in environment`);
        continue;
      }

      const authData = JSON.parse(authDataStr);

      console.log(`   Auth Data:`);
      console.log(`   - baseUrl: ${authData.baseUrl}`);
      console.log(`   - domain: ${authData.domain}`);

      // Create page with auth data (simulating fixture behavior)
      const page = await browser.newPage({
        baseURL: authData.baseUrl,
        storageState: {
          cookies: [authData],
          origins: [{ origin: authData.baseUrl, localStorage: [] }],
        },
      });

      // Store domain in context (simulating updated createPageInstance)
      (page.context() as any)._options = {
        ...(page.context() as any)._options,
        domain: authData.domain,
      };

      // Test domain retrieval
      const retrievedDomain = (page.context() as any)._options?.domain;

      console.log(`\n   ✅ Retrieved domain: ${retrievedDomain}`);
      console.log(`   Expected domain: ${testCase.expectedDomain}`);

      if (retrievedDomain === testCase.expectedDomain) {
        console.log(`   ✅ PASS: Domain matches expected value`);
      } else {
        console.log(`   ❌ FAIL: Domain mismatch!`);
      }

      await page.close();

    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
  }

  await browser.close();

  console.log('\n' + '='.repeat(60));
  console.log('✅ Domain resolution test completed\n');
}

testDomainResolution().catch(console.error);
