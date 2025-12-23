---
name: Flightsim System Upgrade
overview: Upgrade Flightsim to fully integrate with the ADDON_DEV tooling system, addressing unique challenges as a standalone (non-Ace3) addon with complex real-time UI and Midnight API handling.
todos:
  - id: format-code
    content: Apply StyLua formatting to all 4 Lua files
    status: pending
  - id: create-l-table
    content: Implement minimal L table pattern in Flightsim.lua for localization
    status: pending
    dependencies:
      - format-code
  - id: create-locales
    content: Create Locales/enUS.lua with all user-facing strings
    status: pending
    dependencies:
      - create-l-table
  - id: localize-config
    content: Wrap Config.lua slash command messages with L["KEY"]
    status: pending
    dependencies:
      - create-locales
  - id: localize-settings
    content: Wrap SettingsUI.lua setting names/descriptions with L["KEY"]
    status: pending
    dependencies:
      - create-locales
  - id: update-toc
    content: Add Locales/enUS.lua to flightsim.toc load order
    status: pending
    dependencies:
      - create-locales
  - id: create-tests
    content: Create Tests/helpers_spec.lua for Clamp and color functions
    status: pending
    dependencies:
      - format-code
  - id: update-agents
    content: Update AGENTS.md with tooling, localization, and test documentation
    status: pending
    dependencies:
      - create-locales
      - create-tests
---

# Flightsim System Upgrade Plan

Flightsim is more complex than ClassyMap: ~1500 lines across 4 files, standalone (no Ace3), real-time OnUpdate loop, and extensive Midnight API compatibility work already in place.---

## Current State Assessment

| Check | Status | Notes ||-------|--------|-------|| TOC Validation | PASS | Interface 120001/120000, all files exist || Deprecation Scan | PASS | No Midnight API issues found || Luacheckrc | EXISTS | Already extends central config correctly || Formatting | NEEDS WORK | StyLua reports files need formatting || Localization | NONE | 0 localizable strings (many hardcoded) || Tests | NONE | No Tests/ directory || Custom Pattern Scan | 4 WARNINGS | See details below |

### Linting Warnings Detected

The custom pattern scanner found 4 issues:

1. **WOW005** - `SettingsUI.lua:71` - String concatenation in loop
2. **WOW001** - `UI.lua:870` - OnUpdate without obvious throttling (false positive - has throttle)
3. **WOW006** - `UI.lua:128-129` - Fallible API calls (already pcall wrapped - informational)

---

## Key Differences from ClassyMap

| Aspect | ClassyMap | Flightsim ||--------|-----------|-----------|| Framework | Ace3 | Standalone || Localization | AceLocale-3.0 | Manual implementation needed || Settings | AceConfig-3.0 | Blizzard Settings API || Complexity | ~950 lines, 2 files | ~1500 lines, 4 files || Real-time UI | Minimal | Heavy (20Hz OnUpdate) || API Sensitivity | Low | High (spell APIs, combat) |---

## Implementation Strategy

### Phase 1: Code Quality Foundation

**1.1 Apply StyLua Formatting**

- Run `format_addon("Flightsim")` to apply consistent style
- All 4 Lua files need formatting

**1.2 Address Linting Warning**

- `SettingsUI.lua:71`: The warning is a false positive (no string concat in loop at that line)
- `UI.lua:870`: False positive - OnUpdate has explicit throttling via `self._accum` accumulator
- `UI.lua:128-129`: Already correctly wrapped in pcall - informational only

### Phase 2: Localization (Manual Implementation)

Since Flightsim is standalone (no Ace3), localization requires a simple custom pattern:**2.1 Create Localization Infrastructure**

- Create `Locales/` directory
- Implement minimal `L` table pattern in `Flightsim.lua`
- Create `Locales/enUS.lua` with base strings

**Strings to localize** (from code analysis):[`Config.lua`](_dev_/Flightsim/Config.lua):

- Lines 9, 15, 19, 24, 30, etc. - Slash command output messages
- Lines 162-175 - Help text

[`SettingsUI.lua`](_dev_/Flightsim/SettingsUI.lua):

- All setting names and descriptions (35+ strings)

[`UI.lua`](_dev_/Flightsim/UI.lua):

- Line 795 - Debug/error message
- Lines 1377, 1390, etc. - Debug output prefixes

**Proposed L table pattern** (no external dependencies):

```lua
-- Flightsim.lua (top)
local L = setmetatable({}, {
    __index = function(t, k) return k end -- Fallback to key
})
Flightsim.L = L
```



### Phase 3: Testing Infrastructure

**3.1 Create Tests Directory**

- Add `Tests/` folder
- Create `Tests/helpers_spec.lua` for pure function tests

**3.2 Testable Functions**Focus on pure utility functions that don't require WoW API mocking:

- `Clamp()` function (exists in both `UI.lua` and `SettingsUI.lua`)
- `ColorForPct()`, `ColorForPctBlue()`, `ColorForPctPurple()`, `ColorForPctSurgeForward()`
- `CopyDefaults()` in `Flightsim.lua`

**3.3 Integration Test Stubs**Document test scenarios for manual verification:

- Visibility toggle behavior
- Combat lockdown handling
- Druid flight form detection

### Phase 4: Documentation Updates

**4.1 Update AGENTS.md**Add sections for:

- Tooling commands (lint, format, test)
- Localization approach
- Performance baseline expectations

---

## Files to Create/Modify

| File | Action | Purpose ||------|--------|---------|| `Locales/enUS.lua` | CREATE | Base English locale strings || `Tests/helpers_spec.lua` | CREATE | Unit tests for pure functions || `Flightsim.lua` | MODIFY | Add L table, load Locales || `Config.lua` | MODIFY | Wrap messages with L["KEY"] || `SettingsUI.lua` | MODIFY | Wrap setting text with L["KEY"] || `flightsim.toc` | MODIFY | Add Locales to load order || `AGENTS.md` | MODIFY | Add tooling documentation |---

## Validation Checklist (Post-Implementation)

```javascript
lint_addon("Flightsim")          → Warnings acknowledged/addressed
format_addon("Flightsim", true)  → No changes needed
validate_tocs()                  → PASS
extract_locale_strings()         → All strings covered
run_tests("Flightsim")           → Tests pass (requires lua.exe)
```

---

## Notes

- **OnUpdate throttling**: The WOW001 warning is a false positive. Line 870 has explicit throttling via `self._accum` and adaptive rates (20Hz visible, 2Hz hidden).
- **pcall wrapping**: WOW006 warnings are informational - the code already uses pcall correctly for combat-safe API calls.