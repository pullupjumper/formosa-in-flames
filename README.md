# Formosa in Flames

A **Command: Modern Operations (CMO)** scenario simulating a Taiwan Strait conflict, written in Lua. The project models large-scale multi-faction operations — **China (PLA)**, **Taiwan (ROC)**, and **United States** — with fully scripted air operations, electronic warfare, amphibious assault, ballistic/cruise missile employment, and integrated air defense.

## Features

- **Modular, event-driven architecture** orchestrated from `src/core/init.lua`.
- **Strike Planner** — ATO/FSP execution, recon-triggered operation scheduling, dynamic ATO/FSEM builders, and targeting pipelines.
- **Electronic Warfare** — GNSS jamming, communications jamming, and SIGINT.
- **Amphibious Landing Operations** — assault waves, logistics, unloading, ship movement.
- **Missile System** — TEL concealment, deployment cycles, movement, ammo, and trigger management.
- **Integrated Air Defense (IADS)**, attack manager, unit generator, runway damage/repair, bearing-only launch.
- **Embedded React UI** bundled to single-file HTMLs for CMO's in-game browser.

## Repository Layout

```
.
├── src/
│   ├── core/           # init, config, constants, schema, saveData
│   ├── utils/          # gameApi, gameUtils, utils, logger
│   ├── modules/
│   │   ├── strikePlanner/   # ATO/FSP execution, recon, dynamic operation builders, targeting
│   │   ├── ew/              # GNSS/comms jamming, SIGINT
│   │   ├── landingOps/      # amphibious assault, logistics, ship movement
│   │   ├── missileSystem/   # TEL management
│   │   └── *.lua            # IADS, attackManager, unitGenerator, ...
│   ├── scripts/        # Event handlers by faction: china/, taiwan/, us/, score/
│   └── htmls/          # Built single-file HTML UIs (output of htmls-app build)
├── htmls-app/          # React 19 + TS + Vite source for the in-game UI
├── spec/               # busted unit tests
├── docs/               # Per-module architecture docs
├── tools/              # build_lua_scenario.py — Lua bundler for CMO
├── bin/                # build.sh
├── slim/               # Processed/flattened deployment output
├── references/         # Reference materials
├── CLAUDE.md           # Guidance for Claude Code
└── AGENTS.md
```

## Requirements

