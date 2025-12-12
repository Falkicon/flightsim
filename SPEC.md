# Flightsim – Living Spec

Last updated: 2025-12-12

## 1) Overview

Flightsim is a small UI addon to replace a specific WeakAuras workflow for flight:

- Shows current flight speed as a color-coded bar with percentage text.
- Displays an acceleration indicator bar.
- Tracks Whirling Surge cooldown with a dedicated bar.
- Tracks Second Wind charges with 3 individual charge bars.
- Dims Second Wind when unusable (Surge Forward at max charges).

## 2) Supported clients

- Retail 11.2.7+: must work.
- Midnight beta (12.0): compatible via Interface 120000 for testing.
- Midnight release: should keep core functionality despite API pruning.

## 3) UX requirements

### 3.1 UI surface

Single movable frame containing (top to bottom):

1. **Speed bar**: Color-coded (red → yellow → green) showing current speed percentage.

   - Overlaid speed text (e.g., "789%").
   - Sustainable speed marker (vertical line, configurable position and opacity).

2. **Acceleration bar**: Thin bar below speed bar showing rate of speed change.

   - Green when accelerating, red when decelerating.

3. **Whirling Surge bar**: Blue color-coded bar showing cooldown status.

   - Full when ability is ready, drains during cooldown.

4. **Second Wind bars**: Three purple charge bars showing individual charge states.
   - Each bar fills independently as charges regenerate.
   - Entire section dims to 20% opacity when Surge Forward is at max charges (6/6), indicating Second Wind is unusable.

### 3.2 Customization

Available via Settings UI and slash commands:

- Frame position (drag when unlocked)
- Scale
- Bar width + height
- Speed bar max value
- Sustainable speed marker position
- Sustainable speed marker width
- Sustainable speed marker opacity (default 60%)
- Acceleration bar height + gap
- Ability bar height + gap
- Visibility mode (hide when not skyriding / hide while skyriding / always show)
- Font size
- Show percentage toggle

Configuration UI:

- Primary: Blizzard AddOn Settings panel (Options → AddOns → Flightsim).
- Secondary/fallback: slash commands.

### 3.3 Visibility

The UI can auto-hide based on skyriding state:

- **Hide when not skyriding** (default on)
- **Hide while skyriding** (default off)
- **Always show** (if both above are off)

Skyriding detection uses `C_PlayerInfo.GetGlidingInfo()` with fallbacks.

### 3.4 Performance

- **Adaptive throttling**: 20Hz when visible, 0.2Hz (every 5s) when hidden
- **Event-driven visibility**: Responds to `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_AURA`, `PLAYER_ENTERING_WORLD`
- **Fast dismount detection**: Early `IsMounted()` check bypasses expensive API calls
- **No per-frame allocations**: Reusable tables for cooldown/position data
- **Frame-level caching**: `IsSkyridingActive()` result cached per frame
- **Idle overhead**: ~150k memory, <0.15 ms/s CPU when not skyriding

## 4) Data model (SavedVariables)

SavedVariables: `FlightsimDB`

Current shape:

```lua
FlightsimDB.profile = {
    locked = false,
    x = 0,
    y = 0,
    scale = 1,
    ui = {
        width = 150,
        speedBarHeight = 30,
        sustainableSpeedMarkerWidth = 1,
        sustainableSpeedMarkerAlpha = 0.6,
        accelBarHeight = 2,
        accelBarGap = 2,
        abilityBarHeight = 10,
        abilityBarGap = 2,
    },
    speedBar = {
        maxSpeed = 950,
        sustainableSpeed = 790,
        fontSize = 12,
        showPercent = true,
    },
    visibility = {
        hideWhenNotSkyriding = true,  -- Default: hide when not skyriding
        hideWhileSkyriding = false,
    },
    abilityBars = {
        showSurgeForward = true,   -- 6 charges, blue
        showSecondWind = false,    -- 3 charges, purple (off by default)
        showWhirlingSurge = false, -- 30s cooldown, cyan (off by default)
    },
    abilities = {
        order = { ... },
        enabled = { ... },
    },
}
```

Migration notes:

- Old `optimalSpeed` values are read as fallback for `sustainableSpeed`.
- Old `optimalMarkerWidth` values are read as fallback for `sustainableSpeedMarkerWidth`.

## 5) APIs and compatibility

### 5.1 Compatibility matrix

| Feature              | APIs (current)                                                                 | Combat-safe? | Fallback behavior               |
| -------------------- | ------------------------------------------------------------------------------ | ------------ | ------------------------------- |
| Speed number + bar   | `C_PlayerInfo.GetGlidingInfo()` (skyriding forwardSpeed) + `GetUnitSpeed`      | Yes          | Position-delta estimate or `--` |
| Skyriding detection  | `C_PlayerInfo.IsPlayerInSkyriding()` / `C_PlayerInfo.IsPlayerInDragonriding()` | Yes          | Prefer hiding if uncertain      |
| Whirling Surge CD    | `C_Spell.GetSpellCooldown(361584)`                                             | TBD          | Show bar at 0%                  |
| Second Wind charges  | `C_Spell.GetSpellCharges(425782)`                                              | TBD          | Show bars at 0%                 |
| Surge Forward checks | `C_Spell.GetSpellCharges(372608)`                                              | TBD          | Don't dim Second Wind           |

### 5.2 Spell IDs

| Ability        | Spell ID | Notes                              |
| -------------- | -------- | ---------------------------------- |
| Surge Forward  | 372608   | 6 charges, restored by Second Wind |
| Whirling Surge | 361584   | 30s cooldown dash                  |
| Second Wind    | 425782   | 3 charges, restores vigor          |
| Skyward Ascent | 372610   | (tracked, not displayed)           |
| Aerial Halt    | -        | (tracked, not displayed)           |

### 5.3 Speed calculation

1. Primary: `C_PlayerInfo.GetGlidingInfo()` forward speed while skyriding.
2. Fallback: `GetUnitSpeed("player")` or `UnitSpeed("player")`.
3. Last resort: Position-delta calculation.

Speed is displayed as a percentage of ~8.24 y/s (100% ground speed baseline).

## 6) File structure

```
flightsim.toc        # Addon manifest
Flightsim.lua        # Core initialization, SavedVariables, defaults
UI.lua               # Frame construction, layout, OnUpdate logic
Config.lua           # Slash command handling
SettingsUI.lua       # Blizzard Settings panel integration
README.md            # User documentation
SPEC.md              # This file (living spec)
AGENTS.md            # Agent notes and conventions
ADDON_DEVELOPMENT_GUIDE.md  # Development best practices
```

## 7) Resolved questions

- **Ability set**: Tracking Surge Forward, Whirling Surge, Second Wind, Skyward Ascent, Aerial Halt.
- **Speed display**: Percentage by default, configurable.
- **Visibility**: Configurable; defaults to always show.
- **Sustainable speed**: Renamed from "optimal" to better reflect its meaning (speed maintainable without abilities).

## 8) Future considerations

- Midnight API compatibility testing when beta is available.
- Additional ability bar displays if requested.
- Per-character settings support.
