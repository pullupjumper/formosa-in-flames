# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Command: Modern Operations (CMO)** military simulation scenario written in **Lua**. The project simulates a Taiwan Strait conflict with sophisticated systems for air operations, electronic warfare, amphibious assaults, and multi-faction coordination (China, Taiwan, US).

## Essential Commands

### Testing
```bash
# Run all tests (from project root)
busted --lua=luajit spec
```

### Linting
```bash
# LuaLS check (warn only, never blocks the build); add -v for details
bash bin/build.sh -c -n -l -i
```
Run after editing Lua; do not add new warnings.

### Build and Deployment
```bash
# Full deployment build: UI build -> Lua flatten/inject -> minify -> inject into .scen (in place, keeps .bak)
bash bin/build.sh

# Run tests before deployment build
bash bin/build.sh -t

# Target a specific scen / skip scen injection
bash bin/build.sh -s path/to.scen
bash bin/build.sh -i
```

## Architecture Overview

### Core System Design
The project uses a **modular event-driven architecture** centered around `src/core/init.lua` which orchestrates all game systems. Configuration is split into two files:
- `src/core/config.lua` - Runtime configuration values (weapon counts, timing, operational parameters) using nested namespaces (`.c`, `.t`, `.u` for China, Taiwan, US)
- `src/core/constants.lua` - Immutable constants (platform DBIDs, base GUIDs, weapon IDs, area definitions)

### Key Architectural Patterns

- **API Abstraction**: All CMO game API calls use `src/utils/gameApi.lua` wrappers. Never call raw `ScenEdit_*` functions directly.
- **Type Safety**: Use LuaLS annotations (`---@param`, `---@return`) with prefixes `SBJ__*` (project types) and `CMO__*` (game API types).
- **Naming**: Follow `docs/naming.md` for file, module, function, variable, parameter, type, and config key naming.
- **Config vs Constants**: Use `config.*` for gameplay values that may need adjustment; use `constants.*` for immutable identifiers (DBIDs, GUIDs, area definitions).
- **No Hardcoding**: Never hardcode DBIDs, GUIDs, or coordinates directly in logic.
- **Package Facades**: A module folder with an `init.lua` (`missileSystem/`, `strikePlanner/`, `landingOps/`) is a package. Code outside the folder requires only its `init.lua`; files inside the folder call each other directly, never through their own facade. `spec/moduleBoundary_spec.lua` enforces this. Facade functions that only forward are fine at the boundary; prefer ones that also hide internals (e.g. take `sideName` and resolve config/state themselves).

### Module Organization

```
src/
├── core/           # init, config, constants, schema, saveData
├── utils/          # gameApi, gameUtils, utils, logger
├── modules/
│   ├── strikePlanner/  # ATO/FSP execution, recon, dynamic operation builders, targeting (docs/strikePlanner/)
│   ├── ew/             # GNSS/comms jamming, SIGINT (docs/ew/)
│   ├── landingOps/     # Amphibious assault, logistics, ship movement (docs/landingOps/)
│   ├── missileSystem   # TEL management (docs/missileSystem.md)
│   └── ...             # unitGenerator, assignMission, attackManager, etc.
└── scripts/        # Event handlers organized by faction (china/, taiwan/, us/, score/)
```

See `docs/` for detailed module architecture documentation.

### CMO Build And Runtime Constraints

CMO cannot run this project directly from modular Lua source because runtime Lua module/filesystem APIs such as normal `require` are unavailable or restricted. Treat `src/` as development source only; CMO deployment must use the generated single-file output.

Use `bash bin/build.sh` for deployment builds. It optionally runs busted tests with `-t`, builds `htmls-app` pages into `src/htmls/*.html`, runs `tools/build_lua_scenario.py`, writes `slim/main.lua`, minifies or copies it to `slim/_main.lua`, then runs `tools/cmo_scen_v5_decoder.py inject --in-place` to replace the `main.lua` `<ScriptText>` inside the encrypted `.scen` (path from `SCEN_PATH` in the script or `-s`; previous file kept as `.scen.bak`). Needs Python `lz4` and `cryptography`.

`tools/build_lua_scenario.py` strips project-local `require` lines, comments, and module-level `return`; promotes module table declarations when needed; orders `core/`, `utils/`, and `modules/` by priority plus source `require` dependency analysis; injects `src/htmls/*.html` into `unitStatusUI.lua`; and expands `src/core/init.lua` event/special-action loops by embedding processed `src/scripts/**` as CMO `ScriptText`.

Do not edit `slim/` manually. Change `src/`, `src/scripts/`, or `htmls-app/`, then rebuild. When adding event scripts or special actions, also register their path/action name in `src/core/init.lua`; the bundler uses those lists to inject script bodies. Avoid runtime dependencies on `io`, `package`, `dofile`, `loadfile`, dynamic `require`, or filesystem access in code that must run inside CMO.

### Event System

CMO drives scenario behavior through event-bound Lua scripts under `src/scripts/{faction}/{feature}/`. Register event action paths and special actions in `src/core/init.lua`; the bundler injects those script bodies into CMO actions during deployment.

Common event usage:
- **Scen Loaded** - One-time initialization through `src/core/init.lua`
- **Regular Time** - Periodic systems such as strike planning, EW, reload/hide checks, and runway repair
- **Unit Remains in Area** - Repeated area checks, usually every 5 minutes
- **Unit Enters Area** - Area-entry reactions
- **Unit Destroyed** / **Unit Damaged** - Loss accounting, scoring, and cascading reactions
- **Unit Base Status** - Base state transitions

## htmls-app (React UI)

`htmls-app/` holds the React panels shown in CMO's embedded browser. `bin/build.sh` builds them into `src/htmls/*.html`, which `unitStatusUI.lua` fills via `window.__INJECT_*__` placeholders.

When working inside `htmls-app/`, read `htmls-app/CLAUDE-FRONTEND.md` first — it owns the tech stack, code style, naming conventions, data flow, and test guidance for the frontend.
