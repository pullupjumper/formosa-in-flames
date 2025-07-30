# Technology Stack

## Language & Runtime
- **Primary Language**: Lua
- **Target Platform**: Command: Modern Operations (CMO) wargaming simulation
- **Architecture**: Modular Lua modules with centralized configuration

## Project Structure
- Uses `require()` for module loading
- Centralized configuration in `src/core/constants.lua`
- Persistent state management via `saveData` system
- Game API abstraction layer in `src/utils/gameApi.lua`

## Key Libraries & Frameworks
- **Game Integration**: Command: Modern Operations Lua API
- **State Management**: Custom persistence system with `gKH.State`
- **Logging**: Custom logger with in-game and development modes
- **Utilities**: Custom game utilities and helper functions

## Development Patterns
- **Error Handling**: Proxy pattern for API calls with centralized error catching
- **Configuration**: Hierarchical config structure with nested tables
- **Data Models**: Lua tables with type annotations using LuaLS format
- **Modularity**: Clear separation between core, modules, scripts, and utilities

## Common Commands
Since this is a Lua project for CMO simulation:
- **Testing**: Load scripts directly in CMO scenario editor
- **Debugging**: Use Logger module for in-game debugging
- **Development**: Edit .lua files and reload in CMO
- **Deployment**: Copy to CMO scenario or use as standalone scripts

## Code Style
- Use `---@class` and `---@type` annotations for type safety
- CamelCase for classes, snake_case for variables
- Prefix custom types with `SBJ__` (project identifier)
- Extensive use of nested table structures for configuration
- Error handling through GameApi proxy layer