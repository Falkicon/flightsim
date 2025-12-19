# Changelog

All notable changes to Flightsim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

First official release! 🎉

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

- Speed bar with color gradient (red → green based on speed)
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
