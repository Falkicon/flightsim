# GitHub Pull Request Workflow

Carefully review the current state of the project's changes, make appropriate updates, commit, and submit a PR to GitHub.

## Pre-Flight Checks

1. **Review changes:**
   ```bash
   git status
   git diff
   ```

2. **Verify no unintended changes** - Look for:
   - Debug code left in
   - Commented-out blocks that should be removed
   - Test data that shouldn't be committed

## Documentation Updates

Before committing, ensure these files are updated if needed:

3. **CHANGELOG.md** - Add entry for this version:
   - Use Keep a Changelog format
   - Include version number and date
   - Categorize changes: Added, Changed, Fixed, Removed

4. **README.md** - Update if:
   - New features added
   - Slash commands changed
   - Settings/configuration changed
   - Installation instructions affected

5. **AGENTS.md** - Update if:
   - Architecture changed
   - New files added
   - API patterns changed
   - Decisions made that future agents should know

## Version Bump (For Releases)

6. **Update .toc version** (if this is a release):
   ```
   ## Version: X.Y.Z
   ```

7. **Update .pkgmeta** (if needed):
   - Add new externals
   - Update ignore patterns for new files

## Create Feature Branch (if not already on one)

8. **Create and checkout branch:**
   ```bash
   git checkout -b feature/descriptive-name
   ```

## Commit Changes

9. **Stage changes:**
   ```bash
   git add -A
   ```

10. **Commit with descriptive message:**
    ```bash
    git commit -m "Description of changes"
    ```

## Push & Create PR

11. **Push branch to remote:**
    ```bash
    git push -u origin feature/descriptive-name
    ```

12. **Create PR using GitHub CLI:**
    ```bash
    gh pr create --title "PR Title" --body "## Summary
    - Change 1
    - Change 2

    ## Test plan
    - [ ] Tested in-game
    - [ ] Verified no Lua errors"
    ```

## Post-PR

13. **Note the PR URL** for reference

14. **After PR is merged** (for releases):
    - Checkout main: `git checkout main`
    - Pull latest: `git pull origin main`
    - Create tag: `git tag vX.Y.Z`
    - Push tag: `git push origin vX.Y.Z`

## CurseForge Release Notes

When the PR is merged and you're ready for a CurseForge release:
- The tag push triggers CurseForge packaging
- Clean tags (e.g., `v1.0.2`) create Release builds
- Tags with `-alpha` or `-beta` suffix create corresponding release types
