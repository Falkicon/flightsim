# Flightsim – Agent Documentation

Technical reference for AI agents modifying this addon.

For shared patterns, library references, and development guides, see **[Mechanic](../Mechanic/AGENTS.md)**.

---

## Project Intent

A lightweight replacement for a specific WeakAuras use-case:

- Flight speed display with color gradient
- Acceleration indicator
- Skyriding ability cooldown/charge tracking (Surge Forward, Second Wind, Whirling Surge)

**Stack:** Ace3 for database/config, FenCore for pure logic domains.

---

## Architecture (AFD Pattern)

Flightsim follows **Adapter-Framework-Domain** separation:

```
Logic/              Pure domain logic (no WoW APIs)
  ├── init.lua              Namespace setup
  ├── speed.lua             Speed calculations
  ├── acceleration.lua      Acceleration state machine
  ├── color.lua             Color gradients and palettes
  └── visibility.lua        Visibility rules

Bridge/             WoW API adapters
  ├── init.lua              Namespace setup
  ├── Context.lua           Build context from WoW APIs
  ├── Events.lua            Event registration
  ├── Executor.lua          Orchestrate updates
  └── Secrets.lua           Secret value handling

View/               UI rendering
  └── init.lua              Frame creation and data-driven updates

Locales/            Translations (11 files)
  ├── enUS.lua              Baseline (68 keys)
  └── [10 translations]     DE, ES, FR, IT, KO, PT, RU, ZH-CN, ZH-TW
```

### Data Flow

