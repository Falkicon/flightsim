# Flightsim

![Flightsim Banner](https://raw.githubusercontent.com/Falkicon/flightsim/main/assets/images/flightsim-banner-1200.png)

A lightweight World of Warcraft addon that displays flight speed, acceleration, and skyriding ability cooldowns, including support for **Druid Flight Form**.

![WoW Target](https://img.shields.io/badge/WoW_target-12.1.0-blue)
![Interface](https://img.shields.io/badge/Interface-120100-green)
[![GitHub](https://img.shields.io/badge/GitHub-Falkicon%2Fflightsim-181717?logo=github)](https://github.com/Falkicon/flightsim)
[![Sponsor](https://img.shields.io/badge/Sponsor-pink?logo=githubsponsors)](https://github.com/sponsors/Falkicon)

The current manifest targets **Interface 120100 (WoW 12.1.0)**. Flightsim uses modern spell APIs and guarded fallbacks when the client restricts speed or ability data. See [flightsim.toc](flightsim.toc) for the addon version and client target.

## Credits

Inspired by [Dragonriding UI](https://wago.io/dmui-dragonriding/42), a WeakAura by **Darianopolis**. Flightsim is a standalone addon reimplementation with additional features and performance optimizations.

## Features

- **Speed Display** - Current flight speed as a percentage, with color gradient from red (slow) to green (fast)
- **Acceleration Bar** - Visual indicator of acceleration/deceleration with elapsed-time smoothing and optional dynamic coloring
- **Sustainable Speed Marker** - Zone-based cruise-speed reference, with an optional custom speed override
- **Ability Cooldown Bars**:
  - **Surge Forward** - 6-charge ability with individual charge bars (blue gradient)
  - **Second Wind** - 3-charge ability with individual charge bars (purple gradient)
  - **Whirling Surge** - 30-second cooldown bar (cyan gradient)
  - Second Wind bars dim automatically when Surge Forward is at max charges
  - Each ability bar can be individually toggled in Settings
- **Recovery Buff Indicators** - Configurable circles for Thrill of the Skies and Ground Skimming
- **Custom Colors** - Colors for the speed gradient, acceleration, ability bars, recovery indicators, and frame background/border
- **Profiles and Layout** - AceDB profiles, adjustable scale and width, draggable positioning, and click-through when locked
- **Localization** - All 150 core and settings keys translated for 10 locales (DE, ES-ES, ES-MX, FR, IT, KO, PT, RU, ZH-CN, ZH-TW)
- **MechanicLib Integration** - Debug tools, performance metrics, and testing when [Mechanic](https://github.com/Falkicon/mechanic) is installed

## Installation

### CurseForge

Search for "Flightsim" in your addon manager, or:

- [CurseForge](https://www.curseforge.com/wow/addons/flightsim)

### Manual Installation

1. Download or clone this repository
2. Place the `Flightsim` folder in your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart WoW or type `/reload` if already running

## Usage

By default, the display appears while airborne on a detected skyriding mount or in a supported flight form. Visibility settings can also show it on the ground or keep it visible outside skyriding.

### Slash Commands

All commands use `/flightsim` or `/fs`:

| Command                     | Description                                                |
| --------------------------- | ---------------------------------------------------------- |
| `/fs`                       | Open settings panel                                        |
| `/fs lock`                  | Lock frame position                                        |
| `/fs unlock`                | Unlock frame (drag to move)                                |
| `/fs scale <0.5-2.0>`       | Set UI scale                                               |
| `/fs width <50-800>`        | Set HUD width in pixels                                    |
| `/fs barmax <speed>`        | Set a positive minimum for the speed-bar scale             |
| `/fs reset`                 | Reset position and scale to defaults                       |
| `/fs status`                | Show brief status information                              |
| `/fs debug`                 | Toggle debug logging                                       |
| `/fs pos`                   | Show detailed saved/profile/frame position information     |
| `/fs hidenot`               | Enable the skyriding-only visibility rule                   |
| `/fs showalways`            | Disable the skyriding-only visibility rule                  |
| `/fs toggle <ability>`      | Toggle an ability bar using part of its English name        |
| `/fs move <ability> <index>` | Move an ability row (positions 1–3)                         |
| `/fs list`                  | Show ability row order and enabled state                   |
| `/fs sustainable <speed\|auto>` | Set marker speed, use `0` to hide it, or restore zone defaults with `auto` |

Ability arguments match part of the English ability name, for example `/fs toggle second` or `/fs move whirling 1`. `optimal` is an alias for `sustainable`; the legacy `hidesky` command is an alias for `showalways`.

Speeds use walking speed as 100%. The bar scale is the largest of the configured `barmax`, the zone reference, and the session maximum. `/fs reset` resets position and scale; use the Profiles settings to reset the full profile.

### Settings Panel

Open **Game Menu > Options > AddOns > Flightsim** for graphical settings:

- **General**: Lock toggle, scale, width, background color, visibility options
- **Speed Bar**: Height, font settings, sustain marker, custom gradient colors
- **Accel Bar**: Height, dynamic color toggle (green=accelerating, red=decelerating)
- **Ability Bars**: Height, gap, show/hide toggles, custom colors for each ability
- **Buff Indicators**: Visibility, size, and colors for recovery circles
- **Profiles**: Switch, copy, and reset saved profiles

The experimental pitch bar is disabled and hidden from settings.

## Visibility

With **Only Show When Skyriding** enabled (the default):

- The HUD requires detected skyriding and an airborne state.
- **Show on Ground** also allows a detected skyriding mount while grounded.
- The HUD hides when skyriding cannot be detected, including ordinary steady flight.

Disable **Only Show When Skyriding** to keep the HUD visible outside those conditions. Restricted speed data hides acceleration and uses guarded speed rendering; restricted ability data uses fallback fills instead of precise recharge progress. An ability bar's visibility is still controlled by its setting.

## Architecture

Flightsim follows the **AFD (Adapter-Framework-Domain)** pattern:

```
Logic/          Pure domain logic (no WoW APIs)
  ├── speed.lua         Speed calculations
  ├── acceleration.lua  Acceleration state machine
  ├── pitch.lua         Dormant pitch calculations (disabled)
  ├── color.lua         Color gradients and palettes
  └── visibility.lua    Visibility rules

Bridge/         WoW API adapters
  ├── Context.lua       Build context from WoW APIs
  ├── Events.lua        Event registration
  ├── Executor.lua      Orchestrate updates
  └── Secrets.lua       Secret value handling

View/           UI rendering
  └── init.lua          Frame creation and updates

Locales/        Translations (11 files)
```

## Dependencies

Flightsim uses embedded libraries (no external dependencies required):

- **Ace3** - AceDB, AceConfig, AceConsole, AceGUI for settings
- **FenCore** - Pure logic domains (Math, Secrets, Charges, Cooldowns)
- **MechanicLib** - Optional integration with Mechanic development hub

## Requirements

- World of Warcraft Retail matching the current manifest target (Interface 120100 / 12.1.0)
- Skyriding unlocked on your character

## Development

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for setup and verification, or [AGENTS.md](AGENTS.md) for module contracts and agent workflow. The [CI guide](docs/ci.md) lists offline tests, lint, formatting, and manifest/localization checks. See [CHANGELOG.md](CHANGELOG.md) for release history and unreleased changes.

## Support

If you find Flightsim useful, consider [sponsoring on GitHub](https://github.com/sponsors/Falkicon) to support continued development and new addons. Every contribution helps!

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.
