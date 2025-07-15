# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Lua scripting project for Command: Modern Operations (CMO), a military simulation game. The project simulates war scenarios with custom AI logic for enemy forces and complex military operations including air tasking orders, fire support plans, amphibious operations, and electronic warfare.

## Development Commands

### Testing
```bash
# Run unit tests using Busted framework
busted test/
```

### Code Processing
```bash
# Clean and process Lua scripts (removes require statements and module exports)
python tools/clean_lua_scripts.py
```

## Architecture

### Directory Structure
- **src/** - Main source code (development version with modules)
- **slim/** - Processed code (deployment version without require statements)
- **test/** - Unit tests using Busted framework
- **tools/** - Build and processing utilities
- **references/** - Reference materials and prototypes

### Core Components

#### Core System (`src/core/`)
- **init.lua** - Main initialization script that sets up all game systems
- **constants.lua** - Configuration and platform database IDs for different military units
- **saveData.lua** - Persistent data schema for game state
- **schema.lua** - Data structure definitions
- **gKH_*.lua** - External game state management libraries

#### Modules (`src/modules/`)
- **assignMission.lua** - Unit mission assignment logic
- **attackManager.lua** - Combat engagement coordination
- **unitGenerator.lua** - Dynamic unit creation and placement
- **strikePlanner/** - Air operation planning and execution
- **landingOps/** - Amphibious assault operations
- **EW/** - Electronic warfare (GPS jamming, SIGINT, communications jamming)

#### Scripts (`src/scripts/`)
Event-driven scripts organized by faction:
- **china/** - Chinese forces AI and operations
- **taiwan/** - Taiwanese forces AI and operations  
- **us/** - US forces operations
- **score/** - Victory condition and scoring logic

#### Utilities (`src/utils/`)
- **gameApi.lua** - Command Lua API wrappers
- **gameUtils.lua** - Game-specific utility functions
- **utils.lua** - General utility functions
- **logger.lua** - Logging system

### Key Patterns

#### Module Architecture
- Modules use local tables with function definitions
- Functions are defined as `ModuleName.functionName = function()`
- Modules return table with public interface
- The build process removes require statements for deployment

#### Game Integration
- Uses Command Lua API through gameApi.lua wrappers
- Event-driven architecture with scheduled operations
- Persistent state management through gKH libraries
- Unit identification via database IDs (dbid) from constants.lua

#### Error Handling
- SafeCall pattern for error handling with Utils.SafeCall()
- Comprehensive logging through Logger module
- Defensive programming for missing units/contacts

#### Testing
- Unit tests with Busted framework in test/ directory
- Mock game API for isolated testing
- Test coverage for core modules like assignMission

## Important Development Notes

- The slim/ directory contains processed code without require statements for game deployment
- Platform DBIDs in constants.lua map to specific military unit types in the game
- The game state is persisted using gKH.State.SaveTableToKey/LoadTableFromKey
- Event scripts are triggered by game events and execute specific tactical operations
## AI Assistant Guidelines

You are a professional programmer proficient in various programming languages and frameworks. Please respond in Traditional Chinese, avoiding Simplified Chinese and China-specific terminology. Maintain professionalism with precise terminology suitable for Taiwan developers.
