# Flightsim – Agent Documentation

Technical reference for AI agents modifying this addon.

This document describes the current source tree. [flightsim.toc](flightsim.toc) is the source of truth for addon version and client target; [CHANGELOG.md](CHANGELOG.md) separates unreleased work from recorded releases. See [CONTRIBUTING.md](CONTRIBUTING.md) and [CI](docs/ci.md) for standalone development checks.

In the shared development workspace, also read **[Mechanic](../Mechanic/AGENTS.md)** for ecosystem tooling and diagnostic rules. That sibling checkout is optional for isolated Flightsim tests.

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
  ├── pitch.lua             Dormant pitch logic (disabled)
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
  ├── enUS.lua              Baseline (150 keys)
  └── [10 translations]     deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW
```

### Data Flow

1. **Flightsim.lua** initializes AceDB, the View, settings, and optional Mechanic integration after this addon's `ADDON_LOADED` event.
2. **Events.lua** invalidates API caches and refreshes zone/buff state. The View's mount callback resets Executor state and applies visibility immediately.
3. The **View** update loop calls `Executor.FullUpdate()` at the active or idle interval. **Context.lua** builds a reusable context from API adapters and caches.
4. **Executor.lua** calls **Logic/** and FenCore, maintains animation/history state, and returns render data in a reusable ActionResult.
5. **View/** applies visibility and renders the returned data. Settings and profile callbacks update layout, colors, and visibility directly.

Hot-path contexts, result wrappers, and output tables are borrowed mutable storage. Copy any values retained across calls; do not assume an ActionResult always owns a fresh snapshot.

---

## File Structure

| File | Purpose |
|------|---------|
| `flightsim.toc` | Manifest (v1.5.6, Interface 120100; source of truth for versions) |
| `Flightsim.lua` | Entry point, AceDB init, MechanicLib registration |
| `Settings.lua` | AceConfig options table |
| `Config.lua` | Slash subcommand handler and MechanicLib Tools panel |
| `Logic/` | Pure calculation functions (speed, acceleration, color, visibility) |
| `Bridge/` | WoW API adapters and event handling |
| `View/init.lua` | All UI frame creation and rendering |
| `Locales/` | 11 locale files (enUS baseline + 10 translations) |
| `Tests/` | Lua 5.1 domain, bridge, view, and command regressions; run with `lua Tests/run.lua` |
| `.pkgmeta` | CurseForge packaging config |
| `.github/workflows/quality.yml` | Offline checks for pull requests and pushes to `main` |

---

## Tooling & Workflow

This addon supports **Mechanic** development tooling. Use connected MCP tools for ecosystem operations; registry names are shown below (transport names may use dashes). Read `commands.list` for current argument schemas.

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

1. Make changes and run relevant offline checks. The standalone suite is `lua Tests/run.lua` with Lua 5.1; CI also runs Luacheck, StyLua, and `python Tests/validate_repo.py`.
2. For runtime changes, install/sync to the intended client before live verification. A development-tree edit alone does not prove the installed addon changed.
3. Ask the user to `/reload` and wait for explicit confirmation.
4. With Mechanic MCP connected, discover/select the intended diagnostic target and call `addon.output` with `agent_mode=true` and that explicit target. Keep the same target through subsequent diagnostic operations.

If Mechanic MCP is unavailable, use source inspection and isolated offline checks; do not substitute live `mech` CLI operations or claim installed-game validation. Documentation-only changes need path/example checks, not a game reload.

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

The repository embeds these libraries for standalone installation. The full Mechanic addon is optional. In the shared workspace, FenCore is sourced from `../Libs/FenCore`; coordinate changes there and in the embedded copy so library synchronization retains required APIs. Do not update unrelated consumers as part of a Flightsim-only change.

---

## FenCore Integration

Flightsim delegates pure logic to **FenCore** domains:

| Domain | Usage |
|--------|-------|
| `FenCore.Math` | `Clamp()` for value clamping |
| `FenCore.Secrets` | `IsSecret()`, `SafeToString()`, `SafeCompare()` for Midnight secret values |
| `FenCore.Charges`, `FenCore.Cooldowns` | `CalculateAllInto()` and `CalculateProgressInto()` calculate ability states into reusable buffers; the Executor owns animation state |
| `FenCore.ActionResult` | Result pattern for error handling |

---

## Localization

Uses a minimal manual L table (no AceLocale):

```lua
-- Flightsim.lua
local L = setmetatable({}, { __index = function(t, k) return k end })
Flightsim.L = L
```

**Coverage:** 150 keys in every one of the 11 locale files, including settings labels and descriptions. English loads first as fallback. Brand names, font names, slash-command tokens, and developer diagnostic text are not all localized.

Validate offline with `python Tests/validate_repo.py` and `lua Tests/run.lua`, or use `locale.validate` with addon="Flightsim" when Mechanic MCP is connected. See [CI documentation](docs/ci.md).

---

## Bar Architecture

### Default Bar Order (top to bottom)

1. Speed bar (with sustainable marker)
2. Acceleration bar (thin, no gap from speed bar)
3. Surge Forward (6 charge sections, blue gradient)
4. Second Wind (3 charge sections, purple gradient) – dims when Surge Forward full
5. Whirling Surge (cooldown bar, cyan gradient)

Ability rows follow `profile.abilities.order`; `Logic.Visibility.GetAbilityOrder()` normalizes unknown, duplicate, and omitted entries. `profile.abilityBars` controls enabled state; the legacy `profile.abilities.enabled` table is retained but is not consumed by rendering or commands.

### Ability Identifiers

| Ability | Spell ID | Type |
|---------|----------|------|
| Surge Forward | 372608 | 6 charges |
| Second Wind | 425782 | 3 charges |
| Whirling Surge | 361584 | 30s cooldown |

Recovery indicators match public aura IDs: Thrill of the Skies `377234` and active Ground Skimming `404184` (not passive talent `404183`). Secret IDs are ignored; localized aura names are not compared. See [identifier evidence](docs/quality-improvements.md#recovery-buff-identifiers).

### Custom Colors

All bar colors are user-configurable in Settings. The View layer applies brightness dimming (0.3x) for inactive states.

---

## Visibility Rules

- `profile.visibility.hideWhenNotSkyriding` defaults to true and requires detected skyriding plus an airborne state.
- `showWhenGroundMounted` permits a detected skyriding mount on the ground. Disabling the skyriding-only rule shows the HUD regardless of flight state.
- `Context.IsSkyridingActive()` requires a mount or detected druid flight form, then accepts `canGlide` or public Surge Forward charge data with positive maximum charges. A false `canGlide` alone does not veto the charge-data fallback.
- Ability visibility follows `profile.abilityBars`, not whether spell data is secret. Restricted charge data uses usability-based full/empty fills; restricted Whirling Surge data displays a full fallback bar.
- Secret speed hides acceleration; the View handles secret speed through guarded rendering.
- Container height adjusts to visible rows. Pitch is explicitly disabled in the Executor and hidden in settings.

---

## Performance Patterns

- Adaptive throttling: 20Hz when visible, 2Hz when hidden
- Event-driven visibility via `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`, `UPDATE_SHAPESHIFT_FORMS`
- Skyriding detection uses a 0.05-second cache, invalidated by relevant events; spell data stays cached until charge/cooldown, spellbook, combat, mount/form, world, or zone transitions.
- Acceleration normalizes speed changes and smoothing by elapsed time, preserving the original 20Hz response; hidden or interrupted samples reset history.
- Shared charge/cooldown outputs are borrowed mutable buffers. Copy values needed beyond the next call and use separate buffers for independent abilities.
- Profiling runs when debug mode or Mechanic is present; published component timings are milliseconds of work per elapsed second. Offline allocation tests do not establish an in-game CPU or memory budget.
- Event callback errors reach WoW's error handler with event/category/ID and a ten-second per-callback throttle; subscriber failures do not stop other callbacks.

---

## SavedVariables

- **Root**: `FlightsimDB`
- Runtime settings use `Flightsim.db.profile`, AceDB's selected profile. Preserve existing profile keys as the compatibility contract.
- Raw `FlightsimDB` stores AceDB's `profiles` and `profileKeys`; legacy `FlightsimDB.profile` is only consulted by the position migration. Do not write new settings into that legacy table.
- Always add new settings as optional keys with defaults

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/fs` | Open settings panel |
| `/fs lock` | Lock frame position |
| `/fs unlock` | Unlock frame (drag to move) |
| `/fs scale <0.5-2.0>` | Set UI scale |
| `/fs width <50-800>` | Set HUD width in pixels |
| `/fs barmax <speed>` | Set a positive minimum speed-bar scale; zone/session maxima may raise it |
| `/fs reset` | Reset position and scale |
| `/fs status` | Show brief status |
| `/fs debug` | Toggle debug logging |
| `/fs pos` | Show saved/profile/frame position diagnostics |
| `/fs hidenot` | Enable the skyriding-only visibility rule |
| `/fs showalways` | Disable the skyriding-only visibility rule |
| `/fs toggle <ability>` | Toggle a bar by its English ability token |
| `/fs move <ability> <index>` | Reorder ability rows |
| `/fs list` | Show current row order and enabled state |
| `/fs sustainable <speed\|auto>` | Set the marker, hide it with 0, or restore automatic zone scaling |

