# Flightsim – Agent Notes

## Project intent

A lightweight replacement for a specific WeakAuras use-case:

- Flight speed display with color gradient
- Acceleration indicator
- Skyriding ability cooldown/charge tracking (Surge Forward, Second Wind, Whirling Surge)

## Constraints

- Must work on Retail 11.2.7+
- Must be resilient to Midnight API pruning, especially in combat
- Prefer simple native APIs; standalone addon with no external dependencies

## Current status

**Fully functional MVP:**

- Speed bar with sustainable speed marker
- Acceleration bar
- Surge Forward charge bars (6 charges) – blue (#74AFFF)
- Second Wind charge bars (3 charges) – purple (#D379EF)
- Whirling Surge cooldown bar (30s) – cyan (#4AC7D4)
- Bars dim when Surge Forward at max charges (6/6)
- Blizzard Settings panel integration
- Slash commands for all settings
- Performance optimized: ~150k memory, <0.15 ms/s CPU when idle

## Bar order (top to bottom)

1. Speed bar (with sustainable marker)
2. Acceleration bar (thin, no gap from speed bar)
3. Surge Forward (6 charge sections, blue #74AFFF)
4. Second Wind (3 charge sections, purple #D379EF) – dims when Surge Forward full
5. Whirling Surge (cooldown bar, cyan #4AC7D4)

## Flightsim conventions

### SavedVariables

- Root: `FlightsimDB`
- Treat `FlightsimDB.profile` as the stable contract
- Always add new settings as optional keys with defaults (never hard-require migrations)
- Migration pattern: check for old key, copy to new key, delete old key

### Ability identifiers

Confirmed spell IDs for 11.2.7:

| Ability        | Spell ID | Type                                  |
| -------------- | -------- | ------------------------------------- |
| Surge Forward  | 372608   | 6 charges (dims all bars when at max) |
| Second Wind    | 425782   | 3 charges                             |
| Whirling Surge | 361584   | 30s cooldown                          |

- User-facing names can be matched loosely via slash commands
- Stored identifiers use spellID for stability
- If resolution fails, UI degrades gracefully (shows `--`, avoids Lua errors)

### Visibility rules

- Default: hide when NOT skyriding
- Do not show during old-style flying
- Hide ability bars when spell APIs are restricted (combat/restricted zones)
- Skyriding detection is conservative; if uncertain, prefer hiding
- Uses `C_PlayerInfo.GetGlidingInfo()` with pcall wrapper
- Early `IsMounted()` check for fast visibility detection

### Performance patterns

- Adaptive throttling: 20Hz when visible, 0.2Hz when hidden
- Event-driven visibility via `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`
- Frame-level caching for `IsSkyridingActive()` to avoid repeated pcalls
- Reusable tables for cooldown results (no per-frame allocations)
- Cache invalidation on mount events for instant response

### Debugging expectations

- `/fs status` is a short, human-readable health check
- `/fs debug` is a verbose dump intended for issue reports
- Never spam chat during normal operation; debug output is opt-in

## Decisions log

| Date       | Decision                                                 |
| ---------- | -------------------------------------------------------- |
| 2025-12-11 | Start as standalone (no Ace3) to keep surface area small |
| 2025-12-11 | Use spell IDs as stable identifiers                      |
| 2025-12-11 | Dim Second Wind bars when Surge Forward at max charges   |
| 2025-12-11 | Rename "optimal" to "sustainable" for clarity            |
| 2025-12-11 | Add opacity setting for sustainable speed marker         |
| 2025-12-12 | Add per-ability bar toggle settings in GUI               |
| 2025-12-12 | Hide ability bars when spell APIs restricted (Midnight)  |
| 2025-12-12 | Performance: adaptive throttling, table reuse, caching   |
| 2025-12-12 | Early IsMounted() check for instant dismount detection   |
| 2025-12-12 | Druid Flight Form support via GetShapeshiftForm() check  |

## API compatibility notes

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

Critical APIs for skyriding detection:

- `C_PlayerInfo.GetGlidingInfo()` – returns `isGliding, canGlide, forwardSpeed`
- `C_Spell.GetSpellCooldown()` – cooldown info
- `C_Spell.GetSpellCharges()` – charge info

### Druid Flight Form Support

Druid Flight Form (Travel Form while flying) requires special handling:

- `IsMounted()` returns `false` for druids in Flight Form (it's a shapeshift, not a mount)
- `GetShapeshiftForm()` returns `3` for Travel/Flight Form on druids
- `C_PlayerInfo.GetGlidingInfo()` works correctly for druids doing dynamic flight
- Detection logic: check both `IsMounted()` OR druid flight form before querying gliding APIs

## File structure

| File             | Purpose                    | Lines |
| ---------------- | -------------------------- | ----- |
| `flightsim.toc`  | Manifest                   | ~15   |
| `Flightsim.lua`  | Init, defaults, migrations | ~80   |
| `UI.lua`         | All UI logic               | ~1280 |
| `Config.lua`     | Slash commands             | ~180  |
| `SettingsUI.lua` | Settings panel             | ~485  |

## Future considerations

- Additional ability tracking (if useful abilities identified)
- Per-mount or per-zone profiles (if requested)
- Minimap button (currently slash-only)
- Combat logging integration (post-Midnight, if APIs stabilize)
