# Flightsim – Agent Documentation

Technical reference for AI agents modifying this addon.

For shared patterns, library references, and development guides, see **[ADDON_DEV/AGENTS.md](../ADDON_DEV/AGENTS.md)**.

---

## Project Intent

A lightweight replacement for a specific WeakAuras use-case:

- Flight speed display with color gradient
- Acceleration indicator
- Skyriding ability cooldown/charge tracking (Surge Forward, Second Wind, Whirling Surge)

**Note:** Standalone addon with no external dependencies (no Ace3).

---

## File Structure

| File | Purpose |
|------|---------|
| `flightsim.toc` | Manifest |
| `Flightsim.lua` | Init, defaults, migrations, localization setup |
| `Locales/enUS.lua` | Base English locale strings |
| `UI.lua` | All UI logic |
| `Config.lua` | Slash commands |
| `SettingsUI.lua` | Settings panel |
| `Tests/helpers_spec.lua` | Unit tests for pure functions |
| `.pkgmeta` | CurseForge packaging config |

---

## Tooling & Workflow

This addon follows the standard `ADDON_DEV` tooling workflow:

| Task | Command |
|------|---------|
| Linting | `@lint` or `powershell -File "_dev_\ADDON_DEV\Tools\LintingTool\lint.ps1" -Addon Flightsim` |
| Formatting | `@format` or `powershell -File "_dev_\ADDON_DEV\Tools\Formatter\format.ps1" -Addon Flightsim` |
| Testing | `@test` or `powershell -File "_dev_\ADDON_DEV\Tools\TestRunner\run_tests.ps1" -Addon Flightsim` |

---

## Localization

Since Flightsim is standalone (no Ace3), it uses a minimal manual implementation:

```lua
-- Flightsim.lua
local L = setmetatable({}, { __index = function(t, k) return k end })
Flightsim.L = L
```

Localizable strings are defined in `Locales/enUS.lua` and should be accessed via `Flightsim.L["KEY"]`.

---

## Testing

Pure utility functions (Clamp, Color functions, etc.) are refactored into `FlightsimUI.Utils` for testability and covered by Busted tests in `Tests/helpers_spec.lua`.

---

## Architecture

### Bar Order (top to bottom)

1. Speed bar (with sustainable marker)
2. Acceleration bar (thin, no gap from speed bar)
3. Surge Forward (6 charge sections, blue #74AFFF)
4. Second Wind (3 charge sections, purple #D379EF) – dims when Surge Forward full
5. Whirling Surge (cooldown bar, cyan #4AC7D4)

### Ability Identifiers

| Ability | Spell ID | Type |
|---------|----------|------|
| Surge Forward | 372608 | 6 charges (dims all bars when at max) |
| Second Wind | 425782 | 3 charges |
| Whirling Surge | 361584 | 30s cooldown |

### Visibility Rules

- Default: hide when NOT skyriding
- Do not show during old-style flying (Steady Flight)
- Steady Flight Detection: explicitly check `canGlide` from `C_PlayerInfo.GetGlidingInfo()`; if false while mounted, the HUD is disabled.
- Hide ability bars when spell APIs are restricted (combat/restricted zones)
- Uses `C_PlayerInfo.GetGlidingInfo()` with pcall wrapper

### Performance Patterns

- Adaptive throttling: 20Hz when visible, 2Hz when hidden
- Event-driven visibility via `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`, `UPDATE_SHAPESHIFT_FORMS`
- Frame-level caching for `IsSkyridingActive()` to avoid repeated pcalls

---

## SavedVariables

- **Root**: `FlightsimDB`
- Treat `FlightsimDB.profile` as the stable contract
- Always add new settings as optional keys with defaults

---

## Slash Commands

- `/fs` or `/fs help` – Show command list
- `/fs status` – Short, human-readable health check
- `/fs debug` – Verbose dump intended for issue reports

---

## API Notes

### Druid Flight Form Support

- `IsMounted()` returns `false` for druids in Flight Form
- `GetShapeshiftForm()` returns `3` for Travel/Flight Form on druids
- Detection: check both `IsMounted()` OR druid flight form before querying gliding APIs

### Midnight (12.0) API Handling

- **Normal Mode**: `C_Spell.GetSpellCharges` and `C_Spell.GetSpellCooldown` work correctly **outside of combat**.
- **Degraded Mode**: When spell APIs return secret values (typically in combat), all ability bars switch to a binary state (Full/Empty) based on `C_Spell.IsSpellUsable`.
- **Vigor Removed**: The Vigor resource (Power Type 25 / AlternateMount) was removed from the game in 11.2.7. Skyriding now uses direct charges. Do NOT use `UnitPower("player", 25)` - it returns invalid/secret data.
- **GetGlidingInfo Unreliable**: In 12.0+, `C_PlayerInfo.GetGlidingInfo()` may return `false/false` even when skyriding. The addon uses Surge Forward spell data (372608) as a fallback detection method.
- **Arithmetic Protection**: The addon uses `IsSecret()`, `SafeCompare()`, and `SafeToString()` wrappers to avoid Lua errors when arithmetic, comparisons, or formatting are attempted on secret values.
- **Silent Crash Prevention**: All `or` operators on potential secret returns have been replaced with explicit `nil` checks to prevent immediate crashes.
- **API Diagnostic**: Run `/fs testapi` to check the current state of Skyriding APIs.

---

## CurseForge Deployment

- **Project ID**: `1403044`
- **Project URL**: https://www.curseforge.com/wow/addons/flightsim

| Git Action | CurseForge Release |
|------------|-------------------|
| Push to main (no tag) | Alpha |
| Tag with "alpha" | Alpha |
| Tag with "beta" | Beta |
| Clean tag (e.g., `1.0.0`) | Release |

---

## Decisions Log

| Date | Decision |
|------|----------|
| 2025-12-11 | Start as standalone (no Ace3) to keep surface area small |
| 2025-12-11 | Use spell IDs as stable identifiers |
| 2025-12-12 | Druid Flight Form support via GetShapeshiftForm() check |
| 2025-12-13 | Midnight: Use issecretvalue() to detect combat secrets |
| 2025-12-19 | Explicit Steady Flight detection via GetGlidingInfo.canGlide check |
| 2025-12-19 | Global GetSpellInfo removal and pcall guards for mode transitions |