- **Command: Modern Operations** (host simulation)
- **LuaJIT** and **[busted](https://lunarmodules.github.io/busted/)** for running tests
- **Python 3** for the Lua bundler
- **Node.js** (with `npm`) for `htmls-app/`

## Build & Deploy

`bin/build.sh` runs the full deployment chain end-to-end:

```bash
bash bin/build.sh         # UI build → Lua inject/merge → minify
bash bin/build.sh -t      # run busted tests first
bash bin/build.sh -n      # skip the htmls-app (npm) build
bash bin/build.sh -l      # skip luamin minification
```

Steps: **(1)** optional tests → **(2)** `npm run build` in `htmls-app/` (single-file HTMLs to `src/htmls/`) → **(3)** `tools/build_lua_scenario.py` flattens `require`s, cleans modules, and embeds the built HTML into `unitStatusUI.lua` → **(4)** `luamin` minifies.

To run only the Lua bundling step (assumes `src/htmls/` is already built):

```bash
python3 tools/build_lua_scenario.py
```

Output lands in `slim/` — `main.lua` (readable) and `_main.lua` (minified); paste the chosen one into the CMO scenario's Lua editor.

## Testing

```bash
busted --lua=luajit spec
```

Tests live under `spec/modules/` mirroring `src/modules/`.

## Architectural Conventions

### API Abstraction

All CMO API access goes through `src/utils/gameApi.lua`. Its metatable wraps every call in `Utils.safeCall()` with retries and bilingual logging.

> **Never** call raw `ScenEdit_*` functions directly — always use `GameAPI.*`.

### Two-Tier Configuration

| Layer       | File                       | Purpose                                                         |
| ----------- | -------------------------- | --------------------------------------------------------------- |
| `config.*`  | `src/core/config.lua`      | Runtime-tunable parameters (weapon counts, timing, tactics)     |
| `constants.*` | `src/core/constants.lua` | Immutable identifiers (DBIDs, base GUIDs, weapon IDs, areas)    |

Faction-scoped sub-namespaces: `.c` (China), `.t` (Taiwan), `.u` (US), `.s` (score/shared). Never hardcode DBIDs, GUIDs, or coordinates in logic.

### Type Annotations (LuaLS)

- `SBJ__*` — project-specific types
- `CMO__*` — game API types
- All public functions require `---@param` / `---@return` annotations

```lua
---Short description (≤ 2 lines)
---@param name type Description
---@param optional? type Optional parameter
---@return type # Description (single return)
---@return type varName Description (multiple returns)
```

### Event System

Scripts in `src/scripts/{faction}/{feature}/` are bound to CMO events:

| Event                  | Usage                                                  |
| ---------------------- | ------------------------------------------------------ |
| Scen Loaded            | One-time init via `src/core/init.lua`                  |
| Regular Time           | 1- or 5-minute periodic ticks                          |
| Unit Remains in Area   | Re-fires every 5 min while units occupy an area        |
| Unit Enters Area       | Area-entry trigger                                     |
| Unit Destroyed         | Loss accounting, scoring, cascading logic              |
| Unit Damaged           | Damage reactions                                       |
| Unit Base Status       | Base state transitions                                 |

## htmls-app (In-Game UI)

`htmls-app/` is **not a standalone website** — it is the React source for the scenario's **custom in-game UI panels**. Each page is bundled into a single self-contained HTML file, embedded into the Lua scenario, and rendered inside CMO through its `UI_CallAdvancedHTMLDialog` browser dialog. Panels are triggered by **Special Actions** registered in `src/core/init.lua`.

**Stack:** React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet.

### Panels

Each page lives in `src/pages/<page>/` with its own `index.html` + `main.tsx` entry and builds to `src/htmls/<page>.html`:

| Page            | In-game role                                                                   | Data injected at runtime |
| --------------- | ----------------------------------------------------------------------------- | ------------------------ |
| `setup-menu`    | Pre-game deployment menu — aircraft / jammers / missile systems / summary tabs | `__INJECT_JAMMERS__`, `__INJECT_AIRBASES__`, `__INJECT_MISSILE_SYSTEMS__`, `__INJECT_SIDE_NAME__` |
| `unit-status`   | Live status dashboard — signals, launchers, C2, base weapons, landing units   | `__INJECT_SIGNALS__`, `__INJECT_LAUNCHERS__`, `__INJECT_C2__`, `__INJECT_BASE_WEAPONS__`, `__INJECT_LANDING_UNITS__` |
| `emcon-setting` | EMCON / weapon-control-status configuration                                   | — |

### Build → Embed → Render pipeline

1. **Build** — `npm run build` (`scripts/build.js`) builds each page in turn (`BUILD_PAGE=<page> vite build`), inlining all JS/CSS via `vite-plugin-singlefile`, and emits `src/htmls/<page>.html`.
2. **Embed** — `tools/build_lua_scenario.py` reads `src/htmls/*.html`, inlines any remaining local JS, strips JS comments (to avoid Lua parse conflicts), and embeds each HTML as the return value of a template function in `src/modules/unitStatusUI.lua` (`getSetupMenuTemplate`, `getHTMLTemplate`, `getWCSSettingTemplate`).
3. **Render** — at runtime `unitStatusUI.lua` substitutes the `__INJECT_*__` placeholders with live game JSON, then calls `GameApi.UI_CallAdvancedHTMLDialog(...)` to show the panel inside CMO.

> The full chain is orchestrated by `bin/build.sh` (UI build → Lua inject/merge → minify). If you run `tools/build_lua_scenario.py` on its own, rebuild `htmls-app` first — the bundler embeds whatever currently sits in `src/htmls/`.

### Development

```bash
cd htmls-app
npm install
npm run dev       # live dev server
npm run build     # emit single-file HTMLs to ../src/htmls/
npm run lint
npm run format
```

In `dev` the `window.__INJECT_*__` globals are absent, so each page falls back to mock data in `src/data/` — letting you iterate on the UI outside CMO.
