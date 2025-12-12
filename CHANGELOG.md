# Changelog

All notable changes to Flightsim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
