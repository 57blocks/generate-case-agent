#!/bin/bash

# ====================================================================
# GitHub Pages Monthly Maintenance Script
# ====================================================================
# Purpose: Periodic cleanup of gh-pages branch history to reduce repo size
# Usage: ./scripts/cleanup-gh-pages-monthly.sh
#
# **MAINTENANCE SCHEDULE**: Run this script every 4-6 weeks
#
# This script replaces the automated cleanup that was removed from
# the CI workflow to prevent duplicate GitHub Pages builds.
#
# Run this script manually when:
# - gh-pages branch history grows too large (>50 commits)
# - Repository size becomes a concern
# - You want to reset the git history while preserving all reports
#
# **Key Difference from cleanup-gh-pages.sh:**
# - cleanup-gh-pages.sh: One-time full rebuild (for major cleanup)
# - cleanup-gh-pages-monthly.sh: Regular maintenance (squash history periodically)
# ====================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  GitHub Pages History Cleanup Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if we're in the correct directory
if [ ! -f "package.json" ] || [ ! -d ".github" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo "Current directory: $(pwd)"
  exit 1
fi

# Check if gh-pages branch exists
if ! git ls-remote --heads origin gh-pages | grep -q gh-pages; then
  echo -e "${YELLOW}Warning: gh-pages branch not found on remote${NC}"
  echo "This might be the first deployment or the branch doesn't exist yet."
  exit 0
fi

echo -e "${GREEN}Step 1: Fetching gh-pages branch${NC}"
echo "----------------------------------------------"
git fetch origin gh-pages:refs/remotes/origin/gh-pages --depth=1000 || {
  echo -e "${RED}Failed to fetch gh-pages branch${NC}"
  exit 1
}

# Get commit count
commit_count=$(git rev-list --count origin/gh-pages 2>/dev/null || echo "0")
echo "Current commits in gh-pages: ${commit_count}"
echo ""

# Check if cleanup is needed
CLEANUP_THRESHOLD=50

if [ "$commit_count" -le "$CLEANUP_THRESHOLD" ]; then
  echo -e "${GREEN}✓ Commit count ($commit_count) is below threshold ($CLEANUP_THRESHOLD)${NC}"
  echo "Cleanup not needed. Exiting."
  exit 0
fi

echo -e "${YELLOW}⚠ Commit count ($commit_count) exceeds threshold ($CLEANUP_THRESHOLD)${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}This will squash all gh-pages history into 1 commit.${NC}"
echo -e "${YELLOW}All report files will be preserved, only git history will be removed.${NC}"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo -e "${GREEN}Step 2: Checking out gh-pages branch${NC}"
echo "----------------------------------------------"

# Create temporary directory for cleanup
TEMP_DIR=$(mktemp -d)
echo "Working in temporary directory: $TEMP_DIR"

cd "$TEMP_DIR"
git clone --branch gh-pages --single-branch $(git -C "$OLDPWD" remote get-url origin) gh-pages-cleanup || {
  echo -e "${RED}Failed to clone gh-pages branch${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
}

cd gh-pages-cleanup

echo ""
echo -e "${GREEN}Step 3: Analyzing current reports${NC}"
echo "----------------------------------------------"

# List all report directories
echo "Current report directories:"
for dir in html-all html-poc html-democase html-connectors allure allure-history index.html; do
  if [ -e "$dir" ]; then
    if [ -d "$dir" ]; then
      size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      file_count=$(find "$dir" -type f | wc -l | tr -d ' ')
      echo "  ✓ $dir ($size, $file_count files)"
    else
      size=$(du -h "$dir" 2>/dev/null | cut -f1)
      echo "  ✓ $dir ($size)"
    fi
  fi
done

echo ""
echo -e "${GREEN}Step 4: Creating orphan branch (squashing history)${NC}"
echo "----------------------------------------------"

# Configure git
git config user.name "GitHub Pages Cleanup"
git config user.email "cleanup@github.com"

# Create orphan branch from current HEAD
git checkout --orphan temp-cleanup || {
  echo -e "${RED}Failed to create orphan branch${NC}"
  cd "$OLDPWD"
  rm -rf "$TEMP_DIR"
  exit 1
}

# Stage all files
git add -A

# Create squashed commit
commit_message="chore: squashed gh-pages history - keeping only current reports

Current reports preserved:
$(for dir in html-all html-poc html-democase html-connectors allure allure-history; do
  [ -d "$dir" ] && echo "  - $dir ($(du -sh $dir 2>/dev/null | cut -f1))"
done)

Previous commits: $commit_count → 1
This cleanup preserves all current report files while removing git history.

🧹 Manual cleanup using scripts/cleanup-gh-pages-monthly.sh"

git commit -m "$commit_message" || {
  echo -e "${RED}Failed to create commit${NC}"
  cd "$OLDPWD"
  rm -rf "$TEMP_DIR"
  exit 1
}

# Replace gh-pages with the new orphan commit
git branch -D gh-pages
git branch -m gh-pages

echo ""
echo -e "${GREEN}Step 5: Pushing cleaned branch to remote${NC}"
echo "----------------------------------------------"
echo -e "${YELLOW}This will force push to gh-pages branch${NC}"
echo ""
read -p "Proceed with force push? (yes/no): " push_confirm

if [ "$push_confirm" != "yes" ]; then
  echo "Push cancelled. Cleaning up temporary directory."
  cd "$OLDPWD"
  rm -rf "$TEMP_DIR"
  exit 0
fi

# Push with force
max_retries=3
retry=0

while [ $retry -lt $max_retries ]; do
  if git push origin gh-pages --force; then
    echo ""
    echo -e "${GREEN}✓ Successfully cleaned gh-pages history${NC}"
    echo -e "${GREEN}  Before: $commit_count commits${NC}"
    echo -e "${GREEN}  After: 1 commit${NC}"
    echo -e "${GREEN}  All reports preserved${NC}"
    break
  else
    retry=$((retry + 1))
    if [ $retry -lt $max_retries ]; then
      echo -e "${YELLOW}Push failed, retrying ($retry/$max_retries)...${NC}"
      sleep 3
      git fetch origin gh-pages
    else
      echo -e "${RED}Failed to push after $max_retries attempts${NC}"
      cd "$OLDPWD"
      rm -rf "$TEMP_DIR"
      exit 1
    fi
  fi
done

# Cleanup
echo ""
echo -e "${GREEN}Step 6: Cleaning up${NC}"
echo "----------------------------------------------"
cd "$OLDPWD"
rm -rf "$TEMP_DIR"
echo "Temporary directory removed"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Cleanup completed successfully!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Summary:"
echo "  • Git history: $commit_count commits → 1 commit"
echo "  • All report files preserved"
echo "  • Repository size reduced"
echo ""
echo "Note: GitHub Pages will rebuild once (this is normal and expected)"
echo ""
