#!/bin/bash

# Script to optimize Git configuration for faster cloning and pulling
# This script configures Git to skip the gh-pages branch, which contains
# large test report files that aren't needed for development.

set -e

echo "======================================"
echo "Git Configuration Optimization Script"
echo "======================================"
echo ""
echo "This script will:"
echo "  1. Configure Git to skip gh-pages branch (saves ~2GB)"
echo "  2. Remove local gh-pages branch if it exists"
echo "  3. Clean up unreferenced objects"
echo "  4. Make 'git pull' much faster"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if we're in the project root
if [ ! -f "package.json" ] || [ ! -f "playwright.config.ts" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo "Current repository size:"
du -sh .git | awk '{print "  .git directory: " $1}'
echo ""

read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Backing up current git config..."
cp .git/config .git/config.backup
echo "✅ Backup saved to .git/config.backup"

echo ""
echo "Step 2: Removing local gh-pages branch (if exists)..."
if git show-ref --verify --quiet refs/heads/gh-pages; then
    git checkout master 2>/dev/null || git checkout main 2>/dev/null
    git branch -D gh-pages
    echo "✅ Local gh-pages branch removed"
else
    echo "ℹ️  No local gh-pages branch found"
fi

echo ""
echo "Step 3: Configuring remote to skip gh-pages..."
# Remove existing fetch configurations
git config --unset-all remote.origin.fetch || true

# Add specific fetch refspecs (skip gh-pages)
git config --add remote.origin.fetch "+refs/heads/master:refs/remotes/origin/master"
git config --add remote.origin.fetch "+refs/heads/poc-test:refs/remotes/origin/poc-test"

echo "✅ Remote configured to skip gh-pages branch"

echo ""
echo "Step 4: Pruning remote references..."
git fetch --prune
echo "✅ Remote references pruned"

echo ""
echo "Step 5: Removing gh-pages remote reference completely..."
# Remove from refs
rm -f .git/refs/remotes/origin/gh-pages 2>/dev/null || true
# Remove from packed-refs if exists
if [ -f .git/packed-refs ]; then
    sed -i.bak '/refs\/remotes\/origin\/gh-pages/d' .git/packed-refs 2>/dev/null || true
    rm -f .git/packed-refs.bak 2>/dev/null || true
fi
echo "✅ gh-pages reference removed"

echo ""
echo "Step 6: Cleaning up unreferenced objects (this may take a few minutes)..."
git reflog expire --expire-unreachable=now --all
git prune --expire=now
git repack -ad
git prune-packed
echo "✅ Git cleanup complete"

echo ""
echo "Step 7: Verifying configuration..."
echo ""
echo "Current branches:"
git branch -a
echo ""
echo "New repository size:"
du -sh .git | awk '{print "  .git directory: " $1}'

echo ""
echo "======================================"
echo "✅ Optimization Complete!"
echo "======================================"
echo ""
echo "Your repository is now optimized. Benefits:"
echo "  • Faster 'git pull' and 'git fetch'"
echo "  • Smaller .git directory (should be ~200MB instead of ~2GB)"
echo "  • gh-pages reports still accessible online at:"
echo "    https://codeseals.github.io/portal-ui-automation"
echo ""
echo "Note: If you need to access gh-pages branch locally in the future:"
echo "  git fetch origin gh-pages:gh-pages"
echo ""
