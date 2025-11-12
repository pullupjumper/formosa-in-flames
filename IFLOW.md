# IFLOW.md - Formosa in Flames

## Project Overview

This is a **Command: Modern Operations (CMO)** military simulation scenario written in **Lua**. The project simulates a Taiwan Strait conflict with sophisticated systems for air operations, electronic warfare, amphibious assaults, and multi-faction coordination (China, Taiwan, US).

## Essential Commands

### Testing
```bash
# Run all tests (from test directory)
busted

# Run specific test file
busted modules/assignMission_spec.lua
```

### Build and Deployment
```bash
# Process Lua modules for deployment (removes requires, cleans modules)
python tools/build_lua_scenario.py
```

### Development Mode
Set `config.isDevMode = true` in `src/core/constants.lua` for development features including console logging.

## Architecture Overview

### Core System Design
The project uses a **modular event-driven architecture** centered around `src/core/init.lua` which orchestrates all game systems. Configuration is centralized in `src/core/constants.lua` using nested namespaces (`.c`, `.t`, `.u`, `.s` for different factions).

### Key Architectural Patterns

**API Abstraction Layer**: All CMO game API calls are wrapped in `src/utils/gameApi.lua` with comprehensive error handling and retry logic. Never call CMO APIs directly - always use the wrapper functions.

**Type Safety**: Extensive use of LuaLS annotations with project-specific type prefixes:
- `SBJ__*` for project-specific types
- `CMO__*` for game API types
- All public functions must have `---@param` and `---@return` annotations

**Error Handling Strategy**: All CMO API calls through `GameAPI` are automatically wrapped with error handling via `setmetatable`. The metatable's `__index` method intercepts all API calls and wraps them in `Utils.safeCall()`, providing centralized error handling with automatic logging through the bilingual `Logger` module. Errors are logged with context and functions return `nil` on failure. Never call raw `ScenEdit_*` functions directly - always use the `GameAPI.*` wrappers.

**Configuration Management**:
- All platform DBIDs, base GUIDs, and operational parameters are constants in `src/core/constants.lua`
- Use structured namespacing:
  - `config.c.*` (China) - Chinese faction configuration
  - `config.t.*` (Taiwan) - Taiwanese faction configuration
  - `config.u.*` (US) - US faction configuration
  - `config.s.*` (Scoring) - Scoring system configuration defining point values for unit destruction events
- Never hardcode military platform IDs or coordinates

**Scoring System** (`config.s.*`):
The scoring configuration defines point values awarded or deducted when units are destroyed. Event handlers reference these values:
- `src/scripts/score/taiwaneseAssetIsDestroy.lua` - Tracks scoring when Taiwanese assets are destroyed
- `src/scripts/score/destroyUnits.lua` - General unit destruction scoring logic
- `src/scripts/score/successfulLanding.lua` - Scoring for successful amphibious landing objectives

### Module Organization

**Core Systems** (`src/core/`):
- `init.lua` - Main entry point and system orchestration
- `constants.lua` - Centralized configuration (platform DBIDs, base GUIDs, operational areas)
- `schema.lua` - Type definitions with LuaLS annotations
- `saveData.lua` - Persistent state management

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
- `IADS.lua` - Integrated Air Defense System coordination
- `unitStatusUI.lua` - Unit status monitoring and UI generation
- `launcher.lua` - TEL (Transporter Erector Launcher) management for mobile missile systems

**Specialized Subsystems**:

**Strike Planning** (`src/modules/strikePlanner/`):
- `airTaskingOrder.lua` - ATO execution and coordination
- `fireSupportPlan.lua` - Fire Support Execution Matrix (FSEM) management
- `dynamicFireSupportPlan.lua` - **Dynamic Fire Support Planning** with BDA-based automated FSEM creation
- `recon.lua` - Reconnaissance mission scheduling and management
- `targetingProcess.lua` - Target selection and prioritization
- `dynamicATOInsertion.lua` - Dynamic ATO insertion based on intelligence
- `dynamicOperationsUtils.lua` - Utilities for dynamic operations coordination

**Electronic Warfare** (`src/modules/EW/`):
- `GPSJamming.lua` - GPS denial operations
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
- `src/scripts/china/recon/H6NLaunchWZ8.lua` - H-6N launch WZ-8 reconnaissance drone operations
- `src/scripts/china/CSGEnterArea.lua` - China Carrier Strike Group area entry handling
- `src/scripts/china/launcher/moveToPosition.lua` - China TEL move to each positions
- `src/scripts/taiwan/launcher/moveToPosition.lua` - Taiwan TEL move to each positions
- `src/scripts/score/successfulLanding.lua` - Score tracking for successful amphibious landings

**1-Minute Regular Time Event Scripts**:
- `src/scripts/china/EW/commsJamming.lua` - China communications jamming operations

**5-Minute Regular Time Event Scripts**:
- `src/scripts/china/amphibiousOps/landingCheck.lua` - Monitors amphibious landing progress
- `src/scripts/china/EW/collectSIGINT.lua` - China SIGINT collection operations
- `src/scripts/china/scheduledStrikePlanner.lua` - China strike planning coordination
- `src/scripts/china/launcher/scheduledReloadHideCheck.lua` - China TEL reload/hide status monitoring
- `src/scripts/taiwan/launcher/scheduledReloadHideCheck.lua` - Taiwan TEL reload/hide status monitoring
- `src/scripts/us/collectSIGINT.lua` - US SIGINT collection operations
- `src/scripts/scheduledRunwayRepairment.lua` - Automated runway damage repair scheduling

**Scen Loaded Event**:
All core systems (`src/core/`), modules (`src/modules/`), and utilities (`src/utils/`) are initialized when the scenario loads. The main entry point `src/core/init.lua` orchestrates the initialization of all game systems, configuration loading, and module setup at scenario start.

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
- Run tests before deployment: `busted` from test directory