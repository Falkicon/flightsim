# Changelog

## [1.5.1] - 2026-02-20

### Fixed
- **Critical Performance: Zero-Allocation Pipeline** — Eliminated all per-frame table and string allocations from the 20Hz update loop
  - Memory reduced from 5.4 MB (and climbing) to ~500 KB stable after 5 minutes of flying
  - Eradicated compounding GC freezes (previously ~650 ms/s CPU spikes every few minutes)
- **C-API Table Leak** — `C_Spell.GetSpellCharges` and `C_Spell.GetSpellCooldown` were allocating new tables from the C-client on every call (~10,800 tables/min). Replaced with event-driven cache invalidated by `SPELL_UPDATE_COOLDOWN`
- **Secret Value Fallback Leak** — When spell data was flagged as secret, charge/cooldown/pitch handlers allocated fresh tables every frame (~46,800 tables/min). All secret branches now mutate pre-allocated static buffers
- **Visibility Logic Leak** — `Logic/visibility.lua` called `Result.success({...})` 5+ times per frame. Rewrote to use pre-allocated static result buffers
- **Speed Display String Leak** — `string.format` generated a new string every frame. Now caches the formatted text and only regenerates when the rounded display value changes
- **IsSkyridingActive Closure Leak** — Removed anonymous `pcall(function() ... end)` that created a new closure 20 times per second. Unwrapped to flat control flow with direct `pcall(C_PlayerInfo.GetGlidingInfo)`
- **UI Layout Thrashing** — `ApplyVisibilityState` recalculated frame positions every tick. Added state caching to skip redundant `SetPoint`/`SetSize`/`Show`/`Hide` calls

### Changed
- Bridge Executor now bypasses `FenCore.ActionResult.unwrap()` in hot paths, reading `.data` directly from static result buffers
- Logic layers (Speed, Acceleration, Visibility) all use pre-allocated output buffers instead of ActionResult wrappers

## [1.5.0] - 2026-02-10

### Added
- **Buff Recovery Indicators**: Circle indicators for Thrill of the Skies and Ground Skimming charge recovery buffs
  - Colored dots appear next to the speed bar when buffs are active
  - Configurable visibility, size (4-24px), and colors per buff
  - New "Buff Indicators" settings tab
- **Show on Ground Option**: New visibility toggle to show the HUD when on a skyriding mount but still on the ground
  - Appears next to "Only Show When Skyriding" in settings
  - Grayed out when skyriding-only mode is disabled
- **Pitch Bar (Experimental, Hidden)**: Position-based pitch estimation using UnitPosition triangulation
  - Shelved for refinement — code preserved but hidden from settings and HUD

## [1.4.5] - 2026-01-22

### Added
- **HUD Click-Through**: Frame is now click-through when locked, allowing clicks to pass through to the game world
  - Lock ON: Mouse passes through HUD to interact with game
  - Lock OFF: HUD is interactive and draggable
  - Works with settings toggle, Lock/Unlock buttons, and `/flightsim lock|unlock` commands

### Fixed
- **Speed Bar Scaling**: Fixed bar fill and sustain marker starting at wrong position on initial load
  - Bar now uses zone-aware reference max (1430% Dragon Isles, 1215% Old World) for consistent scaling
  - Sustain marker now appears at correct ~65% position immediately without needing to fly first
  - Previously bar would show nearly full at cruise speed until session max was established
- **Zone Detection**: Zone modifier now refreshes on mount to ensure correct speed calculations

## [1.4.4] - 2026-01-20

### Fixed
- **Frame Drag Positioning**: Fixed frame jumping to incorrect position when dragging with scale != 1.0
  - Correctly compensates for scaled coordinate origin in SetPoint offset calculation
- **Settings Panel Display**: Fixed General tab controls showing blank values until edited
  - Added NotifyChange refresh when opening settings via slash command or Blizzard options

### Changed
- **Code Formatting**: Applied StyLua formatting to all source files for consistent style

## [1.4.3] - 2026-01-18

### Fixed
- **Speed Percentage Display**: Changed baseline from mounted speed (8.24 y/s) to walking speed (7.0 y/s) to match WoW's standard speed percentage convention
  - Dragon Isles cruise now shows 929% (was 789%)
  - Old World cruise now shows 789% (was 671%)
  - Matches tooltips and other addons that use 100% = walking speed

## [1.4.2] - 2026-01-17

### Fixed
- **Frame Position Persistence**: Fixed frame position not saving correctly across profile switches and character logins
  - Frame now uses `GetCenter()` for accurate position capture after drag
  - Writes directly to SavedVariables to ensure persistence
  - Added migration to clean up stale root-level position data
- **Zone-Aware Speed**: Speed display now correctly accounts for zone modifiers (Dragon Isles vs Old World)
  - Uses Map ID detection with parent traversal for sub-zones and delves

### Added
- `/fs pos` debug command for troubleshooting position issues

### Known Issues
- Whirling Surge bar may not update on 11.2.7 (works on 12.0 PTR)

## [1.4.1] - 2026-01-05

### Fixed
- Localization files now check client locale before loading, preventing non-English strings (e.g., Chinese) from overwriting English on US/EU clients


All notable changes to Flightsim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.0] - 2026-01-04

