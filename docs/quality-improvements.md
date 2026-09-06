# Quality improvements — 2026-09-05

Follow-up to the [repository review](quality-review.md). This records the offline
verification snapshot from September 5, before publication or remote CI runs.
Release history is maintained in [CHANGELOG.md](../CHANGELOG.md).

## Changes

- **Continuous integration:** pull requests and pushes to `main` run Lua 5.1
  regressions, Luacheck, complete first-party formatting checks, and repository
  validation. Validation checks exact manifest/XML path casing, recursive XML
  includes, locale guards, duplicate keys, key parity, and referenced locale keys.
  See [CI setup and local commands](ci.md).
- **Callback diagnostics:** failed event subscribers report event, category,
  callback ID, and error through WoW's error handler. Reporting is limited to
  once per callback every ten seconds. Other subscribers still run, including
  when the error handler itself fails. Without a usable clock, each callback
  reports at most once until it is registered again.
- **Lifecycle regressions:** exercise mounted login, takeoff, ability recovery,
  restricted spell APIs, dismount, remount, profile changes, and stable caches
  through the actual Context, Events, and Executor modules.
- **Localization:** all 150 core and settings keys now exist in all 11 locales.
  Tests exercise actual Lua locale guards, format placeholders, and settings
label resolution. Proper font/brand names and English slash tokens remain;
  developer diagnostic text is not comprehensively localized.
- **Acceleration timing:** speed deltas and smoothing use elapsed seconds.
  The original response at 20Hz is preserved. Tests compare 10, 20, and 60Hz
  and irregular samples; missing samples, hidden state, and gaps over one
  second reset history. Zero elapsed time preserves the prior smoothed value.
  Dormant pitch behavior remains disabled and unchanged by this timing work.
- **Shared domain calculations:** the Executor uses FenCore's buffer APIs
  instead of duplicating charge and cooldown formulas. Existing allocating
  ActionResult APIs retain independent results. Buffer APIs return borrowed
  tables which may change on the next call; callers retaining history must
  copy it. Independent abilities use independent buffers.

## Recovery buff identifiers

`Context.UpdateBuffs()` matches public `spellId` fields rather than localized
names. The active buffs are Thrill of the Skies **377234** and Ground Skimming
**404184**. Ground Skimming **404183** is the passive talent, not the active aura.
The current client-data tooltip records support this distinction:
[Thrill of the Skies](https://nether.wowhead.com/tooltip/spell/377234) and
[Ground Skimming](https://nether.wowhead.com/tooltip/spell/404184).

Secret IDs remain ignored. A public ID can be recognized even when its name is
localized or secret. This does not assume IDs are always readable in restricted
game states. Regressions cover those cases and reject the passive talent ID.

## Shared-library source

The updated `Domains/Charges.lua` and `Domains/Cooldowns.lua` also exist in the
sibling `../Libs/FenCore` source checkout, so future library synchronization can
retain the APIs. Its original files matched Flightsim's embedded originals
before the update. The source directory is outside this repository and is not
tracked by Flightsim's Git diff. `../Libs/FenCore/Docs/Buffers.md` documents the
borrowed-buffer contract.

The new APIs are `Charges.CalculateChargeFillInto()`,
`Charges.CalculateAllInto()`, `Cooldowns.CalculateProgressInto()`, and
`Cooldowns.CalculateInto()`. Steady-state calculations reuse existing output
storage; first use and increased charge capacity may allocate. Animation state
remains owned by the Executor.

## Verification and remaining limits

Run `lua Tests/run.lua`, `python Tests/validate_repo.py`, `luacheck .`, and the
formatting check in the CI guide. The regression runner includes domain helpers,
Bridge, commands, View/Logic, acceleration timing, buffer compatibility, callback
diagnostics, lifecycle sequences, and localization.

Executed results: all 12 domain tests and eight regression suites passed.
Luacheck reported zero warnings and errors in 26 first-party runtime files;
the complete configured StyLua check and `git diff --check` passed. Repository
validation resolved 35 TOC files and 45 recursive XML references and confirmed
150 keys across all 11 locales.

The buffer regression checks separate ability storage, retained allocating
results, shrink/grow transitions, and secret-state recovery. With garbage
collection stopped, both 10,000 domain iterations and 10,000 three-ability
Executor iterations stay below the test's 1KiB growth tolerance after warmup.
These are offline allocation checks, not in-game CPU measurements. The same
32 checks pass against the sibling FenCore source, as do its 30 existing charge
and cooldown tests.

Mechanic MCP is unavailable in this session. Offline mocks cannot reproduce
WoW's secret-value VM, protected frames, visual geometry, or actual event timing.
Translations have structural checks but still benefit from native-speaker review.
After syncing to the intended client, confirm `/reload` and exercise the
[game verification checklist](quality-review.md#verification), including callback
error visibility, acceleration feel, translated settings, and recovery indicators.
Read live diagnostics only after that confirmation and with Mechanic MCP connected.
