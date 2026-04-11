# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Command: Modern Operations (CMO)** military simulation scenario written in **Lua**. The project simulates a Taiwan Strait conflict with sophisticated systems for air operations, electronic warfare, amphibious assaults, and multi-faction coordination (China, Taiwan, US).

## Essential Commands

### Testing
```bash
# Run all tests (from project root)
busted --lua=luajit spec

# Run specific test file
busted --lua=luajit spec/modules/missileSystem_spec.lua
```

### Build and Deployment
```bash
# Process Lua modules for deployment (removes requires, cleans modules)
python3 tools/build_lua_scenario.py

# Clean only (src -> slim)
python3 tools/build_lua_scenario.py --clean-only

# Merge only (slim -> main.lua)
python3 tools/build_lua_scenario.py --merge-only
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
│   ├── strikePlanner/  # ATO, fire support, recon, targeting (docs/strikePlanner/)
│   ├── ew/             # GNSS/comms jamming, SIGINT (docs/ew/)
│   ├── landingOps/     # Amphibious assault, logistics, ship movement (docs/landingOps/)
│   ├── missileSystem   # TEL management (docs/missileSystem.md)
│   └── ...             # unitGenerator, assignMission, attackManager, etc.
└── scripts/        # Event handlers organized by faction (china/, taiwan/, us/, score/)
```

See `docs/` for detailed module architecture documentation.

### Event System

CMO provides several event types that trigger the scripts in `src/scripts/`:

- **Unit Remains in Area** - Triggers every 5 minutes when units stay within defined areas
- **Unit Enters Area** - Triggers when units enter defined areas
- **Unit Destroyed** - Triggers when units are destroyed
- **Unit Damaged** - Triggers when units take damage
- **Unit Base Status** - Triggers on base status changes
- **Regular Time** - Scheduled events at 1-minute or 5-minute intervals
- **Scen Loaded** - Triggers once when scenario initializes; `src/core/init.lua` orchestrates all system initialization

Scripts are organized under `src/scripts/{faction}/{feature}/` by faction and event type.

## htmls-app (React UI)

The `htmls-app/` directory contains React-based UI components that are built into single HTML files for CMO's embedded browser.

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
CMO game engine injects JSON data via `window.__INJECT_*__` globals. Components parse with `parseJSON()` and fall back to mock data from `src/data/` during development.

### Build Commands
```bash
cd htmls-app
npm run dev          # Development server
npm run build        # Build all pages to ../src/htmls/
npm run lint         # Run ESLint
npm run format       # Format with Prettier
```
