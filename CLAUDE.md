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

**Faction Scripts** (`src/scripts/`): Event handlers organized by faction (china/, taiwan/, us/).

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