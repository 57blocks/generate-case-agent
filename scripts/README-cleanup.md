# gh-pages Branch Cleanup Guide

## Available Scripts

**Two cleanup scripts are available for different scenarios:**

1. **`cleanup-gh-pages.sh`** - One-time full rebuild
   - **When to use**: Major cleanup (e.g., reducing 28GB → 500MB)
   - **How it works**: Complete rebuild in temporary directory
   - **Frequency**: Once, or when major cleanup needed
   - **Safe for**: Your local working directory (node_modules, .vscode stay intact)

2. **`cleanup-gh-pages-monthly.sh`** - Regular maintenance
   - **When to use**: Periodic cleanup every 4-6 weeks
   - **How it works**: Squash commits when >50 commits accumulated
   - **Frequency**: Monthly/bi-monthly
   - **Safe for**: Uses temporary directory, no impact on local files

## Problem

The `gh-pages` branch has accumulated **28GB of git history** due to continuous report deployments. This causes:
- Slow CI/CD checkout operations
- High disk space usage on GitHub runners
- Unnecessary bandwidth consumption

## Solution

Clean the gh-pages branch by removing all historical commits while preserving current report files.

## How to Use

### Option 1: Automated Script (Recommended)

Run the cleanup script:

```bash
# Make sure you're on master branch with no uncommitted changes
git checkout master
git status

# Run the cleanup script
./scripts/cleanup-gh-pages.sh
```

The script will:
1. ✅ Create a fresh gh-pages branch with no history in a temporary directory
2. ✅ Download and preserve current report files
3. ✅ Force-push the clean branch to origin
4. ✅ Reduce repository size from 28GB to ~500MB
5. ✅ Keep your local working directory intact (node_modules, .vscode, etc.)

### Option 2: Manual Cleanup

If you prefer to do it manually:

```bash
# 1. Switch to master and ensure clean state
git checkout master
git status

# 2. Delete local gh-pages branch
git branch -D gh-pages 2>/dev/null || true

# 3. Create new orphan branch (no history)
git checkout --orphan gh-pages-new

# 4. Clear staging area
git rm -rf .

# 5. Download current gh-pages files (without history)
git fetch --depth=1 origin gh-pages
git checkout FETCH_HEAD -- .

# 6. Commit the files
git add .
git commit -m "chore: rebuild gh-pages with clean history"

# 7. Force push to replace remote gh-pages
git push origin gh-pages-new:gh-pages --force

# 8. Clean up
git checkout master
git branch -D gh-pages-new
```

## What Gets Preserved

✅ **Preserved:**
- `/allure/` - Latest Allure report
- `/allure-history/` - Last 5 builds (automatically cleaned by workflow)
- `/html/` - Latest Playwright HTML report (all tests)
- `/html-all/` - Latest Playwright HTML report (all tests)
- `/html-poc/` - Latest POC test report
- `/html-democase/` - Latest Demo Case test report
- `/html-connectors/` - Latest Connectors test report
- `/index.html` - Navigation page

❌ **Removed:**
- All git commit history (reduces from 28GB to current snapshot)
- Old report versions (no longer needed)

## Safety Notes

⚠️ **Important:**
- This operation uses `--force` push to replace remote gh-pages
- Cannot be undone (git history will be permanently deleted)
- Current report files are preserved, so GitHub Pages continues working
- Requires push access to the repository

✅ **Safe because:**
- gh-pages is a deployment branch (not source code)
- Reports are regenerated on every CI run
- Only historical commits are removed, current files are kept
- CI/CD workflow continues to work normally after cleanup

## Expected Results

Before cleanup:
- gh-pages branch: ~28GB git history
- CI checkout time: 2-5 minutes
- Disk space usage: High

After cleanup:
- gh-pages branch: ~500MB (current snapshot only)
- CI checkout time: 10-20 seconds (with `fetch-depth: 1`)
- Disk space usage: Minimal

## Ongoing Maintenance

### Automatic Cleanup (Built into CI/CD)

The workflow already includes automatic cleanup:

1. **Allure History**: Automatically keeps only last 5 builds (line 1871-1890)
2. **Large Files**: Automatically removes videos and large screenshots (line 1862-1868)
3. **Incremental Deployment**: Uses `keep_files: true` to avoid re-uploading unchanged files

### Manual Monthly Maintenance

Run the monthly maintenance script every 4-6 weeks:

```bash
# Check if cleanup is needed (>50 commits)
./scripts/cleanup-gh-pages-monthly.sh
```

The script will:
- Check current commit count in gh-pages branch
- Only proceed if commits exceed threshold (>50)
- Squash all history into 1 commit
- Preserve all current report files
- Work in temporary directory (safe for your local environment)

## Verification

After cleanup, verify the branch:

```bash
# Check branch size
git fetch --depth=1 origin gh-pages
git log FETCH_HEAD --oneline --max-count=5

# Should show only 1 commit (the initial rebuild commit)

# Check reports are accessible
# Visit: https://codeseals.github.io/portal-ui-automation
```

## Troubleshooting

### "Permission denied" error
You need push access to the repository. Contact repository admin.

### "GitHub Pages not updating"
Wait 2-5 minutes for GitHub Pages to rebuild after force push.

### "Reports missing after cleanup"
Check if the files exist:
```bash
git ls-tree --name-only origin/gh-pages
```

If files are missing, the fetch step may have failed. Re-run the cleanup script.

## Questions?

- Check GitHub Actions logs for automated cleanup runs
- Review workflow configuration: `.github/workflows/playwright.yml`
- Contact DevOps team for assistance
