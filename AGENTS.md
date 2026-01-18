# Agent Development Guidelines

## Build & Test Commands

### Testing
```bash
# Run all tests (from test directory)
busted

# Run specific test file
busted test/modules/targetingProcess_scanTargets_spec.lua

# Run with verbose output
busted --verbose
```

### Build & Deployment
```bash
# Process Lua modules for deployment (removes requires, cleans modules)
python tools/build_lua_scenario.py

# Windows: Set UTF-8 encoding for emoji characters
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py

# Clean only (src -> slim)
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py --clean-only

# Merge only (slim -> main.lua)
PYTHONIOENCODING=utf-8 python tools/build_lua_scenario.py --merge-only
```

## Code Style Guidelines

### Imports
- Use `local X = require("src.path.to.module")` for all imports
- No circular imports allowed
- Import dependencies at file top before module definition

### Naming Conventions
- **Modules**: PascalCase (e.g., `AssignMission`, `GameApi`, `Utils`)
- **Functions**: camelCase (e.g., `filterEmbarkedPlatforms`, `assignEmbarkedUnitsToMissions`)
- **Local functions**: camelCase, prefixed with `local` keyword
- **Variables**: camelCase (e.g., `baseUnit`, `filteredPlatforms`, `weaponCount`)
- **Constants**: UPPER_SNAKE_CASE (in config.lua)
- **Type prefixes**:
  - `CMO__*` for CMO game API types
  - `SBJ__*` for project-specific types

### Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line length**: 120 characters max
- **Spacing**: Single blank line between functions
- **Trailing whitespace**: None
- **Empty lines**: No more than one consecutive empty line

### Type Annotations (LuaLS)
**Function Documentation** (maximum 2 lines):
```lua
---Filter embarked platforms by type and database ID
---Returns filtered list of platforms matching criteria
---@param baseUnit CMO__Unit The base unit with embarked units
---@param platformType string The type of platform to filter
---@param platformDBID number The database ID of the platform
---@return CMO__Unit[] # A list of filtered embarked units
```

**Key Rules**:
- Function descriptions: Maximum 2 lines, start with uppercase, use `---Description`
- Single return: Use `#` separator → `---@return type # Description`
- Multiple returns: Include variable names → `---@return type varName Description`
- Parameters: No `--` separator, direct description after type
- Variable names: Use semantic names (`success`, `count`, `error`) not generic (`result1`, `result2`)
- Reserved words: Avoid Lua keywords as variable names (use `num` not `number`)

### Error Handling
- **Never call raw CMO APIs** - always use `GameApi.*` wrappers (src/utils/gameApi.lua)
- All GameApi calls are automatically wrapped with error handling via metatable
- Use `Utils.safeCall(funcName, func, ...)` for custom error handling
- Functions return `nil` on failure with error logged through bilingual Logger
- Validate API responses before proceeding with operations

### Code Organization
- **Core modules** (`src/core/`): init.lua, config.lua, constants.lua, schema.lua, saveData.lua
- **Utilities** (`src/utils/`): gameApi.lua, gameUtils.lua, utils.lua, logger.lua
- **Feature modules** (`src/modules/`): Organized by feature (strikePlanner/, EW/, landingOps/, etc.)
- **Event scripts** (`src/scripts/`): Organized by faction and event type (china/, taiwan/, us/)

### Configuration Management
- **Runtime config** (`src/core/config.lua`): Operational parameters, timing, tactical settings
  - Uses prominent section headers: `-- ============================================================================`
  - Structured namespacing: `config.c.*`, `config.t.*`, `config.u.*`, `config.s.*`
- **Constants** (`src/core/constants.lua`): DBIDs, GUIDs, weapon IDs, area definitions
- **Never hardcode** DBIDs, GUIDs, or coordinates in logic - reference from config/constants

### Testing
- Framework: Busted
- Test location: `test/modules/`
- Naming: `[moduleName]_spec.lua` (e.g., `targetingProcess_scanTargets_spec.lua`)
- Use `before_each` for setup, `after_each` for cleanup
- Mock dependencies comprehensively for isolated testing
- Use `describe()` and `it()` for test organization

### Event System
Events trigger scripts in `src/scripts/`:
- **Unit Remains in Area** (5-min intervals): Amphibious ops, launcher monitoring
- **Unit Enters Area**: CSG entry, TEL positioning, zone neutralization
- **Unit Destroyed**: Scoring, asset tracking
- **Unit Damaged**: Runway damage detection
- **Unit Base Status**: Aircraft landing operations
- **Regular Time**: 1-min (high-freq), 5-min (periodic) tasks
- **Scen Loaded**: System initialization

### Comments Policy
- Add function documentation annotations for all public functions
- **NO inline code comments** unless explicitly requested
- Keep code self-documenting through clear naming and structure

### Development Mode
Set `config.isDevMode = true` in `src/core/config.lua` for console logging

### Important Notes
- Windows Traditional Chinese systems: Set `PYTHONIOENCODING=utf-8` before Python commands
- Build process removes `require()` statements for deployment
- Always follow existing patterns when adding new features
- Type check with LuaLS during development
