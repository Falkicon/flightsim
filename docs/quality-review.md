# Flightsim repository quality review — 2026-09-05

This is the initial review snapshot. The subsequently authorized
[quality improvements](quality-improvements.md) address the CI, diagnostics,
lifecycle coverage, localization, acceleration timing, and shared-library items
below. That follow-up includes changes to embedded and shared-source FenCore.

Scope: first-party Lua, runtime integration, embedded-library usage, tests, locale
coverage, manifest/packaging, and developer documentation. Embedded libraries were
inspected as dependencies and were not forked or modified. Changes are local and
have not been deployed or verified in WoW.

## Findings addressed

| Priority | Finding and impact | Resolution |
| --- | --- | --- |
| P1 | Recharge start/duration values could remain secret even when charge counts were public, allowing restricted values into arithmetic. | The Bridge checks all charge timing fields and guards secret usability results. Secret speed also resets acceleration history before public samples resume. |
| P2 | Spell caches were invalidated only by cooldown events, leaving stale charges or restriction state after other transitions. | Invalidate on charge, spellbook, combat, mount, form, world, and zone transitions. Refresh recovery buffs on initialization and world entry. |
| P2 | The fallback skyriding check read forward speed as `canGlide`. | Corrected the `pcall` return position; boolean false remains evidence for steady flight. |
| P2 | Completion animations could continue after an ability was spent again; cooldown completion could use an old animation value. | Cancel animations on consumption and seed them from the current displayed state. Reset animation state across secret/public transitions. |
| P2 | Idle throttling consulted the speed child's `IsShown()` even though visibility is controlled by its parent. | Consult the HUD container so hiding it selects the existing 2Hz idle interval instead of the 20Hz active interval. |
| P2 | Performance metrics labeled a single update's duration as milliseconds per second and retained stale component values. | Accumulate measured work over actual elapsed time and publish rates; clear stale values when profiling stops. |
| P2 | Slash toggles/listing used an obsolete setting, and moving abilities changed saved order without changing layout. | Share order normalization between the View and commands, use `profile.abilityBars` for enabled state, and rebuild on moves. Unknown/duplicate tokens are ignored and omitted rows appended. |
| P2 | Config and AceConsole registered the same slash aliases independently, giving ambiguous dispatch. | AceConsole owns both aliases; one handler opens settings for empty/whitespace input and routes subcommands. |
| P2 | Scale commands saved an unclamped value after the View clamped it; zero bar maximum and overflowing numeric strings were accepted. | Validate finite numeric input, keep saved/displayed scale and width consistent, and require a positive bar maximum. Zero still disables the sustainable marker. |
| P2 | The sustainable marker used a different denominator from the speed fill, and the sustainable command's saved value never reached rendering. | Use the same effective maximum for fill and marker. Explicit overrides now reach the renderer; `sustainable auto` restores automatic zone scaling, which remains the default for existing profiles. |
| P2 | Tests referenced deleted `UI.lua` and obsolete helper methods; lint configuration depended on another checkout. | Replace obsolete tests with current domain regressions, add Bridge/View/command coverage, and make the offline runner and lint configuration self-contained. |
| P3 | Disabled pitch sampled player position on every update; its pure calculator referenced an undefined result helper and output buffer. | Remove unused position sampling, bind the error helper, and accept the caller's output buffer explicitly. |
| P3 | Bootstrap retained an unused defaults copier and listened for addon loads after initialization. Documentation still described removed files and old behavior. | Remove dead code, unregister the bootstrap event, and update the architecture, commands, dependency, and test guidance. |

The gliding contract was checked against Blizzard's generated
[PlayerInfo API documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua):
`isGliding`, `canGlide`, `forwardSpeed`.

## Architecture assessment

The existing Logic/Bridge/View division is appropriate for this addon's size.
Pure calculations can be exercised without the game, and API restrictions have a
clear boundary. Shared ability-order normalization removes disagreement between
commands and rendering without introducing a new framework.

Several paths deliberately reuse result/context tables. These are borrowed,
mutable results: callers that retain history must copy the values they need before
the next calculation. The View maintains a separate scalar visibility snapshot for
change detection. A broad conversion to immutable results would add allocations
to a frequent update path and was not warranted by this review.

Executor charge/cooldown calculations duplicate logic available in FenCore to
avoid allocations. Future consolidation should first provide a tested output-buffer
contract in the shared library; reverting these paths to allocating helpers would
trade one maintainability concern for runtime overhead. Likewise, splitting the
large View and Settings files is a possible later cleanup, not a prerequisite for
the concrete fixes above.

## Remaining findings and limits

- **P2: recovery buffs are matched by English names** in `Bridge/Context.lua`.
  Non-English clients cannot reliably recognize these localized aura names. The
  source notes that prior IDs changed; current identifiers must be verified before
  replacing the matching with spell IDs. Existing secret-name guards prevent
  restricted comparisons but do not solve localization.
- **P3: translation coverage is incomplete.** The baseline contains 81 keys;
  each of the ten translations has 68, missing 13 newer keys. Those keys and many
  hardcoded settings labels still use English. Locale guards
  and English fallback should remain in place while these are translated.
- **Pitch remains deliberately disabled.** Its dormant settings and calculation
  code were retained; enabling the feature requires renewed sampling and game
  verification.
- **P3: event callback failures are swallowed** by `Bridge/Events.lua`'s `pcall`
  dispatch. A later observability change should forward failures to the normal
  error handler without stopping other subscribers.
- Acceleration and dormant pitch smoothing use sample-based weights. Retuning
  them around elapsed time would change the visual response and needs a dedicated
  behavior review.
- Offline mocks do not emulate WoW's secret-value VM, protected frames, actual
  frame geometry, or client event timing. No measured in-game CPU improvement is
  claimed. Profiling remains conditional on debug mode or Mechanic presence.

## Verification

From the repository root, use Lua 5.1:

```text
lua Tests/run.lua
luacheck .
git diff --check
```

The regression suites cover current domain functions, API/cache transitions,
animation cancellation, command dispatch/settings consistency, row ordering,
hidden/visible throttling, and elapsed-time profiling. The Bridge suite includes
57 assertions. Targeted StyLua checks cover modified Lua files.

Final executed results: 12/12 domain tests, 57 Bridge checks, 16 View/Logic checks,
and the command/settings suite all passed. Luacheck reported zero warnings and
zero errors across 26 first-party Lua files. Changed Lua files passed StyLua checks,
and `git diff --check` passed. The standalone runner was verified using both
relative and absolute interpreter paths, including the workspace's spaces.
All 35 TOC paths and 11 FenCore XML paths resolve with exact tracked casing;
all ten non-English locale files have locale guards. Release packaging excludes
tests, developer documentation/configuration, and the library-management manifest,
while retaining LICENSE.

Mechanic MCP was unavailable in this session. All executed checks were isolated
offline checks; no live Mechanic CLI was used and installed game state was not
inferred from repository results.

After syncing the changed addon to the intended client, confirm `/reload` and
check: login while already mounted, skyriding versus steady flight, druid form
transitions, charge use/recovery and rapid reuse, entering/leaving restrictions,
profile switching, ability toggles/order, frame dragging/scale, and recovery buff
indicators. Read the selected target's `addon.output` only after that confirmation
and when Mechanic MCP is connected.
