# WoW Addon Development Guide (Living)

Last updated: 2025-12-13

This is a living reference for building and maintaining high-quality WoW Retail addons with an emphasis on:

- Reliability across patches
- Performance and combat-safety
- Debuggability and maintainability
- Preparing for expansion-level API changes (e.g., Midnight)

If a section conflicts with official Blizzard guidance for the current client, prefer Blizzard.

---

## 1) Core principles

- Prefer stable, minimal surface area: fewer dependencies, fewer hooks, fewer moving parts.
- Treat combat as a constrained runtime: assume many actions may be blocked (secure/protected, taint, restricted APIs).
- Build on events, not polling:
  - Event-driven updates are cheaper and tend to survive API changes better.
  - If you must poll (e.g., for smooth bars), throttle aggressively.
- Make every feature degradable:
  - If an API becomes unavailable, fail “closed” (hide UI / show placeholders) rather than spamming errors.
- Make debugging first-class:
  - Provide a short status command + a deep debug dump.
  - Keep internal state inspectable.

---

## 2) Project structure (recommended)

- `AddonName.toc`
- `Core.lua` (initialization + SavedVariables defaults + event routing)
- `UI.lua` (frame construction + layout)
- `Data.lua` (spell IDs, constants, lookup tables)
- `Config.lua` (slash commands / optional options UI)
- `Debug.lua` (optional, if debug grows)
- `README.md`, `SPEC.md`, `AGENTS.md`

Why:

- Keeps load order explicit.
- Separates API-facing code from UI and config.

---

## 3) TOC best practices

- Set `## Interface:` to the current build’s interface number.
- Use `## SavedVariables:` (global) or `## SavedVariablesPerCharacter:` only when needed.
- Keep the file list ordered by dependency: core → data → UI → config.
- Keep titles/notes concise; avoid localization in the TOC (prefer runtime localization).

---

## 4) SavedVariables design

- Use a single top-level table (`AddonDB`) with versioned structure.
- Prefer a “profile” shape if you anticipate per-character vs account later.
- Use defaults + deep-merge:
  - Never assume nested tables exist.
  - Keep new keys additive so older DBs upgrade smoothly.

Example pattern:

- `DEFAULTS = { profile = { ... } }`
- `CopyDefaults(DB, DEFAULTS)` on `ADDON_LOADED`

Avoid:

- Storing transient runtime-only values in SavedVariables.
- Persisting frame objects or function references.

---

## 5) UI engineering

### 5.1 Frame creation

- Prefer a single root frame with child regions.
- Keep layout logic in one place (e.g., `RebuildLayout()`), and call it when settings change.

### 5.2 Layout and sizing

- Treat layout as data-driven:
  - padding, row height, gaps, widths
- Recalculate height based on visible elements.

### 5.3 Responsiveness

- If updating on `OnUpdate`, throttle (e.g., 0.1s+), and skip work when hidden.
- Prefer events where possible:
  - spell charge/cooldown updates
  - mount/vehicle changes
  - zone changes

### 5.4 Avoid “UI spam”

- Don’t recreate frames repeatedly; recycle rows/widgets.
- If you need to rebuild, hide unused widgets instead of destroying them.

---

## 5.5 Configuration UI (Blizzard Settings)

Prefer the native Blizzard AddOn Settings APIs for in-game configuration when possible:

- Keeps dependencies minimal (no Ace3 required).
- Makes settings discoverable (Options  AddOns).
- Plays better with future API pruning than custom config frames.

Practical notes:

- Use proxy settings when backing onto SavedVariables.
- Be strict about types for dropdown values (e.g., number vs string), otherwise the Settings panel can fail to render.

---

## 6) Combat lockdown, protected actions, and taint

Combat rules are not “nice to have”—they determine whether your addon works at all.

General guidance:

- Do not attempt protected actions in combat:
  - secure button clicks
  - changing protected frame attributes
  - certain UI modifications
- Avoid insecure hooking of protected frames.
- If you need secure behavior, use secure templates correctly (and keep the insecure side minimal).

Practical pattern:

- If a setting change requires protected work, queue it:
  - If `InCombatLockdown()` then store “pending changes”
  - Apply on `PLAYER_REGEN_ENABLED`

---

## 7) Performance and efficiency

- Use local upvalues for hot paths (`local math_floor = math.floor` etc.) only if profiling shows it matters.
- Prefer caching spell IDs and icons:
  - Resolve once, reuse.
- Keep debug printing behind an explicit command.
- Avoid scanning the whole UI tree.

