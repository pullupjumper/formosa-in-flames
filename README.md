# Formosa in Flames

A **Command: Modern Operations (CMO)** scenario simulating a Taiwan Strait conflict, written in Lua. The project models large-scale multi-faction operations — **China (PLA)**, **Taiwan (ROC)**, and **United States** — with fully scripted air operations, electronic warfare, amphibious assault, ballistic/cruise missile employment, and integrated air defense.

## Highlights

- **Modular, event-driven architecture** orchestrated from `src/core/init.lua`.
- **Strike Planner** — Air Tasking Order (ATO), dynamic ATO insertion, fire support plans, recon, and targeting pipelines.
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
│   │   ├── strikePlanner/   # ATO, fire support, recon, targeting
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

Bundle Lua modules into a CMO-loadable scenario (flattens `require`s and cleans modules):

```bash
python3 tools/build_lua_scenario.py
# or
bash bin/build.sh
```

Processed output lands under `slim/` and can be injected into the CMO scenario.

## Testing

```bash
busted --lua=luajit spec
```

Tests live under `spec/modules/` mirroring `src/modules/`.

## Development Mode

Enable development features (console logging, debug paths):

```lua
-- src/core/config.lua
config.isDevMode = true
```

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

## htmls-app (React UI)

React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet. Each page has its own `main.tsx` entry and is bundled into a single HTML file via `vite-plugin-singlefile` for CMO's embedded browser.

```bash
cd htmls-app
npm install
npm run dev       # development server
npm run build     # emits single-file HTMLs to ../src/htmls/
npm run lint
npm run format
```

CMO injects JSON through `window.__INJECT_*__` globals; components fall back to mock data in `src/data/` during development.

See `htmls-app/README.md` for UI-specific details.

## Documentation

Per-module architecture docs (Mermaid diagrams, tables, data structures):

- [`docs/strikePlanner/`](docs/strikePlanner/README.md) — ATO, dynamic ATO insertion, fire support, recon, targeting
- [`docs/ew/`](docs/ew/README.md) — GNSS jamming, comms jamming, SIGINT
- [`docs/landingOps/`](docs/landingOps/README.md) — amphibious assault, logistics, ship movement, unloading
- [`docs/missileSystem/`](docs/missileSystem/README.md) — TEL concealment, deployment, movement, triggers, ammo

Additional guidance:

- [`CLAUDE.md`](CLAUDE.md) — working conventions for Claude Code
- [`AGENTS.md`](AGENTS.md) — agent-facing notes
