# Contributing to Flightsim

Thanks for your interest in contributing! This addon is a lightweight skyriding HUD for World of Warcraft, and we welcome bug reports, feature suggestions, and code contributions.

## Getting Started

1. **Fork and clone** the repository
2. **Place the addon** in your WoW addons directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\Flightsim\
   ```
3. **Test in-game** with `/reload` after making changes

## Development Guidelines

### Read the Docs First

- [AGENTS.md](AGENTS.md) – Project intent, conventions, and decisions log
- [SPEC.md](SPEC.md) – Technical specification and architecture
- [ADDON_DEVELOPMENT_GUIDE.md](ADDON_DEVELOPMENT_GUIDE.md) – WoW addon best practices

### Code Style

- **Lua 5.1** syntax (WoW's embedded Lua version)
- **Local variables** – Prefer `local` for performance and scope control
- **Defensive API calls** – Wrap WoW APIs in `pcall` when they may fail in combat or restricted zones
- **No external dependencies** – Keep the addon standalone

### Performance Expectations

This addon prioritizes low resource usage:

- **Memory**: ~150k when idle
- **CPU**: <0.15 ms/s when hidden
- Avoid per-frame table allocations
- Use event-driven updates where possible
- Throttle OnUpdate handlers appropriately

### Midnight Compatibility

The addon targets Interface 120000 (Midnight beta). When adding features:

- Assume APIs may be restricted in combat
- Use `pcall` wrappers for any API that touches spell/unit data
- Fail gracefully – hide UI elements rather than throwing errors

## Submitting Changes

### Bug Reports

Open an issue with:

- WoW version and client (Retail/Beta)
- Steps to reproduce
- Output from `/fs debug` if relevant
- Any Lua errors from BugSack/BugGrabber

### Feature Requests

Open an issue describing:

- What you want to accomplish
- Why it fits the addon's scope (lightweight skyriding HUD)

### Pull Requests

1. **Create a branch** from `main`
2. **Keep changes focused** – one feature or fix per PR
3. **Test in-game** on both Retail and Beta if possible
4. **Update docs** if adding settings or slash commands
5. **Describe your changes** in the PR description

## File Structure

| File             | Purpose                    |
| ---------------- | -------------------------- |
| `flightsim.toc`  | Addon manifest             |
| `Flightsim.lua`  | Init, defaults, migrations |
| `UI.lua`         | All UI logic (~1280 lines) |
| `Config.lua`     | Slash commands             |
| `SettingsUI.lua` | Blizzard Settings panel    |

## Testing Checklist

Before submitting:

- [ ] Addon loads without errors (`/reload`)
- [ ] UI appears when skyriding
- [ ] UI hides when dismounted
- [ ] Settings persist across sessions
- [ ] `/fs status` shows correct info
- [ ] No Lua errors in combat

## Questions?

Open an issue or check the existing documentation. Thanks for helping make Flightsim better!
