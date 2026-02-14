# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Command: Modern Operations (CMO)** military simulation scenario written in **Lua**. The project simulates a Taiwan Strait conflict with sophisticated systems for air operations, electronic warfare, amphibious assaults, and multi-faction coordination (China, Taiwan, US).

## Essential Commands

### Testing
```bash
# Run all tests (from project root)
busted test

# Run specific test file
busted test/modules/missileSystem_spec.lua
```

**Claude Code Testing Note**:
Claude Code runs commands via Git Bash (MSYS2), where `.bat` files cannot be executed directly. Use `cmd.exe //c` to run busted:
```bash
# Run tests from Claude Code
cd /d/codes/lua/CMOScripts/formosa-in-flames && cmd.exe //c "busted test"

# Run specific test file
cd /d/codes/lua/CMOScripts/formosa-in-flames && cmd.exe //c "busted test\\modules\\missileSystem_spec.lua"
```

### Build and Deployment
```bash
# Process Lua modules for deployment (removes requires, cleans modules)
python tools/build_lua_scenario.py

# On Windows Traditional Chinese systems, set UTF-8 encoding (script uses emoji characters)
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py

# Clean only (src -> slim)
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py --clean-only

# Merge only (slim -> main.lua)
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py --merge-only
```

**Windows Encoding Note**:
- Windows Traditional Chinese systems default to CP950 encoding, which cannot display emoji characters (🚀, 🧹, 💉, etc.) used in Python scripts
- Must set `PYTHONIOENCODING=utf-8` environment variable before execution
- This is a Windows OS limitation, not a code issue

### Development Mode
Set `config.isDevMode = true` in `src/core/config.lua` for development features including console logging.

## Architecture Overview

### Core System Design
The project uses a **modular event-driven architecture** centered around `src/core/init.lua` which orchestrates all game systems. Configuration is split into two files:
- `src/core/config.lua` - Runtime configuration values (weapon counts, timing, operational parameters) using nested namespaces (`.c`, `.t`, `.u`, `.s` for different factions)
- `src/core/constants.lua` - Immutable constants (platform DBIDs, base GUIDs, weapon IDs, area definitions)

### Key Architectural Patterns

**API Abstraction Layer**: All CMO game API calls are wrapped in `src/utils/gameApi.lua` with comprehensive error handling and retry logic. Never call CMO APIs directly - always use the wrapper functions.

**Type Safety**: Extensive use of LuaLS annotations with project-specific type prefixes:
- `SBJ__*` for project-specific types
- `CMO__*` for game API types
- All public functions must have `---@param` and `---@return` annotations

**Annotation Standards**:

*Function Annotations*:
```lua
---Function description (maximum 2 lines)
---Second line of description if needed
---@param name type Description
---@param optional? type Optional parameter description
---@return type # Description (single return)
---@return type varName Description (multiple returns)
```

*Key Rules*:
- **Function descriptions**: Maximum 2 lines, use `---Description` (no space after `---`), start with uppercase letter
- **Single return**: Use `#` separator → `---@return type # Description`
- **Multiple returns**: Include variable names → `---@return type varName Description`
- **Parameters**: No `--` separator, direct description after type
- **Variable names**: Use semantic names (`success`, `count`, `error`) not generic (`result1`, `result2`)
- **Reserved words**: Avoid Lua keywords as variable names (use `num` not `number`)

Examples:
```lua
---Get unit by GUID or name
---@param guid string The GUID or name of the unit
---@param sideName? string Optional side name
---@return CMO__Unit|nil # Unit object or nil if not found
function GameApi.ScenEdit_GetUnit(guid, sideName)

---Safely call a function with error handling
---@param funcName string Function name for error context
---@param func function The function to call
---@return any|nil result Function result or nil on error
---@return string|nil error Error message or nil on success
function Utils.safeCall(funcName, func, ...)
```

**Error Handling Strategy**: All CMO API calls through `GameAPI` are automatically wrapped with error handling via `setmetatable`. The metatable's `__index` method intercepts all API calls and wraps them in `Utils.safeCall()`, providing centralized error handling with automatic logging through the bilingual `Logger` module. Errors are logged with context and functions return `nil` on failure. Never call raw `ScenEdit_*` functions directly - always use the `GameAPI.*` wrappers.

**Configuration Management**:
The project uses a two-tier configuration system for better organization and maintainability:

