# GitHub Push & Release Workflow

Carefully review the current state of the project's changes, make appropriate updates, commit, push to GitHub, and optionally create a release tag for CurseForge.

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

## Commit & Push

8. **Stage changes:**
   ```bash
   git add -A
   ```

9. **Commit with descriptive message:**
   ```bash
   git commit -m "Description of changes"
   ```
   - For releases: `git commit -m "Release X.Y.Z: Brief description"`

10. **Push to main:**
    ```bash
    git push origin main
    ```

## CurseForge Release (Optional)

If this should be a formal CurseForge release (not just an alpha):

11. **Create version tag:**
    ```bash
    git tag vX.Y.Z
    ```

12. **Push the tag:**
    ```bash
    git push origin vX.Y.Z
    ```

**Tag naming:**
- Clean release: `v1.0.2` → CurseForge Release
- Alpha: `v1.0.2-alpha` → CurseForge Alpha
- Beta: `v1.0.2-beta` → CurseForge Beta

## Post-Push Verification

13. **Verify push succeeded:**
    ```bash
    git log --oneline -3
    ```

14. **Check CurseForge** (if tagged):
    - Build should appear within a few minutes
    - Verify version string is correct
