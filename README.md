# Flightsim

![Flightsim Banner](https://raw.githubusercontent.com/Falkicon/flightsim/main/assets/images/flightsim-banner-1200.png)

A lightweight World of Warcraft addon that displays flight speed, acceleration, and skyriding ability cooldowns while skyriding. Fully supports **Druid Flight Form** (Travel Form while flying).

![WoW Version](https://img.shields.io/badge/WoW-11.2.7%2B-blue)
![Interface](https://img.shields.io/badge/Interface-120000-green)
[![GitHub](https://img.shields.io/badge/GitHub-Falkicon%2Fflightsim-181717?logo=github)](https://github.com/Falkicon/flightsim)
[![Sponsor](https://img.shields.io/badge/Sponsor-pink?logo=githubsponsors)](https://github.com/sponsors/Falkicon)

> **Midnight Compatibility**: This addon is being actively tested against the Midnight beta (Interface 120000). All API calls use defensive `pcall` wrappers to handle the expected API pruning in combat and restricted zones.

## Credits

Inspired by [Dragonriding UI](https://wago.io/dmui-dragonriding/42), a WeakAura by **Darianopolis**. Flightsim is a standalone addon reimplementation with additional features and performance optimizations.

## Features

- **Speed Display** – Current flight speed as a percentage, with color gradient from red (slow) to green (fast)
- **Acceleration Bar** – Visual indicator of current acceleration/deceleration
- **Sustainable Speed Marker** – Reference line showing the speed you can maintain indefinitely (default 930%)
- **Ability Cooldown Bars**:
  - **Surge Forward** – 6-charge ability with individual charge bars (blue gradient)
  - **Second Wind** – 3-charge ability with individual charge bars (purple gradient)
  - **Whirling Surge** – 30-second cooldown bar (cyan gradient)
  - Second Wind bars dim automatically when Surge Forward is at max charges (6/6), indicating you should spend charges first
  - Each ability bar can be individually toggled in Settings

## Installation

1. Download or clone this repository
2. Place the `Flightsim` folder in your WoW addons directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Restart WoW or type `/reload` if already running

## Usage

The display automatically appears when you are skyriding and hides otherwise.

### Slash Commands

All commands use `/flightsim` or `/fs`:

| Command                     | Description                                                |
| --------------------------- | ---------------------------------------------------------- |
| `/fs`                       | Toggle visibility                                          |
| `/fs lock`                  | Lock frame position                                        |
| `/fs unlock`                | Unlock frame (drag to move)                                |
| `/fs scale <0.5-2.0>`       | Set UI scale                                               |
| `/fs reset`                 | Reset position and settings to defaults                    |
| `/fs sustainable <percent>` | Set sustainable speed marker (e.g., `/fs sustainable 930`) |
| `/fs status`                | Show brief status information                              |
| `/fs debug`                 | Show detailed debug information                            |

### Settings Panel

Open **Game Menu → Options → AddOns → Flightsim** for graphical settings:

- Lock/unlock toggle
- Scale slider
- Sustainable speed marker position
- Sustainable speed marker width
- Sustainable speed marker opacity

## Visibility

The addon only displays while actively skyriding:

- Hidden on ground
- Hidden during old-style flying
- Hidden in combat (defensive measure for API reliability)
- Hidden when skyriding state cannot be confirmed

## Requirements

- World of Warcraft Retail 11.2.7+ or Midnight Beta
- Skyriding unlocked on your character

## Files

| File             | Purpose                             |
| ---------------- | ----------------------------------- |
| `flightsim.toc`  | Addon manifest                      |
| `Flightsim.lua`  | Core initialization and defaults    |
| `UI.lua`         | Frame construction and update logic |
| `Config.lua`     | Slash command handling              |
| `SettingsUI.lua` | Blizzard Settings panel integration |

## Technical Notes

- Standalone addon with no external dependencies
- Uses WoW's native SavedVariables for persistence
- Defensive API usage with pcall wrappers for Midnight compatibility
- Event-driven updates with efficient OnUpdate throttling
- Adaptive throttling: 20Hz when flying, 0.2Hz when hidden
- Minimal resource usage: ~150k memory, <0.15 ms/s CPU when idle
- Graceful degradation when spell APIs are restricted (combat/restricted zones)

## License

MIT License – see [LICENSE](LICENSE) for details.
