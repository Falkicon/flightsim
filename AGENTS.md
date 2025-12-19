# Flightsim – Agent Documentation

Technical reference for AI agents modifying this addon.

## External References

### Development Documentation
For comprehensive addon development guidance, consult these resources:

- **[ADDON_DEV/AGENTS.md](../../ADDON_DEV/AGENTS.md)** – Library index, automation scripts, dependency chains
- **[Addon Development Guide](../../ADDON_DEV/Addon_Dev_Guide/)** – Full documentation covering:
  - Core principles, project structure, TOC best practices
  - UI engineering, configuration UI, combat lockdown
  - Performance optimization, API resilience
  - Debugging, packaging/release workflow
  - Midnight (12.0) compatibility and secret values

### Blizzard UI Source Code
For reverse-engineering, hijacking, or modifying official Blizzard UI frames:

- **[wow-ui-source-live](../../wow-ui-source-live/)** – Official Blizzard UI addon code
  - Use this to understand frame hierarchies, event patterns, and protected frame behavior
  - Reference for Skyriding/mount-related UI components
  - Essential for understanding native cooldown and charge display patterns

---

## Project Intent

A lightweight replacement for a specific WeakAuras use-case:

- Flight speed display with color gradient
- Acceleration indicator
- Skyriding ability cooldown/charge tracking (Surge Forward, Second Wind, Whirling Surge)

## Constraints

- Must work on Retail 11.2.7+
- Must be resilient to Midnight API pruning, especially in combat
- Prefer simple native APIs; standalone addon with no external dependencies

## File Structure

| File | Purpose | Lines |
|------|---------|-------|
| `flightsim.toc` | Manifest | ~15 |
| `Flightsim.lua` | Init, defaults, migrations | ~80 |
| `UI.lua` | All UI logic | ~1300 |
| `Config.lua` | Slash commands | ~180 |
| `SettingsUI.lua` | Settings panel | ~485 |
| `.pkgmeta` | CurseForge packaging config | ~20 |

## Architecture

### Bar Order (top to bottom)