### Added
- **Full Localization**: Complete translations for 10 languages
  - German (deDE), French (frFR), Spanish (esES/esMX), Italian (itIT)
  - Portuguese (ptBR), Russian (ruRU), Korean (koKR)
  - Chinese Simplified (zhCN), Chinese Traditional (zhTW)
- **Dynamic Acceleration Colors**: Accel bar can now show green for accelerating, red for decelerating
- **Custom Ability Colors**: User-configurable colors for all ability bars with brightness dimming
- **Hidden Bar Gap Collapsing**: When ability bars are hidden, remaining bars reposition to eliminate gaps

### Changed
- **Removed Legacy UI.lua**: Completed migration to new View layer architecture
- **Removed AceAddon-3.0**: Unused library removed, reducing addon size
- **Removed Deprecated API Fallbacks**: GetSpellCharges/GetSpellCooldown fallbacks removed (12.0+ only)

### Fixed
- Ability bar colors now properly use custom colors from settings
- Container height now dynamically adjusts based on visible bars

## [1.3.0] - 2026-01-03

### Changed
- **Architecture Refactor**: Complete restructure to Logic/Bridge/View layers
  - **View Layer** (`View/init.lua`): All UI frame creation and rendering
  - **Bridge Layer** (`Bridge/`): API calls, event handling, and command execution
  - **Logic Layer** (`Logic/`): Pure calculation functions for speed, acceleration, color, visibility
- **FenCore Integration**: Delegate core utilities to FenCore domains
  - `FenCore.Math.Clamp` for value clamping
  - `FenCore.Secrets` for Midnight secret value handling (`IsSecret`, `SafeCompare`, `SafeToString`)
  - `FenCore.Charges.CalculateAll` for charge bar state calculations
  - `FenCore.Cooldowns.Calculate` for cooldown bar state
  - `FenCore.Charges.AdvanceAnimation` / `FenCore.Cooldowns.AdvanceAnimation` for smooth fill animations
- **Settings Compatibility**: Settings now support both legacy `FlightsimUI` and new `FlightsimView`
- **Error Handling**: Improved error handling in `Executor.FullUpdate` with safe Result unwrapping

### Fixed
- Animation state properly tracks recharging index locally
- Cooldown display correctly uses `isOnCooldown` instead of inverted `isReady`

## [1.0.4] - 2025-12-23

### Changed
- System upgrade: added StyLua formatting, standalone localization, and unit tests. Added comprehensive Busted test suite for core utility functions.

## [1.0.3] - 2025-12-19

### Added
- **CurseForge Metadata**: Added `## X-License: GPL-3.0` to .toc file
- **Cursor Commands**: Added `.cursor/commands/` with GitHub workflow templates

### Changed
- **License**: Updated LICENSE file formatting

## [1.0.2] - 2025-12-19

### Fixed
- **Mode Transition Crash**: Fixed a crash occurring when changing flight modes via abilities.
  - Removed deprecated global `GetSpellInfo` fallback in favor of `C_Spell.GetSpellInfo`.
- **Error Resilience**: Added `pcall` guards to visibility and update logic to ensure stability during sensitive flight mode transitions.

### Changed
- **Steady Flight Support**: Flightsim now explicitly detects Steady Flight mode and disables the HUD to avoid cluttering the UI when not skyriding.

## [1.0.1] - 2025-12-13

### Fixed
- **Midnight (12.0) compatibility**: Fixed "attempt to compare a secret value" errors in combat
  - Added `issecretvalue()` detection for secret API return values
  - Ability bars now hide gracefully when spell APIs return secret values in combat
  - Skipped aura API calls during combat to prevent `ADDON_ACTION_BLOCKED` warnings
- Wrapped all ability bar logic to skip processing when APIs are restricted

### Changed
- Updated interface version to 120001 (Midnight beta)

## [1.0.0] - 2025-12-12

First official release!

## [0.1.1] - 2025-12-12

### Added
- Druid Flight Form support: addon now displays correctly when druids use Travel Form for skyriding
- CurseForge automatic packaging via GitHub webhook integration
- `.pkgmeta` configuration for CurseForge packager

### Fixed
- Fixed visibility detection for druids in Flight Form (`IsMounted()` returns false for shapeshifts)
- Fixed OnUpdate quick-exit optimization to not hide frame for druids in Flight Form
- Fixed 3-5 second delay before HUD appeared on mount
  - Added `UPDATE_SHAPESHIFT_FORMS` event for instant druid form detection
  - Reduced hidden-state polling from 5s to 0.5s for faster fallback response

## [0.1.0] - 2025-12-12

Initial release.

### Added
- Speed bar with color gradient (red -> green based on speed)
- Acceleration bar (thin bar below speed)
- Sustainable speed marker (configurable position, width, opacity)
- Ability cooldown bars:
  - Surge Forward (6 charges, blue)
  - Second Wind (3 charges, purple)
  - Whirling Surge (30s cooldown, cyan)
- Auto-dimming: Second Wind dims when Surge Forward is at max charges
- Per-ability bar toggles in Settings
- Blizzard Settings panel integration
- Slash commands (`/fs`, `/flightsim`)
- Automatic show/hide based on skyriding state
- Defensive API wrappers for Midnight beta compatibility
- Performance optimizations:
  - Adaptive throttling (20Hz flying, 0.2Hz hidden)
  - Table reuse to avoid per-frame allocations
  - Frame-level caching for skyriding detection
