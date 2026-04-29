# Git Repository Optimization Guide

## Problem

The `portal-ui-automation` repository has a large `.git` directory (~2.1GB) that causes:
- Slow initial cloning (several minutes)
- Slow `git pull` operations
- Unnecessary disk space usage

## Root Cause

The `gh-pages` branch contains historical test reports (~2GB):
- 20+ deployment commits
- Each deployment: 200-400MB of HTML/Allure reports
- These reports are **not needed for development**
- Reports are accessible online at: https://codeseals.github.io/portal-ui-automation/

## Solution

Configure Git to **not fetch the gh-pages branch** by default.

### For New Contributors

When cloning the repository:

```bash
# Clone only master branch (fast clone)
git clone --single-branch --branch master https://github.com/codeseals/portal-ui-automation.git
cd portal-ui-automation

# Run optimization script
./scripts/optimize-git-config.sh
```

**Result**: Clone size ~100MB instead of ~2GB

### For Existing Contributors

If you already have the repository cloned:

```bash
# Run optimization script
./scripts/optimize-git-config.sh
```

**Result**: `.git` folder reduced from ~2.1GB to ~200MB

## What the Optimization Does

1. **Removes local gh-pages branch**
   - You don't need it for development
   - Reports are online

2. **Configures fetch refspec**
   - Only fetches `master` and `poc-test` branches
   - Skips `gh-pages` branch

3. **Cleans up Git objects**
   - Removes unreferenced objects
   - Runs `git gc --aggressive`

4. **Makes git operations faster**
   - `git pull`: seconds instead of minutes
   - `git fetch`: only downloads what you need

## Performance Comparison

| Operation | Before Optimization | After Optimization |
|-----------|-------------------|-------------------|
| Initial clone | ~2.1GB, 3-5 min | ~100MB, 30 sec |
| git pull | 1-3 min | 5-10 sec |
| .git folder size | 2.1GB | ~200MB |

## FAQ

### Q: Will I lose access to test reports?

**A:** No! Reports are published to GitHub Pages and accessible at:
- https://codeseals.github.io/portal-ui-automation/

### Q: What if I need to access gh-pages branch locally?

**A:** You can manually fetch it when needed:
```bash
git fetch origin gh-pages:gh-pages
git checkout gh-pages
```

### Q: Will this affect CI/CD?

**A:** No! GitHub Actions always starts with a fresh clone and has access to all branches.

### Q: Can I revert the optimization?

**A:** Yes! Restore the default fetch configuration:
```bash
git config --unset-all remote.origin.fetch
git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch --all
```

### Q: Is it safe to run the optimization script?

**A:** Yes! The script:
- Creates a backup of your `.git/config`
- Shows what it will do before executing
- Asks for confirmation
- Can be reverted if needed

### Q: Will my teammates see these changes?

**A:** The git configuration is **local only**. Each team member needs to run the optimization script themselves. That's why it's documented in the README!

## Technical Details

### Before Optimization

```bash
[remote "origin"]
	url = https://github.com/codeseals/portal-ui-automation.git
	fetch = +refs/heads/*:refs/remotes/origin/*  # Fetches ALL branches
```

### After Optimization

```bash
[remote "origin"]
	url = https://github.com/codeseals/portal-ui-automation.git
	fetch = +refs/heads/master:refs/remotes/origin/master
	fetch = +refs/heads/poc-test:refs/remotes/origin/poc-test
	# gh-pages intentionally excluded
```

## Maintenance

### For Repository Maintainers

The gh-pages branch will continue to grow over time. To keep it manageable:

1. **Automatic cleanup** (removed to prevent duplicate GitHub Pages builds)
   - See: `.github/workflows/playwright.yml` line 1956-1964

2. **Monthly maintenance cleanup** (recommended every 4-6 weeks):
   ```bash
   ./scripts/cleanup-gh-pages-monthly.sh
   ```
   This squashes gh-pages history while keeping current reports.

   **When to use each script:**
   - `cleanup-gh-pages.sh` - One-time full rebuild (major cleanup, e.g., reducing 28GB → 500MB)
   - `cleanup-gh-pages-monthly.sh` - Regular maintenance (squash commits when >50 commits accumulated)

### Monitoring Repository Size

Check current sizes:
```bash
# Master branch size
git checkout master
du -sh .git

# gh-pages branch size (if checked out)
git checkout gh-pages
du -sh .

# Total blob objects
git rev-list --objects --all | \
  git cat-file --batch-check='%(objectsize)' | \
  awk '{sum += $1} END {print "Total:", sum/1024/1024/1024, "GB"}'
```

## Related Files

- `scripts/optimize-git-config.sh` - Main optimization script
- `.github/git-config-template` - Template configuration
- `README.md` - User-facing documentation
- `scripts/cleanup-gh-pages-monthly.sh` - Maintainer cleanup script

## Troubleshooting

### Script fails with "Not in a git repository"

Make sure you're in the project root directory:
```bash
cd /path/to/portal-ui-automation
./scripts/optimize-git-config.sh
```

### Still seeing slow pulls after optimization

1. Check if gh-pages is still being fetched:
   ```bash
   git config --get-all remote.origin.fetch
   ```

2. Verify no gh-pages reference exists:
   ```bash
   git branch -a | grep gh-pages
   ```

3. Force clean:
   ```bash
   git remote prune origin
   git gc --aggressive --prune=now
   ```

### Want to verify the optimization worked

```bash
# Check .git size
du -sh .git

# Should be ~200MB instead of ~2GB

# Check fetched branches
git branch -a

# Should only see master and poc-test
```

## References

- [Git Documentation: Remote Configuration](https://git-scm.com/docs/git-config#Documentation/git-config.txt-remotenamefetch)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Git GC Documentation](https://git-scm.com/docs/git-gc)
