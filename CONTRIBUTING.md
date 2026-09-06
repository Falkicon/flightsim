# Contributing to Flightsim

Thanks for your interest in contributing! This addon is a lightweight skyriding HUD for World of Warcraft, and we welcome bug reports, feature suggestions, and code contributions.

## Getting Started

1. **Fork and clone** the repository
2. **Run the offline checks** described below before testing runtime changes.
3. **For runtime verification, place/sync the addon** in your intended client's addons directory, for example:
   ```
   World of Warcraft\_retail_\Interface\AddOns\Flightsim\
   ```
4. **Test runtime changes in-game** after `/reload`. Documentation-only changes need source and link checks instead.

## Development Guidelines

### Read the Docs First

- [AGENTS.md](AGENTS.md) – Project intent, conventions, and decisions log

### Code Style

- **Lua 5.1** syntax (WoW's embedded Lua version)
- **Local variables** – Prefer `local` for clear scope and to avoid accidental globals
- **Restricted APIs** – Use `pcall` where an API call itself can raise, then separately check returned values with `FenCore.Secrets` before comparing, formatting, or doing arithmetic
- **Embedded dependencies** – Use the existing Ace3 and FenCore libraries; manage them through `Libs/libs.json`

### Performance Expectations

This addon prioritizes low resource usage:

- Reuse caller-owned or borrowed buffers in frequent update paths
- Copy borrowed results before retaining them across another calculation
- Use event-driven updates where possible
- Throttle OnUpdate handlers appropriately

Performance changes need measurements that state the environment and method.
Offline allocation regressions are useful, but they are not in-game CPU or memory
benchmarks.

### Midnight Compatibility

The addon targets Interface 120100, as declared in `flightsim.toc`. When adding features:

- Handle restricted API data both in and out of combat
- Guard API calls that can raise with `pcall`
- Treat secret return values as a separate concern: use `Secrets.IsSecret`,
  `Secrets.SafeCompare`, or `Secrets.SafeToString` before consuming them
- Degrade gracefully when data is unavailable or restricted

## Submitting Changes

### Bug Reports

Open an issue with:

- WoW version and client (Retail/Beta)
- Steps to reproduce
- Output from `/fs status` (and `/fs pos` for positioning issues); `/fs debug` toggles logging rather than printing a full diagnostic report
- Any Lua errors from BugSack/BugGrabber

### Feature Requests

Open an issue describing:

- What you want to accomplish
- Why it fits the addon's scope (lightweight skyriding HUD)

### Pull Requests

1. **Create a branch** from `main`
2. **Keep changes focused** – one feature or fix per PR
3. **Run relevant offline checks**, then test runtime changes on the intended client; include Beta results if applicable
4. **Update docs** if adding settings or slash commands
5. **Describe your changes** in the PR description

## File Structure

| File             | Purpose                    |
| ---------------- | -------------------------- |
| `flightsim.toc`  | Addon manifest             |
| `Flightsim.lua`  | Init, defaults, migrations |
| `Logic/`        | Pure calculations and visibility rules |
| `Bridge/`       | WoW API adapters, event routing, and execution |
| `View/init.lua` | Frame creation, layout, and rendering |
| `Config.lua`    | Slash commands and Mechanic tools panel |
| `Settings.lua`  | AceConfig settings panel |

### Offline Verification

From the repository root, run `lua Tests/run.lua` with Lua 5.1, `luacheck .`, and
`python Tests/validate_repo.py`. The [CI guide](docs/ci.md) lists pinned tooling
and the full formatting command used by pull-request checks.
The regression suite uses the embedded FenCore and mocked game APIs; it does not
require WoW or a sibling development checkout. It cannot emulate WoW's secret-value
runtime or prove installed-addon behavior.

Use connected Mechanic MCP tools when available. If they are unavailable, run
isolated offline checks rather than live Mechanic CLI operations. Complete offline
checks before installing/syncing changes; request and confirm `/reload` before
reading live diagnostics. See [the quality review](docs/quality-review.md) and
[follow-up improvements](docs/quality-improvements.md) for verification results
and the targeted game verification checklist.

Documentation-only changes do not require installing the addon or reloading the
game. Verify their paths, commands, and claims against the current source instead.

## Testing Checklist

Before submitting:

- [ ] Offline checks relevant to the changed files pass
- [ ] Documentation paths, commands, and version claims match current source
- [ ] For runtime changes, the installed addon loads without errors after a confirmed `/reload`
- [ ] For runtime changes, the affected skyriding, settings, command, and combat behavior is exercised in game

## Questions?

Open an issue or check the existing documentation. Thanks for helping make Flightsim better!