Both `/fs` and `/flightsim` are registered once by AceConsole in `Settings.lua`. Empty input opens settings; other input reaches `Flightsim.HandleSlashCommand()` in `Config.lua`. Legacy aliases: `optimal` → `sustainable`, `hidesky` → `showalways`. Ability queries match the first English token containing the query in configured order. See [README](README.md#slash-commands) for user examples.

---

## API Notes

### Druid Flight Form Support

- The adapter handles flight forms separately from `IsMounted()`.
- Current detection checks class `DRUID`, form index `3`, and either `IsFlying()` or gliding. This index is an implementation assumption to recheck if form behavior changes; do not treat every Travel Form state as airborne.

### Midnight (12.0) API Handling

- **API boundary:** `Context.lua` guards API calls and checks individual returned fields through `Bridge/Secrets.lua`/FenCore before arithmetic. `pcall` success does not make returned values non-secret; restrictions must be handled in or out of combat.
- **Charge timing:** public charge counts do not imply public recharge start/duration. Test both before using the shared numeric domain APIs.
- **Gliding tuple:** `GetGlidingInfo()` is read as `isGliding`, `canGlide`, `forwardSpeed`; account for the leading success boolean from `pcall`.
- **Recovery:** invalidation events refresh caches; secret/public transitions clear stale animation and acceleration history.
- **Resource model:** use spell charges for recovery tracking. Do not reintroduce the legacy `UnitPower("player", 25)` vigor path.

---

## CurseForge Deployment

- **Project ID**: `1403044`
- **Project URL**: https://www.curseforge.com/wow/addons/flightsim

`.pkgmeta` packages the addon as `Flightsim`, includes embedded dependencies, uses `CHANGELOG.md` for release notes, and excludes tests/developer documentation. The checked-in GitHub workflow performs quality checks only; it does not publish a release.

Existing release guides describe CurseForge webhook packaging with clean version tags for releases and `-alpha`/`-beta` suffixes for prereleases. Webhook configuration and remote delivery are external state: verify them when performing a release rather than assuming a push publishes successfully.

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
| 2026-09-05 | Use shared FenCore buffer APIs, elapsed-time acceleration, throttled callback diagnostics, full 150-key locale coverage, and offline CI checks |