When you need to measure:

- Use CPU/memory profiling tools available in the client.
- Profile before optimizing.

---

## 8) API change resilience

### 8.1 Defensive programming

- Always nil-check optional APIs:
  - `if C_Something and C_Something.Fn then ... end`
- Use `pcall` around uncertain APIs (especially right after patch day) to prevent hard breakage.

### 8.2 Prefer “C\_” namespaced APIs when available

- Blizzard increasingly organizes APIs into `C_*` namespaces.
- Keep a small “compat layer” for fallback behavior.

### 8.3 Prefer stable identifiers

- Use spell IDs or stable tokens, not localized names.
- If you accept user input by name, match loosely but store a stable ID.

---

## 9) Debugging and tooling

### 9.1 In-game diagnostics

Recommended commands:

- `/addon status`: one-line “is it working?” summary
- `/addon debug`: full dump (settings, runtime state, resolved IDs, last errors if available)

### 9.2 BugGrabber / BugSack

These addons are great for capturing Lua errors without losing context.

- Use them to capture stack traces.
- Your addon should still degrade gracefully when they are not installed.

### 9.3 Logging philosophy

- Print user-facing messages sparingly.
- For deep debugging, print structured lines so users can paste logs easily.

---

## 10) Packaging and release hygiene

- Semantic-ish versioning helps: `0.x` while building, `1.0` when stable.
- Keep a small changelog section in README or a dedicated file if you publish.
- Keep `.toc` `## Version:` in sync.

---

## 11) Midnight readiness (key changes + preparation)

Important: Blizzard has signaled major API pruning in Midnight, especially in combat. Exact details can change and may not be fully documented until pre-patch/beta.

### 11.1 What to assume (safe assumptions)

- More APIs will be restricted in combat.
- Addons that rely on broad introspection/scanning may break.
- The “right” solution will often be:
  - Use Blizzard’s native UI for complex automation
  - Keep your addon focused on display/monitoring

### 11.2 Patterns that are likely to survive

- Display-only frames that do not attempt protected actions.
- Using officially supported, namespaced APIs.
- Event-driven state updates.
- Minimal / no secure frame modification during combat.

### 11.3 Patterns to avoid (high risk)

- Heavy frame scanning / global hooking of protected UI.
- Calling borderline APIs in combat “because it works today”.
- Depending on undocumented behavior.

### 11.4 How we should track Midnight changes (practical workflow)

- Maintain a “compatibility matrix” in `SPEC.md` or a dedicated section:
  - feature → APIs used → combat-safe? → fallback
- When patch/beta hits:
  - run the addon with `/console scriptErrors 1`
  - capture errors with BugGrabber/BugSack
  - update `DebugDump` to include the new signals you need
- Keep a small “compat layer” file:
  - `Compat.lua` that wraps APIs and isolates version differences

---

## 12) Midnight Secret Values (Combat API Restrictions)

Midnight (12.0) introduces "secret values" - a system where certain API return values become opaque during combat. This section documents practical patterns for handling them.

### 12.1 Detection

```lua
-- issecretvalue() is a global function in Midnight (12.0+)
-- Returns true if the value is secret, nil/false otherwise
local IS_MIDNIGHT = (select(4, GetBuildInfo()) >= 120000)

if IS_MIDNIGHT and issecretvalue and issecretvalue(someValue) then
    -- Value is secret - cannot read, compare, or do arithmetic
end
```

### 12.2 What Fails with Secret Values

Secret values error or behave unexpectedly when used in:

| Operation         | Example                        | Result |
| ----------------- | ------------------------------ | ------ |
| Comparisons       | `if charges > 0 then`          | Error  |
| Arithmetic        | `charges + 1`                  | Error  |
| String formatting | `string.format("%d", charges)` | Error  |
| tonumber()        | `tonumber(charges)`            | Error  |
| or operator       | `charges or 0`                 | Error  |
| Text display      | `fontString:SetText(charges)`  | Error  |

### 12.3 What Works with Secret Values (Passthrough)

Some Blizzard widgets accept secret values directly - they handle the opacity internally:

| Widget/Method                                   | Works? | Example                  |
| ----------------------------------------------- | ------ | ------------------------ |
| `StatusBar:SetValue(secret)`                    | ✅     | Health bars in Plater    |
| `StatusBar:SetMinMaxValues(0, secret)`          | ✅     | Health bars in Plater    |
| `Cooldown:SetCooldownDuration(secret, modRate)` | ✅     | Aura timers in Plater    |
| `ActionButton_ApplyCooldown(...)`               | ✅     | New Blizzard 12.0 helper |

