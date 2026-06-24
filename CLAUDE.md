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

### Build and Deployment
```bash
# Full deployment build: UI build -> Lua flatten/inject -> minify
bash bin/build.sh

# Run tests before deployment build
bash bin/build.sh -t
```

### Development Mode
Set `config.isDevMode = true` in `src/core/config.lua` for development features including console logging.

## Architecture Overview

### Core System Design
The project uses a **modular event-driven architecture** centered around `src/core/init.lua` which orchestrates all game systems. Configuration is split into two files:
- `src/core/config.lua` - Runtime configuration values (weapon counts, timing, operational parameters) using nested namespaces (`.c`, `.t`, `.u`, `.s` for different factions)
- `src/core/constants.lua` - Immutable constants (platform DBIDs, base GUIDs, weapon IDs, area definitions)

### Key Architectural Patterns

**API Abstraction Layer**: All CMO game API calls are wrapped in `src/utils/gameApi.lua` with comprehensive error handling and retry logic. The metatable's `__index` method intercepts all API calls and wraps them in `Utils.safeCall()`, providing centralized error handling with automatic logging through the bilingual `Logger` module. Never call raw `ScenEdit_*` functions directly - always use the `GameAPI.*` wrappers.

**Type Safety**: Extensive use of LuaLS annotations with project-specific type prefixes:
- `SBJ__*` for project-specific types
- `CMO__*` for game API types
- All public functions must have `---@param` and `---@return` annotations

**Annotation Standards**:

```lua
---Function description (maximum 2 lines)
---@param name type Description
---@param optional? type Optional parameter description
---@return type # Description (single return)
---@return type varName Description (multiple returns)
```

- Use `---Description` (no space after `---`), start with uppercase letter
- Single return uses `#` separator; multiple returns include variable names
- Use semantic variable names (`success`, `count`, `error`), avoid Lua keywords

**Configuration Management**:
The project uses a two-tier configuration system:

- **`config.*`** (`src/core/config.lua`): Runtime parameters that may need tuning (weapon defaults, timing, tactical settings)
- **`constants.*`** (`src/core/constants.lua`): Immutable identifiers (platform DBIDs, base GUIDs, weapon IDs, area definitions)

**Best Practices**:
- Use `config.*` for values that control gameplay behavior and may need adjustment
- Use `constants.*` for immutable identifiers that reference game database entries
- Never hardcode DBIDs, GUIDs, or coordinates directly in logic

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

Use `bash bin/build.sh` for deployment builds. It optionally runs busted tests with `-t`, builds `htmls-app` pages into `src/htmls/*.html`, runs `tools/build_lua_scenario.py`, then writes `slim/main.lua` and minifies or copies it to `slim/_main.lua`.

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

The `htmls-app/` directory contains React-based UI panels for CMO's embedded browser. Build output goes to `src/htmls/*.html`; deployment injection is handled by `bin/build.sh`.

### Tech Stack
React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet/react-leaflet. Uses `vite-plugin-singlefile` to bundle into single HTML files. ESLint 9 + Prettier for code quality.

### Project Structure
```
htmls-app/src/
├── components/     # Shared components
├── pages/          # Each page has its own main.tsx entry point
├── types/          # TypeScript type definitions
├── utils/          # Utility functions
├── data/           # Static mock data for development
└── index.css       # Global styles + Tailwind @theme custom colors
```

### Code Style
- Function components + React Hooks only (no class components)
- Props defined with `interface`, named `{ComponentName}Props`
- Use `import type { ... }` for type imports
- Path aliases: `@/`, `@components/`, `@pages/`, `@utils/`, `@types/`
- Section separators: `// ============================================================================`
- State management: React built-in Hooks only (no external state libraries)
- Styling: Tailwind utility classes only; custom colors defined in `index.css` `@theme`
- Utility functions: Pure functions with named exports and JSDoc comments

### Data Flow
HTML pages use `window.__INJECT_*__` placeholders. `unitStatusUI.lua` fills them with runtime JSON via `string.format`; during frontend development they fall back to mock data from `src/data/`.

### Build Commands
```bash
cd htmls-app
npm run dev          # Development server
npm run build        # Rebuild src/htmls only; full deployment uses bin/build.sh
npm run lint         # Run ESLint
npm run format       # Format with Prettier
```
