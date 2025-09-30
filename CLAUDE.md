# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

**Error Handling Strategy**: Use `Utils.safeCall()` wrapper for all critical operations. Log errors with context using the bilingual `Logger` module which automatically detects game vs. development environment.

**Configuration Management**: 
- All platform DBIDs, base GUIDs, and operational parameters are constants in `src/core/constants.lua`
- Use structured namespacing: `config.c.*` (China), `config.t.*` (Taiwan), `config.u.*` (US), `config.s.*` (shared)
- Never hardcode military platform IDs or coordinates

### Module Organization

**Core Systems** (`src/core/`):
- `init.lua` - Main entry point and system orchestration
- `constants.lua` - Centralized configuration (platform DBIDs, base GUIDs, operational areas)
- `schema.lua` - Type definitions with LuaLS annotations
- `saveData.lua` - Persistent state management

**Utilities** (`src/utils/`):
- `gameApi.lua` - **Critical**: CMO API wrapper with error handling - use for all API calls
- `gameUtils.lua` - Higher-level game operations (positioning, missions, formations)
- `logger.lua` - Bilingual logging system (auto-detects game/dev environment)

**Feature Modules** (`src/modules/`):
- `unitGenerator.lua` - Unit creation with formation logic and cleanup
- `assignMission.lua` - Mission assignment and management
- `attackManager.lua` - Combat coordination

**Specialized Subsystems**:
- `src/modules/strikePlanner/` - Air Tasking Orders (ATO), fire support, reconnaissance
- `src/modules/strikePlanner/dynamicFireSupportPlan.lua` - **Dynamic Fire Support Planning** with BDA-based automated FSEM creation
- `src/modules/EW/` - Electronic warfare (GPS jamming, SIGINT, comms jamming)  
- `src/modules/landingOPs/` - Amphibious assault coordination and logistics

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
- `src/scripts/china/launcher/ammoHoldingArea.lua` - China TEL ammunition holding area management
- `src/scripts/china/launcher/firingPosition.lua` - China TEL firing position handling
- `src/scripts/china/launcher/hideArea.lua` - China TEL hide area management
- `src/scripts/china/launcher/reloadPoint.lua` - China TEL reload point operations
- `src/scripts/china/recon/H6NLaunchWZ8.lua` - H-6N launch WZ-8 reconnaissance drone operations
- `src/scripts/china/CSGEnterArea.lua` - China Carrier Strike Group area entry handling
- `src/scripts/taiwan/launcher/ammoHoldingArea.lua` - Taiwan TEL ammunition holding area management
- `src/scripts/taiwan/launcher/hideArea.lua` - Taiwan TEL hide area management
- `src/scripts/taiwan/launcher/reloadPoint.lua` - Taiwan TEL reload point operations
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

### Unit and Formation Management
- Always use formation constants (`FORMATION.ANGLES`, `FORMATION.DISTANCES`) for consistent positioning
- Implement cleanup functions before creating new units to prevent duplicates
- Use retry logic for unit creation operations due to CMO API timing constraints

### Military Simulation Concepts
The codebase implements sophisticated military concepts:
- **Air Tasking Orders (ATO)** with timing synchronization
- **Strike Package coordination** with escort and SEAD missions
- **Formation flying** with geometric positioning algorithms
- **Amphibious Operations** with multi-wave landing coordination
- **Electronic Warfare** including GPS and communications jamming

### API Usage Patterns
- Wrap all `ScenEdit_*` calls in `GameAPI.*` equivalents
- Validate API responses before proceeding with operations
- Use descriptive unit names following military conventions
- Implement fallback behaviors for API failures

### Configuration Changes
- Modify `src/core/constants.lua` for all platform DBIDs, coordinates, and operational parameters
- **Dynamic Fire Support Plan**: Configure `config.c.ground.dynamicFSP` for recon schedules and FSEM templates
- Test configuration changes in development mode before deployment
- Use structured validation for configuration parameters

### Testing Approach
- Unit tests located in `test/modules/` using Busted framework
- Mock game APIs comprehensively for isolated testing
- Test critical modules like `assignMission.lua` and `unitGenerator.lua`
- Run tests before deployment: `busted` from test directory

The project demonstrates professional-grade Lua programming applied to complex military simulation, combining modern software practices with deep domain expertise in modern warfare concepts. 

## New Features

### Dynamic Fire Support Plan (2024)
A sophisticated BDA-based automated fire support system that:
- Monitors reconnaissance schedules and automatically triggers target evaluation
- Supports both fixed targets (airfields, ports) and dynamic targets (radars, SAMs)
- Creates Fire Support Execution Matrices (FSEM) based on real-time intelligence
- Integrates seamlessly with existing fire support planning systems
- Uses weapon system allocation with conflict avoidance
- Configured via `config.c.ground.dynamicFSP` in constants.lua
- See `docs/DynamicFireSupportPlan.md` for detailed documentation