1. Speed bar (with sustainable marker)
2. Acceleration bar (thin, no gap from speed bar)
3. Surge Forward (6 charge sections, blue #74AFFF)
4. Second Wind (3 charge sections, purple #D379EF) – dims when Surge Forward full
5. Whirling Surge (cooldown bar, cyan #4AC7D4)

### Ability Identifiers

Confirmed spell IDs for 11.2.7:

| Ability | Spell ID | Type |
|---------|----------|------|
| Surge Forward | 372608 | 6 charges (dims all bars when at max) |
| Second Wind | 425782 | 3 charges |
| Whirling Surge | 361584 | 30s cooldown |

- User-facing names can be matched loosely via slash commands
- Stored identifiers use spellID for stability
- If resolution fails, UI degrades gracefully (shows `--`, avoids Lua errors)

### Visibility Rules

- Default: hide when NOT skyriding
- Do not show during old-style flying
- Hide ability bars when spell APIs are restricted (combat/restricted zones)
- Skyriding detection is conservative; if uncertain, prefer hiding
- Uses `C_PlayerInfo.GetGlidingInfo()` with pcall wrapper
- Early `IsMounted()` check for fast visibility detection

### Performance Patterns

- Adaptive throttling: 20Hz when visible, 2Hz when hidden
- Event-driven visibility via `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`, `UPDATE_SHAPESHIFT_FORMS`
- Frame-level caching for `IsSkyridingActive()` to avoid repeated pcalls
- Reusable tables for cooldown results (no per-frame allocations)
- Cache invalidation on mount events for instant response

## SavedVariables

- **Root**: `FlightsimDB`
- Treat `FlightsimDB.profile` as the stable contract
- Always add new settings as optional keys with defaults (never hard-require migrations)
- Migration pattern: check for old key, copy to new key, delete old key

## Slash Commands

- `/fs` or `/fs help` – Show command list
- `/fs status` – Short, human-readable health check
- `/fs debug` – Verbose dump intended for issue reports

## Debugging

- `/fs status` is a short, human-readable health check
- `/fs debug` is a verbose dump intended for issue reports
- Never spam chat during normal operation; debug output is opt-in

## API Compatibility Notes

All API calls are wrapped defensively:

```lua
-- Pattern: pcall wrapper with fallback
local function GetSpellCooldownSafe(spellID)
    if not spellID then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and info then return info end
    return nil
end
```

**Critical APIs for skyriding detection:**

- `C_PlayerInfo.GetGlidingInfo()` – returns `isGliding, canGlide, forwardSpeed`
- `C_Spell.GetSpellCooldown()` – cooldown info
- `C_Spell.GetSpellCharges()` – charge info

### Druid Flight Form Support

- `IsMounted()` returns `false` for druids in Flight Form (it's a shapeshift, not a mount)
- `GetShapeshiftForm()` returns `3` for Travel/Flight Form on druids
- `C_PlayerInfo.GetGlidingInfo()` works correctly for druids doing dynamic flight
- Detection logic: check both `IsMounted()` OR druid flight form before querying gliding APIs

### Midnight (12.0) Secret Values

Midnight introduces "secret values" - API returns that are opaque during combat. These cannot be compared, used in arithmetic, or passed to string functions.

**Detection pattern:**

```lua
-- issecretvalue() is a global in Midnight (nil in earlier clients)
local hasSecretValues = issecretvalue and (
    issecretvalue(surgeInfo.maxCharges) or
    issecretvalue(surgeInfo.currentCharges)
)
if hasSecretValues then
    -- Hide bars, skip all processing
end
```

**What works in combat:**

| Ability Type | API | Passthrough? | Notes |
|--------------|-----|--------------|-------|
| Charge-based | `C_Spell.GetSpellCharges` | ✅ Partial | Values are secret, can't read/compare |
| Cooldown-based | `C_Spell.GetSpellCooldown` | ❌ No | Can't calculate elapsed time from secret |
| Aura detection | `C_UnitAuras.*` | ❌ No | Protected function, causes ADDON_BLOCKED |

**Current solution:** Hide all ability bars when secret values detected. Graceful degradation - speed/acceleration bars still work.

## CurseForge Deployment

Automatic packaging is configured via `.pkgmeta` and GitHub webhook.

- **Project ID**: `1403044`
- **Project URL**: https://www.curseforge.com/wow/addons/flightsim

### Release Types

| Git Action | CurseForge Release |
|------------|-------------------|
| Push to main (no tag) | Alpha |
| Tag with "alpha" (e.g., `1.0.0-alpha`) | Alpha |
| Tag with "beta" (e.g., `1.0.0-beta`) | Beta |
| Clean tag (e.g., `1.0.0`) | Release |

### Release Workflow

1. Update version in `flightsim.toc` (e.g., `## Version: 1.0.0`)
2. Update `CHANGELOG.md` with new version entry
3. Commit and push changes
4. Create and push git tag matching the version

## Future Considerations

- Additional ability tracking (if useful abilities identified)
- Per-mount or per-zone profiles (if requested)
- Minimap button (currently slash-only)
- Combat logging integration (post-Midnight, if APIs stabilize)

## Documentation Requirements

**Always update documentation when making changes:**

### CHANGELOG.md
Update the changelog for any change that:
- Adds new features or functionality
- Fixes bugs or issues
- Changes existing behavior
- Modifies settings or configuration options
- Improves performance or stability

**Format** (Keep a Changelog style):
```markdown
## [Version] - YYYY-MM-DD
### Added
- New features

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

### Removed
- Removed features
```

### README.md
Update the README when:
- Adding new features that users should know about
- Changing slash commands or settings
- Modifying installation or usage instructions
- Adding new dependencies or requirements

**Key sections to review**: Features, Slash Commands, Configuration, Technical Notes

## Decisions Log

| Date | Decision |
|------|----------|
| 2025-12-11 | Start as standalone (no Ace3) to keep surface area small |
| 2025-12-11 | Use spell IDs as stable identifiers |
| 2025-12-11 | Dim Second Wind bars when Surge Forward at max charges |
| 2025-12-11 | Rename "optimal" to "sustainable" for clarity |
| 2025-12-12 | Add per-ability bar toggle settings in GUI |
| 2025-12-12 | Hide ability bars when spell APIs restricted (Midnight) |
| 2025-12-12 | Performance: adaptive throttling, table reuse, caching |
| 2025-12-12 | Druid Flight Form support via GetShapeshiftForm() check |
| 2025-12-12 | CurseForge auto-packaging via GitHub webhook |
| 2025-12-13 | Midnight: Use issecretvalue() to detect combat secrets |
| 2025-12-13 | Abandon combat view for now; revisit if APIs improve |

## Library Management

This addon manages its libraries using `update_libs.ps1` located in `Interface\ADDON_DEV`.
**DO NOT** manually update libraries in `Libs`.
Instead, if you need to update libraries, run:
`powershell -File "c:\Program Files (x86)\World of Warcraft\_retail_\Interface\ADDON_DEV\update_libs.ps1"`