### 12.4 Helper APIs for Readable Values

Blizzard provides some helper APIs that return readable values even in combat:

| Secret Source      | Helper API                                               | Returns                 |
| ------------------ | -------------------------------------------------------- | ----------------------- |
| `UnitHealth(unit)` | `UnitHealthPercent(unit)`                                | Readable percentage     |
| `UnitHealth(unit)` | `UnitHealthMissing(unit)`                                | Readable missing health |
| Aura duration      | `C_UnitAuras.GetAuraDurationRemainingByAuraInstanceID()` | Readable time left      |
| Spell charges      | **None known**                                           | N/A                     |
| Spell cooldowns    | **None known**                                           | N/A                     |

### 12.5 Common Addon Patterns

**Pattern A: Passthrough (Plater)**

```lua
-- Pass secret directly to widget - let Blizzard handle it
if IS_MIDNIGHT and issecretvalue(duration) then
    cooldownFrame:SetCooldownDuration(duration, modRate)
    -- Use helper API for text display
    local timeLeft = C_UnitAuras.GetAuraDurationRemainingByAuraInstanceID(unit, auraInstanceID)
    timerText:SetText(string.format("%d", timeLeft))
end
```

**Pattern B: Fallback (Dominos)**

```lua
-- Detect secret, use hardcoded fallback
if issecretvalue and issecretvalue(holdTimeMs) then
    local fakeHoldTimeMs = unit == "player" and 1000 or 0
    endTime = (endTimeMs + fakeHoldTimeMs) / 1000
else
    endTime = (endTimeMs + holdTimeMs) / 1000
end
```

**Pattern C: Safe Default (DBM)**

```lua
-- Return safe default when value is secret
function DBM:GetCIDFromGUID(guid)
    if issecretvalue and issecretvalue(guid) then
        return 0  -- Safe default
    end
    -- Normal processing...
end
```

**Pattern D: Disable Feature (Bartender4)**

```lua
-- Disable functionality entirely in Midnight combat
if Midnight then
    GetActionCount = function() return 0 end
end
```

### 12.6 Degraded UI Strategies

When full data isn't available, consider what partial information is still useful:

| Full UI               | Degraded Alternative         | Why It Works                                     |
| --------------------- | ---------------------------- | ------------------------------------------------ |
| "3/6 charges"         | "Has charges" / "No charges" | Binary state may not be secret                   |
| Exact cooldown timer  | Cooldown swipe animation     | `Cooldown:SetCooldownDuration()` accepts secrets |
| Charge count text     | Filled/empty bar segments    | `StatusBar:SetValue()` accepts secrets           |
| Precise values        | "Ready" / "Recharging"       | State-based rather than value-based              |
| Segmented charge bars | Single bar + "X/6" text      | Simplified but still informative                 |

### 12.7 Flightsim-Specific Considerations

For skyriding ability tracking:

- **Speed/Acceleration**: Uses `C_PlayerInfo.GetGlidingInfo()` - **confirmed working** in combat
- **Surge Forward (charges)**: `C_Spell.GetSpellCharges()` returns secrets in combat
  - Passthrough test 1: `StatusBar:SetValue(chargeInfo.currentCharges)`
  - Passthrough test 2: `FontString:SetFormattedText("%s/%s", current, max)`
  - Fallback: Show "recharging" vs "ready" without count
- **Second Wind (charges)**: Same approach as Surge Forward
- **Whirling Surge (cooldown)**: `C_Spell.GetSpellCooldown()` returns secrets
  - Passthrough option: `Cooldown:SetCooldownDuration(duration, modRate)`
  - The swipe animation may work even if we can't show text

### 12.8 Testing Checklist for Secret Value Passthrough

When testing Midnight compatibility:

1. **Enter combat while skyriding** (attack a mob, get attacked, etc.)
2. **Watch for chat messages** indicating secret detection
3. **Observe UI behavior**:
   - Does the StatusBar visually fill to the correct level?
   - Does the text show the charge count or error?
4. **Exit combat** - verify full UI restores
5. **Log results** with `/fs debug` for diagnostics

---

## 13) Reference checklist (first-run)

- `## Interface` correct for the client
- Addon loads with no Lua errors
- Frame shows/hides under the intended conditions
- Slash commands work
- SavedVariables persist across `/reload`
- Debug output is readable and complete