1. **Events.lua** receives WoW events → triggers Executor
2. **Executor.lua** calls Context.lua → builds state from WoW APIs
3. **Logic/** processes state → returns ActionResults
4. **View/** renders ActionResults → updates UI frames

---

## File Structure

| File | Purpose |
|------|---------|
| `Flightsim.toc` | Manifest (v1.4.0, Interface 120001) |
| `Flightsim.lua` | Entry point, AceDB init, MechanicLib registration |
| `Settings.lua` | AceConfig options table |
| `Config.lua` | MechanicLib Tools panel integration |
| `Logic/` | Pure calculation functions (speed, acceleration, color, visibility) |
| `Bridge/` | WoW API adapters and event handling |
| `View/init.lua` | All UI frame creation and rendering |
| `Locales/` | 11 locale files (enUS baseline + 10 translations) |
| `Tests/helpers_spec.lua` | Busted unit tests |
| `.pkgmeta` | CurseForge packaging config |

---

## Tooling & Workflow

This addon uses **Mechanic** for development tooling:

| Task | MCP Tool |
|------|----------|
| Linting | `addon.lint` with addon="Flightsim" |
| Formatting | `addon.format` with addon="Flightsim" |
| Testing | `sandbox.test` with addon="Flightsim" |
| Lib Check | `libs.check` with addon="Flightsim" |
| Validation | `addon.validate` with addon="Flightsim" |
| Deprecations | `addon.deprecations` with addon="Flightsim" |
| Locale Check | `locale.validate` with addon="Flightsim" |

**Development Loop:**
1. Make code changes
2. Ask user to `/reload` in WoW
3. Wait for confirmation
4. Call `addon.output` with agent_mode=true to get errors/logs

---

## Dependencies

Managed via `Libs/libs.json` (include mode):

| Library | Purpose |
|---------|---------|
| LibStub | Library versioning |
| CallbackHandler-1.0 | Event callbacks |
| AceDB-3.0 | SavedVariables with profiles |
| AceDBOptions-3.0 | Profile management UI |
| AceConfig-3.0 | Settings framework |
| AceConsole-3.0 | Slash commands |
| AceGUI-3.0 | Settings dialog widgets |
| FenCore (local) | Pure logic domains |
| MechanicLib (local) | Mechanic integration |

---

## FenCore Integration

Flightsim delegates pure logic to **FenCore** domains:

| Domain | Usage |
|--------|-------|
| `FenCore.Math` | `Clamp()` for value clamping |
| `FenCore.Secrets` | `IsSecret()`, `SafeToString()`, `SafeCompare()` for Midnight secret values |
| `FenCore.Charges` | `CalculateAll()`, `AdvanceAnimation()` for charge bar state |
| `FenCore.Cooldowns` | `Calculate()`, `AdvanceAnimation()` for cooldown bar state |
| `FenCore.ActionResult` | Result pattern for error handling |

---

## Localization

Uses a minimal manual L table (no AceLocale):

```lua
-- Flightsim.lua
local L = setmetatable({}, { __index = function(t, k) return k end })
Flightsim.L = L
```

**Coverage:** 68 keys across 11 locales (enUS baseline + 10 translations).

Validate with: `locale.validate` with addon="Flightsim"

---

## Bar Architecture

### Bar Order (top to bottom)

1. Speed bar (with sustainable marker)
2. Acceleration bar (thin, no gap from speed bar)
3. Surge Forward (6 charge sections, blue gradient)
4. Second Wind (3 charge sections, purple gradient) – dims when Surge Forward full
5. Whirling Surge (cooldown bar, cyan gradient)

### Ability Identifiers

| Ability | Spell ID | Type |
|---------|----------|------|
| Surge Forward | 372608 | 6 charges |
| Second Wind | 425782 | 3 charges |
| Whirling Surge | 361584 | 30s cooldown |

### Custom Colors

All bar colors are user-configurable in Settings. The View layer applies brightness dimming (0.3x) for inactive states.

---

## Visibility Rules

- Default: hide when NOT skyriding
- Do not show during old-style flying (Steady Flight)
- Steady Flight Detection: check `canGlide` from `C_PlayerInfo.GetGlidingInfo()`
- Hide ability bars when spell APIs are restricted (combat/restricted zones)
- Container height dynamically adjusts based on visible bars

---

## Performance Patterns

- Adaptive throttling: 20Hz when visible, 0.2Hz when hidden
- Event-driven visibility via `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`, `UPDATE_SHAPESHIFT_FORMS`
- Frame-level caching for skyriding detection

---

## SavedVariables

- **Root**: `FlightsimDB`
- Treat `FlightsimDB.profile` as the stable contract
- Always add new settings as optional keys with defaults

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/fs` | Open settings panel |
| `/fs lock` | Lock frame position |
| `/fs unlock` | Unlock frame (drag to move) |
| `/fs scale <0.5-2.0>` | Set UI scale |
| `/fs reset` | Reset position and settings |
| `/fs status` | Show brief status |
| `/fs debug` | Show detailed debug info |

---

## API Notes

### Druid Flight Form Support

- `IsMounted()` returns `false` for druids in Flight Form
- `GetShapeshiftForm()` returns `3` for Travel/Flight Form
- Detection: check both `IsMounted()` OR druid flight form

### Midnight (12.0) API Handling

- **Normal Mode**: `C_Spell.GetSpellCharges` and `C_Spell.GetSpellCooldown` work correctly outside combat
- **Degraded Mode**: When spell APIs return secret values, ability bars use binary Full/Empty state
- **Vigor Removed**: Do NOT use `UnitPower("player", 25)` - Vigor was removed in 11.2.7
- **GetGlidingInfo Unreliable**: May return `false/false` when skyriding; use Surge Forward spell data as fallback
- **Secret Value Handling**: Bridge/Secrets.lua wraps all secret-sensitive operations

---

## CurseForge Deployment

- **Project ID**: `1403044`
- **Project URL**: https://www.curseforge.com/wow/addons/flightsim

| Git Action | CurseForge Release |
|------------|-------------------|
| Push to main (no tag) | Alpha |
| Tag with "alpha" | Alpha |
| Tag with "beta" | Beta |
| Clean tag (e.g., `1.4.0`) | Release |

---

## Decisions Log

| Date | Decision |
|------|----------|
| 2025-12-11 | Start as standalone (no AceAddon) to keep surface area small |
| 2025-12-11 | Use spell IDs as stable identifiers |
| 2025-12-12 | Druid Flight Form support via GetShapeshiftForm() check |
| 2025-12-13 | Midnight: Use issecretvalue() to detect combat secrets |
| 2025-12-19 | Explicit Steady Flight detection via GetGlidingInfo.canGlide |
| 2025-12-19 | Global GetSpellInfo removal and pcall guards for mode transitions |
| 2026-01-03 | AFD architecture refactor: Logic/Bridge/View layer separation |
| 2026-01-03 | FenCore migration: delegate to Math, Secrets, Charges, Cooldowns domains |
| 2026-01-04 | Full localization: 10 language translations (68 keys each) |
| 2026-01-04 | Removed AceAddon-3.0 (unused), removed legacy UI.lua |
| 2026-01-04 | Custom ability colors with user-configurable palettes |
