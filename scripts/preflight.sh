#!/bin/bash
# Playwright Test Harness — preflight check
# Run this from your TARGET PROJECT root before triggering the harness.
# Usage:
#   bash scripts/preflight.sh           # human-readable report (default)
#   bash scripts/preflight.sh --json    # machine-readable JSON (used by add-test agent Step 0)

set -u

MODE="human"
if [ "${1:-}" = "--json" ]; then
  MODE="json"
fi

ERRORS=0
WARNINGS=0
PASSES=0

# Findings: each entry is "level|key|message"
FINDINGS=()

note_pass()    { FINDINGS+=("pass|$1|$2");    PASSES=$((PASSES+1)); }
note_warn()    { FINDINGS+=("warn|$1|$2");    WARNINGS=$((WARNINGS+1)); }
note_error()   { FINDINGS+=("error|$1|$2");   ERRORS=$((ERRORS+1)); }
note_info()    { FINDINGS+=("info|$1|$2"); }

# ── 1. Playwright config ─────────────────────────────────────────────────────
if ls playwright.config.* >/dev/null 2>&1; then
  CFG=$(ls playwright.config.* | head -1)
  note_pass "playwright_config" "Playwright config found: $CFG"
else
  note_error "playwright_config" "No playwright.config.{ts,js,mjs} at project root. This is not a Playwright project."
fi

if [ -f "playwright.test-only.config.ts" ] || [ -f "playwright.test-only.config.js" ]; then
  note_pass "test_only_config" "Single-test config found (used by scripts/test-quick.sh)."
else
  note_warn "test_only_config" "No playwright.test-only.config.ts found. test-runner will use the main config — slower because globalSetup/globalTeardown runs every iteration."
fi