**Runtime Configuration** (`src/core/config.lua`):
- Operational parameters that may need tuning (weapon defaults, ammunition thresholds, reload times)
- Timing configurations (trigger start times, intervals)
- Tactical settings (jamming ranges, detection parameters)
- Uses prominent section header format for easy navigation:
  ```lua
  -- ============================================================================
  -- Configuration Section Name
  -- ============================================================================
  ```
- Structured namespacing:
  - `config.c.*` (China) - Chinese faction configuration
  - `config.t.*` (Taiwan) - Taiwanese faction configuration
  - `config.u.*` (US) - US faction configuration
  - `config.s.*` (Scoring) - Scoring system configuration
  - `config.repairRunway.*` - Runway repair configuration
  - `config.targetScanning.*` - Target scanning configuration

**Immutable Constants** (`src/core/constants.lua`):
- Platform database IDs (DBIDs) for units, weapons, and systems
- Base GUIDs identifying specific installations
- Weapon system identifiers
- Geographic area definitions and coordinates
- Loadout identifiers
- Never modify these at runtime - they define the game's data model

**Best Practices**:
- Use `config.*` for values that control gameplay behavior and may need adjustment
- Use `constants.*` for immutable identifiers that reference game database entries
- Never hardcode DBIDs, GUIDs, or coordinates directly in logic
- Reference from appropriate configuration file based on whether value is mutable

**Scoring System** (`config.s.*`):
The scoring configuration defines point values awarded or deducted when units are destroyed. Event handlers reference these values:
- `src/scripts/score/taiwaneseAssetIsDestroy.lua` - Tracks scoring when Taiwanese assets are destroyed
- `src/scripts/score/destroyUnits.lua` - General unit destruction scoring logic
- `src/scripts/score/successfulLanding.lua` - Scoring for successful amphibious landing objectives

### Module Organization

**Core Systems** (`src/core/`):
- `init.lua` - Main entry point and system orchestration
- `config.lua` - Runtime configuration values (weapon counts, timing, tactical parameters) organized by faction with prominent section headers
- `constants.lua` - Immutable constants (platform DBIDs, base GUIDs, weapon IDs, area definitions)
- `schema.lua` - Type definitions with LuaLS annotations
- `saveData.lua` - Persistent state management with prominent section headers for organization

**Utilities** (`src/utils/`):
- `gameApi.lua` - **Critical**: CMO API wrapper with error handling - use for all API calls
- `gameUtils.lua` - Higher-level game operations (positioning, missions, formations)
- `utils.lua` - Foundation utilities (table operations, string manipulation, mathematical calculations, safe function calls)
- `logger.lua` - Bilingual logging system (auto-detects game/dev environment)

**Feature Modules** (`src/modules/`):
- `unitGenerator.lua` - Unit creation with formation logic and cleanup
- `assignMission.lua` - Mission assignment and management
- `attackManager.lua` - Combat coordination
- `runwayRepairment.lua` - Runway damage assessment and repair scheduling
- `integratedAirDefenseSystem.lua` - Integrated Air Defense System coordination
- `unitStatusUI.lua` - Unit status monitoring and UI generation
- `missileSystem.lua` - TEL (Transporter Erector Launcher) management for mobile missile systems

**Specialized Subsystems**:

**Strike Planning** (`src/modules/strikePlanner/`):
- `airTaskingOrder.lua` - ATO execution and coordination
- `fireSupportPlan.lua` - Fire Support Execution Matrix (FSEM) management
- `dynamicFireSupportPlan.lua` - **Dynamic Fire Support Planning** with BDA-based automated FSEM creation
- `recon.lua` - Reconnaissance mission scheduling and management
- `targetingProcess.lua` - Target selection and prioritization
- `dynamicATOInsertion.lua` - Dynamic ATO insertion based on intelligence
- `dynamicOperationsUtils.lua` - Utilities for dynamic operations coordination

**Electronic Warfare** (`src/modules/ew/`):
- `gnssJamming.lua` - GNSS denial operations
- `commsJamming.lua` - Communications jamming coordination
- `sigint.lua` - Signals intelligence collection and processing

**Amphibious Operations** (`src/modules/landingOps/`):
- `amphibiousAssault.lua` - Core amphibious assault logic (ACV launches, LST operations)
- `amphibiousLogistics.lua` - Cargo transfer and logistics management
- `shipMovement.lua` - Landing ship movement and positioning calculations
- `secondWaveUnloading.lua` - Second wave logistics (barge, RORO operations)

