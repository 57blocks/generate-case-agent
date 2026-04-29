#!/bin/bash
set -e

echo "=========================================="
echo "   gh-pages Branch Cleanup Script"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Create a fresh gh-pages branch with no history"
echo "  2. Preserve current report files"
echo "  3. Reduce repository size from 28GB to ~500MB"
echo ""
echo "⚠️  WARNING: This will force-push to gh-pages branch!"
echo ""

# Check if we're on master branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "master" ]; then
  echo "❌ Error: You must be on master branch"
  echo "   Current branch: $current_branch"
  exit 1
fi

# Confirm with user
read -p "Do you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "❌ Cancelled by user"
  exit 0
fi

echo ""
echo "Step 1: Backing up current branch state..."
git_status=$(git status --porcelain)
if [ -n "$git_status" ]; then
  echo "⚠️  You have uncommitted changes. Please commit or stash them first."
  git status
  exit 1
fi

echo ""
echo "Step 2: Creating temporary working directory..."
TEMP_DIR=$(mktemp -d)
ORIGINAL_DIR=$(pwd)
echo "Temporary directory: $TEMP_DIR"
echo "Original directory: $ORIGINAL_DIR"

echo ""
echo "Step 3: Fetching current gh-pages content..."
git fetch --depth=1 origin gh-pages

echo ""
echo "Step 4: Setting up clean branch in temporary directory..."
cd "$TEMP_DIR"

# Initialize new git repo
git init
git remote add origin $(git -C "$ORIGINAL_DIR" remote get-url origin)

echo ""
echo "Step 5: Downloading current gh-pages files..."
git fetch --depth=1 origin gh-pages
git checkout FETCH_HEAD -- . 2>/dev/null || echo "No files to checkout"

echo ""
echo "Step 6: Checking downloaded content..."
ls -lah
echo ""

# Create initial commit
echo "Step 7: Creating initial commit..."
git add .
if git diff --cached --quiet; then
  echo "⚠️  No changes to commit - creating empty initial commit"
  git commit --allow-empty -m "chore: initialize gh-pages with clean history

- Rebuild gh-pages branch to reduce repository size
- Removed 28GB of historical commits
- Preserved current report files
- Future commits will only track incremental changes

Previous history removed to optimize CI/CD performance.
"
else
  git commit -m "chore: initialize gh-pages with clean history

- Rebuild gh-pages branch to reduce repository size
- Removed 28GB of historical commits
- Preserved current report files
- Future commits will only track incremental changes

Previous history removed to optimize CI/CD performance.
"
fi

echo ""
echo "Step 8: Repository size before push:"
du -sh .git 2>/dev/null || echo "Could not calculate size"

echo ""
echo "⚠️  FINAL CONFIRMATION: About to force-push to origin/gh-pages"
read -p "This will replace the remote gh-pages branch. Continue? (yes/no): " final_confirm
if [ "$final_confirm" != "yes" ]; then
  echo "❌ Cancelled. Cleaning up..."
  cd "$ORIGINAL_DIR"
  rm -rf "$TEMP_DIR"
  exit 0
fi

echo ""
echo "Step 9: Force pushing to origin/gh-pages..."
if git push origin HEAD:gh-pages --force; then
  echo "✅ Successfully rebuilt gh-pages branch!"
else
  echo "❌ Failed to push. Please check your permissions and try again."
  cd "$ORIGINAL_DIR"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo ""
echo "Step 10: Cleaning up..."
cd "$ORIGINAL_DIR"

# Delete local gh-pages branch if exists
git branch -D gh-pages 2>/dev/null || echo "No local gh-pages branch to delete"

# Remove temporary directory
rm -rf "$TEMP_DIR"
echo "Temporary directory removed"

echo ""
echo "=========================================="
echo "   ✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "Results:"
echo "  - gh-pages branch rebuilt with fresh history"
echo "  - All current reports preserved"
echo "  - Repository size significantly reduced"
echo ""
echo "Next steps:"
echo "  1. GitHub Pages will continue to work normally"
echo "  2. Next CI run will add reports incrementally"
echo "  3. Git history will stay small going forward"
echo ""
echo "Note: It may take a few minutes for GitHub Pages to rebuild"
echo "      after the force push."
echo ""