# ── 2. Fixtures file (Page Object injection) ─────────────────────────────────
FIXTURES_CANDIDATES=$(find . -maxdepth 4 -type f \( -name "fixtures.ts" -o -name "fixtures.js" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -3)

if [ -n "$FIXTURES_CANDIDATES" ]; then
  FIXTURES_FILE=$(echo "$FIXTURES_CANDIDATES" | head -1)
  # Try to extract exported fixture names
  FIXTURE_NAMES=$(grep -oE '[a-zA-Z_]+Page' "$FIXTURES_FILE" 2>/dev/null | sort -u | head -10 | tr '\n' ',' | sed 's/,$//' || true)
  if [ -n "$FIXTURE_NAMES" ]; then
    note_pass "fixtures" "Fixtures file: $FIXTURES_FILE (detected: $FIXTURE_NAMES)"
  else
    note_pass "fixtures" "Fixtures file: $FIXTURES_FILE (couldn't auto-detect fixture names)"
  fi
else
  note_warn "fixtures" "No fixtures.ts found. Generated tests assume Page Objects are injected via fixtures (async ({ pageA }) => {}). Without it, coder will fall back to manual instantiation."
fi

# ── 3. Role / constants enum ─────────────────────────────────────────────────
CONSTS_FILE=""
for cand in utils/constants.ts tests/constants.ts e2e/constants.ts src/constants.ts; do
  if [ -f "$cand" ]; then CONSTS_FILE="$cand"; break; fi
done

if [ -n "$CONSTS_FILE" ]; then
  ROLE_ENUM=$(grep -E "^(export )?(const |enum )RoleName" "$CONSTS_FILE" 2>/dev/null | head -1 || true)
  if [ -n "$ROLE_ENUM" ]; then
    ROLES=$(grep -oE '[A-Z][A-Z_0-9]+\s*[:=]' "$CONSTS_FILE" 2>/dev/null | head -8 | sed 's/[ :=].*//' | tr '\n' ',' | sed 's/,$//' || true)
    note_pass "roles" "Role enum: $CONSTS_FILE (sample roles: $ROLES)"
  else
    note_warn "roles" "Found $CONSTS_FILE but no RoleName enum detected. Architect will need user-supplied role mapping."
  fi
else
  note_warn "roles" "No constants.ts found. Generated tests use test.use({ loginRole: RoleName.X }) — without an enum the coder will need user clarification."
fi

# ── 4. Page Object directory convention ──────────────────────────────────────
PAGES_DIRS=""
for cand in pages tests/pageObjects e2e/pages src/pages tests/pages; do
  if [ -d "$cand" ]; then PAGES_DIRS="$PAGES_DIRS $cand"; fi
done
PAGES_DIRS=$(echo "$PAGES_DIRS" | sed 's/^ //')

if [ -n "$PAGES_DIRS" ]; then
  PO_COUNT=0
  for d in $PAGES_DIRS; do
    c=$(find "$d" -name "*.ts" -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
    PO_COUNT=$((PO_COUNT + c))
  done
  note_pass "page_objects" "Page Object directories: $PAGES_DIRS ($PO_COUNT .ts files)"
else
  note_warn "page_objects" "No standard Page Object directory (pages/, tests/pageObjects/, e2e/pages/) found. Architect will have to invent file placement — generated tests may end up scattered."
fi

# ── 5. Test directory ────────────────────────────────────────────────────────
TEST_DIRS=""
for cand in tests e2e __tests__; do
  if [ -d "$cand" ]; then TEST_DIRS="$TEST_DIRS $cand"; fi
done
TEST_DIRS=$(echo "$TEST_DIRS" | sed 's/^ //')

if [ -n "$TEST_DIRS" ]; then
  SPEC_COUNT=0
  for d in $TEST_DIRS; do
    c=$(find "$d" -name "*.spec.ts" -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
    SPEC_COUNT=$((SPEC_COUNT + c))
  done
  if [ "$SPEC_COUNT" -gt 0 ]; then
    note_pass "tests" "Test directories: $TEST_DIRS ($SPEC_COUNT .spec.ts files)"
  else
    note_warn "tests" "Test directories exist ($TEST_DIRS) but contain no .spec.ts files. Coder has no neighboring test to learn import conventions from."
  fi
else
  note_warn "tests" "No tests/ or e2e/ directory found. Coder cannot learn import conventions from neighboring specs."
fi

# ── 6. CLAUDE.md ─────────────────────────────────────────────────────────────
if [ -f "CLAUDE.md" ]; then
  WC=$(wc -l < "CLAUDE.md" | tr -d ' ')
  if [ "$WC" -ge 20 ]; then
    note_pass "claude_md" "CLAUDE.md present ($WC lines)."
  else
    note_warn "claude_md" "CLAUDE.md exists but is very short ($WC lines). Consider documenting project structure, conventions, role list."
  fi
else
  note_warn "claude_md" "No CLAUDE.md at project root. Recommended: write one describing project structure and conventions — agents read it before designing a test."
fi

# ── 7. coding-rules.md ───────────────────────────────────────────────────────
if [ -f ".claude/context/coding-rules.md" ] || [ -f ".claude/coding-rules.md" ]; then
  RULES_FILE=".claude/context/coding-rules.md"
  [ -f ".claude/coding-rules.md" ] && RULES_FILE=".claude/coding-rules.md"
  note_pass "coding_rules" "Coding rules: $RULES_FILE"
else
  note_warn "coding_rules" "No .claude/context/coding-rules.md or .claude/coding-rules.md found. Architect will fall back to CLAUDE.md only. Recommended: copy the harness template and adapt to your UI library."
fi

# ── 8. MCP Playwright server ─────────────────────────────────────────────────
MCP_FOUND=""
for cand in .mcp.json "$HOME/.claude/mcp.json" "$HOME/.config/claude/mcp.json"; do
  if [ -f "$cand" ]; then
    if grep -qE 'playwright' "$cand" 2>/dev/null; then
      MCP_FOUND="$cand"; break
    fi
  fi
done

if [ -n "$MCP_FOUND" ]; then
  note_pass "mcp_playwright" "MCP Playwright configured: $MCP_FOUND"
else
  note_warn "mcp_playwright" "MCP Playwright server not detected. Architect's selector validation falls back to guessing from existing code — accuracy drops noticeably. Configure via .mcp.json or ~/.claude/mcp.json."
fi

# ── 9. Harness scripts ───────────────────────────────────────────────────────
MISSING_SCRIPTS=""
for s in scripts/test-quick.sh scripts/typecheck.sh scripts/lint-patterns.sh scripts/cleanup-artifacts.sh; do
  [ -x "$s" ] || MISSING_SCRIPTS="$MISSING_SCRIPTS $s"
done
if [ -z "$MISSING_SCRIPTS" ]; then
  note_pass "harness_scripts" "All harness helper scripts present and executable."
else
  note_error "harness_scripts" "Missing or non-executable harness scripts:$MISSING_SCRIPTS. Did you copy scripts/ from the harness? Run: chmod +x scripts/*.sh"
fi

# ── 10. Harness agents ───────────────────────────────────────────────────────
MISSING_AGENTS=""
for a in add-test test-analyst test-architect test-coder test-runner test-summarizer; do
  [ -f ".claude/agents/$a.md" ] || MISSING_AGENTS="$MISSING_AGENTS $a"
done
if [ -z "$MISSING_AGENTS" ]; then
  note_pass "harness_agents" "All 6 harness agents present in .claude/agents/."
else
  note_error "harness_agents" "Missing harness agents:$MISSING_AGENTS"
fi

# ── Output ───────────────────────────────────────────────────────────────────
if [ "$MODE" = "json" ]; then
  printf '{\n  "errors": %d,\n  "warnings": %d,\n  "passes": %d,\n  "findings": [\n' "$ERRORS" "$WARNINGS" "$PASSES"
  FIRST=1
  for f in "${FINDINGS[@]}"; do
    LEVEL="${f%%|*}"; REST="${f#*|}"; KEY="${REST%%|*}"; MSG="${REST#*|}"
    ESC_MSG=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
    [ $FIRST -eq 1 ] || printf ',\n'
    printf '    {"level": "%s", "key": "%s", "message": "%s"}' "$LEVEL" "$KEY" "$ESC_MSG"
    FIRST=0
  done
  printf '\n  ]\n}\n'
  exit 0
fi

# Human-readable report
echo "Playwright Test Harness — Preflight Check"
echo "═════════════════════════════════════════"
echo ""
for f in "${FINDINGS[@]}"; do
  LEVEL="${f%%|*}"; REST="${f#*|}"; KEY="${REST%%|*}"; MSG="${REST#*|}"
  case "$LEVEL" in
    pass)  printf "  ✅ %s\n" "$MSG" ;;
    warn)  printf "  ⚠️  %s\n" "$MSG" ;;
    error) printf "  ❌ %s\n" "$MSG" ;;
    info)  printf "  ℹ️  %s\n" "$MSG" ;;
  esac
done
echo ""
echo "─────────────────────────────────────────"
printf "  Pass: %d   Warn: %d   Error: %d\n" "$PASSES" "$WARNINGS" "$ERRORS"
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "  ❌ Fix the errors above before triggering the harness."
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "  ⚠️  You can trigger the harness, but expect lower accuracy."
  echo "     See README → 'Placeholders & project contract' for what each warning affects."
  exit 0
else
  echo "  ✅ Ready. Trigger the harness with a screenshot + a phrase like \"add test for TC-050\"."
  exit 0
fi