**Faction Scripts** (`src/scripts/`): Event handlers organized by faction (china/, taiwan/, us/). These scripts are triggered by CMO game events.

### Event System

CMO provides several event types that trigger the scripts in `src/scripts/`:

**Event Types**:
- **Unit Remains in Area** - Triggers every 5 minutes when units stay within defined areas
- **Unit Enters Area** - Triggers when units enter defined areas
- **Unit Destroyed** - Triggers when units are destroyed
- **Unit Damaged** - Triggers when units take damage
- **Unit Base Status** - Triggers on base status changes
- **Regular Time** - Scheduled events that trigger at regular intervals:
  - 1-minute intervals for high-frequency tasks
  - 5-minute intervals for periodic operations
- **Scen Loaded** - Triggers once when scenario initializes

Event handlers in `src/scripts/` are organized by faction and event type, coordinating real-time responses to simulation state changes.

**Unit Destroyed Event Scripts**:
- `src/scripts/score/taiwaneseAssetIsDestroy.lua` - Score tracking for destroyed Taiwanese assets
- `src/scripts/score/destroyUnits.lua` - General unit destruction scoring and tracking

**Unit Base Status Event Scripts**:
- `src/scripts/china/aircraftLanding.lua` - China aircraft landing and base operations
- `src/scripts/taiwan/aircraftLanding.lua` - Taiwan aircraft landing and base operations

**Unit Damaged Event Scripts**:
- `src/scripts/runwayIsDamaged.lua` - Runway damage detection and repair scheduling

**Unit Remains in Area Event Scripts** (5-minute intervals):
- `src/scripts/china/amphibiousOps/launchACV.lua` - Launch Air Cushion Vehicles from landing ships
- `src/scripts/china/amphibiousOps/offloadVehicles.lua` - Offload vehicles from landing craft

**Unit Enters Area Event Scripts**:
- `src/scripts/china/amphibiousOps/neutralizeAirlandingZone.lua` - Air landing zone neutralization operations
- `src/scripts/china/launchWZ8.lua` - H-6N launch WZ-8 reconnaissance drone operations
- `src/scripts/china/csgEnterArea.lua` - China Carrier Strike Group area entry handling
- `src/scripts/china/missileSystem/moveToPosition.lua` - China TEL move to each positions
- `src/scripts/taiwan/missileSystem/moveToPosition.lua` - Taiwan TEL move to each positions
- `src/scripts/score/successfulLanding.lua` - Score tracking for successful amphibious landings

**1-Minute Regular Time Event Scripts**:
- `src/scripts/china/ew/commsJamming.lua` - China communications jamming operations

**5-Minute Regular Time Event Scripts**:
- `src/scripts/china/amphibiousOps/landingCheck.lua` - Monitors amphibious landing progress
- `src/scripts/china/ew/collectSigint.lua` - China SIGINT collection operations
- `src/scripts/china/scheduledStrikePlanner.lua` - China strike planning coordination
- `src/scripts/china/missileSystem/scheduledReloadHideCheck.lua` - China TEL reload/hide status monitoring
- `src/scripts/taiwan/missileSystem/scheduledReloadHideCheck.lua` - Taiwan TEL reload/hide status monitoring
- `src/scripts/us/collectSigint.lua` - US SIGINT collection operations
- `src/scripts/scheduledRunwayRepairment.lua` - Automated runway damage repair scheduling

**Scen Loaded Event**:
All core systems (`src/core/`), modules (`src/modules/`), and utilities (`src/utils/`) are initialized when the scenario loads. The main entry point `src/core/init.lua` orchestrates the initialization of all game systems, configuration loading, and module setup at scenario start.

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

## Critical Development Guidelines

### API Usage Patterns
- Wrap all `ScenEdit_*` calls in `GameAPI.*` equivalents
- Validate API responses before proceeding with operations
- Use descriptive unit names following military conventions
- Implement fallback behaviors for API failures

### Testing Approach
- Unit tests located in `test/modules/` using Busted framework
- Mock game APIs comprehensively for isolated testing
- Test critical modules like `assignMission.lua` and `unitGenerator.lua`
- Run tests before deployment: `busted test` from project root
- Claude Code must use `cmd.exe //c "busted test"` due to Git Bash environment
