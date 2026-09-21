# Formosa in Flames

A **Command: Modern Operations (CMO)** scenario simulating a Taiwan Strait conflict (PLA / Taiwan / US), scripted in Lua with an embedded React UI.

## Quick Start

```bash
# 1. Tools (WSL2 / Ubuntu)
sudo apt install luajit luarocks
luarocks --local install busted                    # add ~/.luarocks/bin to PATH
python3 -m pip install --user lz4 cryptography     # add --break-system-packages on Debian/Ubuntu
npm install -g luamin
(cd htmls-app && npm install)

# 2. Point the build at your scenario
#    edit SCEN_PATH at the top of bin/build.sh (or pass -s each run)

# 3. Build and deploy — close the scenario in CMO first, reload after
bash bin/build.sh
```

`build.sh` builds the UI, bundles the Lua, minifies it, and **overwrites the `.scen` file in place**. A backup is kept as `<name>.scen.bak` (only the latest).

### build.sh flags

```
-s <scen>   target scen file (default: SCEN_PATH in the script)
-t          run busted + vitest first
-n          skip npm build
-l          skip luamin
-i          skip scen injection (only produce slim/)
-x <glob>   exclude Lua files from the merge (repeatable)
```

### Run pieces by hand

```bash
busted --lua=luajit spec                                       # Lua tests
(cd htmls-app && npm run dev)                                  # UI dev server with mock data
python3 tools/build_lua_scenario.py                            # bundle only -> slim/main.lua, slim/_main.lua
python3 tools/cmo_scen_v5_decoder.py decode <scen>             # dump <scen>.decoded.xml
python3 tools/cmo_scen_v5_decoder.py inject <scen> --in-place  # inject slim/_main.lua, keep .bak
```

## Layout

```
src/core/       init, config, constants, saveData
src/utils/      gameApi (all CMO calls go through here), utils, logger
src/modules/    strikePlanner/, ew/, landingOps/, missileSystem/, IADS, ...
src/scripts/    CMO event handlers by faction: china/, taiwan/, us/, score/
src/htmls/      built single-file HTMLs (output of htmls-app)
htmls-app/      React 19 + Vite source for in-game panels
spec/           busted tests, mirrors src/modules/
docs/           per-module architecture docs
tools/          build_lua_scenario.py (bundler), cmo_scen_v5_decoder.py (scen decrypt/inject)
slim/           bundled output: main.lua (readable), _main.lua (minified)
```

## Rules of the Road

- **Never call `ScenEdit_*` directly.** Use `GameAPI.*` (`src/utils/gameApi.lua`); it wraps every call with retries and logging.
- **UI data flow:** Lua fills `__INJECT_*__` placeholders in the built HTML, then opens it with `UI_CallAdvancedHTMLDialog`. In `npm run dev` those globals are absent and pages fall back to mock data in `htmls-app/src/data/`.

See `AGENTS.md` and `docs/` for module-level detail.
