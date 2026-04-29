#!/usr/bin/env ts-node

/**
 * Environment Configuration Verification Script
 *
 * This script verifies that environment configuration files are properly set up
 * and contain all required variables.
 */

import * as fs from "fs";
import * as path from "path";
import { initializeEnvironment, getCurrentEnvironment, Environment } from "../utils/env-loader";

// Required environment variables for all environments (URLs only)
const REQUIRED_VARS = ["API_BASE_PATH", "PORTAL_ENV", "PORTAL_DOMAIN"];

// Required for staging environment
const STG_REQUIRED_VARS = [
  ...REQUIRED_VARS,
  "DB_HOST",
  "DB_PORT",
  "DB_USER",
  "DB_PASSWORD",
  "DB_NAME",
  "TRAINING_DB_NAME",
  // Staging has many accounts, but we only check for core ones
  "SUPIO_ADMIN_EMAIL",
  "SUPIO_ADMIN_PASSWORD",
  "SUPIO_ADMIN_COMPANY_ID",
  "FIRM_ADMIN_EMAIL",
  "FIRM_ADMIN_PASSWORD",
  "FIRM_ADMIN_COMPANY_ID",
];

// Required for production environment
const PROD_REQUIRED_VARS = [
  ...REQUIRED_VARS,
  "DEMO_USER_EMAIL",
  "DEMO_USER_PASSWORD",
  "DEMO_USER_COMPANY_ID",
  "TESTCOP_PROD_EMAIL",
  "TESTCOP_PROD_PASSWORD",
  "TESTCOP_PROD_COMPANY_ID",
];

// Required for CA environment
const CA_REQUIRED_VARS = [
  ...REQUIRED_VARS,
  "OPS_ADMIN_EMAIL",
  "OPS_ADMIN_PASSWORD",
  "OPS_ADMIN_COMPANY_ID",
  "TESTCOP_PROD_EMAIL",
  "TESTCOP_PROD_PASSWORD",
  "TESTCOP_PROD_COMPANY_ID",
];

interface VerificationResult {
  environment: Environment;
  fileExists: boolean;
  missingVars: string[];
  allVarsPresent: boolean;
}

/**
 * Check if environment file exists
 */
function checkEnvFileExists(env: Environment): boolean {
  const envFile = `.env.${env}`;
  const envPath = path.resolve(process.cwd(), envFile);
  return fs.existsSync(envPath);
}

/**
 * Get list of missing required variables based on environment
 */
function getMissingVars(env: Environment): string[] {
  const missing: string[] = [];

  // Determine which variables are required for this environment
  let requiredVars: string[];
  switch (env) {
    case Environment.STG:
      requiredVars = STG_REQUIRED_VARS;
      break;
    case Environment.PROD:
      requiredVars = PROD_REQUIRED_VARS;
      break;
    case Environment.CA:
      requiredVars = CA_REQUIRED_VARS;
      break;
    default:
      requiredVars = REQUIRED_VARS;
  }

  // Check for missing variables
  for (const varName of requiredVars) {
    if (!process.env[varName]) {
      missing.push(varName);
    }
  }

  return missing;
}

/**
 * Verify environment configuration
 */
function verifyEnvironment(env: Environment): VerificationResult {
  console.log(`\n🔍 Verifying ${env.toUpperCase()} environment configuration...`);

  const fileExists = checkEnvFileExists(env);

  if (!fileExists) {
    console.log(`❌ Configuration file .env.${env} not found`);
    return {
      environment: env,
      fileExists: false,
      missingVars: [],
      allVarsPresent: false,
    };
  }

  console.log(`✅ Configuration file .env.${env} exists`);

  // Load the environment
  try {
    initializeEnvironment();
  } catch (error) {
    console.log(`❌ Error loading environment: ${error.message}`);
    return {
      environment: env,
      fileExists: true,
      missingVars: [],
      allVarsPresent: false,
    };
  }

  // Check for missing variables
  const missingVars = getMissingVars(env);

  if (missingVars.length === 0) {
    console.log(`✅ All required variables are present`);
    return {
      environment: env,
      fileExists: true,
      missingVars: [],
      allVarsPresent: true,
    };
  } else {
    console.log(`❌ Missing ${missingVars.length} required variable(s):`);
    missingVars.forEach((varName) => {
      console.log(`   - ${varName}`);
    });
    return {
      environment: env,
      fileExists: true,
      missingVars,
      allVarsPresent: false,
    };
  }
}

/**
 * Main verification function
 */
function main() {
  console.log("=".repeat(60));
  console.log("  Environment Configuration Verification");
  console.log("=".repeat(60));

  // Get target environment from TEST_ENV or check all
  const targetEnv = process.env.TEST_ENV?.toLowerCase();

  if (targetEnv) {
    // Verify specific environment
    const env = getCurrentEnvironment();
    const result = verifyEnvironment(env);

    console.log("\n" + "=".repeat(60));
    if (result.fileExists && result.allVarsPresent) {
      console.log("✅ Environment configuration is valid!");
      process.exit(0);
    } else {
      console.log("❌ Environment configuration has issues");
      process.exit(1);
    }
  } else {
    // Verify all environments
    console.log("\nℹ️  No TEST_ENV specified, checking all environments...\n");

    const results = [
      verifyEnvironment(Environment.STG),
      verifyEnvironment(Environment.PROD),
      verifyEnvironment(Environment.CA),
    ];

    console.log("\n" + "=".repeat(60));
    console.log("Summary:");
    console.log("=".repeat(60));

    results.forEach((result) => {
      const status = result.fileExists && result.allVarsPresent ? "✅" : "❌";
      console.log(`${status} ${result.environment.toUpperCase()}: ${
        result.fileExists
          ? result.allVarsPresent
            ? "Valid"
            : `Missing ${result.missingVars.length} variable(s)`
          : "File not found"
      }`);
    });

    const allValid = results.every((r) => r.fileExists && r.allVarsPresent);
    console.log("\n" + "=".repeat(60));
    if (allValid) {
      console.log("✅ All environment configurations are valid!");
      process.exit(0);
    } else {
      console.log("❌ Some environment configurations have issues");
      console.log("\nTip: Create missing files from .env.example:");
      console.log("  cp .env.example .env.stg");
      console.log("  cp .env.example .env.prod");
      console.log("  cp .env.example .env.ca");
      process.exit(1);
    }
  }
}

// Run verification
main();
