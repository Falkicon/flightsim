# Continuous integration

The `Quality` workflow runs for pull requests targeting `main` and for pushes
to `main`. It uses an Ubuntu 24.04 runner and performs the same checks that can
be run locally:

```text
lua5.1 Tests/run.lua
python3 Tests/validate_repo.py
luacheck . --config .luacheckrc
stylua --check --syntax Lua51 \
  Flightsim.lua Config.lua Settings.lua \
  Logic/*.lua Bridge/*.lua View/*.lua Locales/*.lua Tests/*.lua \
  Libs/FenCore/Domains/Charges.lua \
  Libs/FenCore/Domains/Cooldowns.lua
```

The repository validator uses Python's standard library. It checks every TOC
entry and every recursive XML `file` reference with exact path spelling, then
checks locale guards, duplicate keys, complete key parity with `enUS`, and all
direct `L["KEY"]` references in first-party runtime Lua. This catches the
case-insensitive Windows lookup trap before an addon package reaches WoW.

Luacheck reads the self-contained [`.luacheckrc`](../.luacheckrc), which keeps
tests and embedded libraries out of that lint pass. StyLua checks the complete
first-party baseline plus the two FenCore domain files changed for the buffer
API. The baseline is intentionally explicit so future edits cannot silently
leave an older file unformatted.

The workflow pins Luacheck to 0.23.0 and StyLua to the immutable 2.3.1 release.
The only action is `actions/checkout` v6.0.3 pinned to its release commit.
These versions are documented by the [Luacheck project](https://github.com/mpeterv/luacheck),
the [StyLua 2.3.1 release](https://github.com/JohnnyMorganz/StyLua/releases/tag/v2.3.1),
and the [checkout 6.0.3 release](https://github.com/actions/checkout/releases/tag/v6.0.3).

On Windows, use the Lua 5.1, Luacheck, and StyLua binaries in the sibling
Mechanic desktop tool directory, or install equivalent pinned versions. The
game must be reloaded separately for live verification; CI and these commands
exercise the offline test harness and repository structure only.
