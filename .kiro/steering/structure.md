# Project Structure

## Directory Organization

```
src/
├── core/           # Core system components
│   ├── constants.lua    # Central configuration and constants
│   ├── saveData.lua     # Persistent game state data
│   ├── init.lua         # System initialization
│   └── schema.lua       # Data structure definitions
├── modules/        # Feature modules
│   ├── strikePlanner/   # Fire support planning system
│   ├── landingOps/      # Amphibious operations
│   ├── EW/              # Electronic warfare
│   └── *.lua            # Individual module files
├── scripts/        # Scenario-specific scripts
│   ├── china/           # PLA-specific scripts
│   ├── taiwan/          # ROC-specific scripts
│   └── us/              # US forces scripts
└── utils/          # Utility functions
    ├── gameApi.lua      # Game API abstraction
    ├── logger.lua       # Logging system
    └── utils.lua        # General utilities
```

## Key Architectural Patterns

### Configuration Management
- All constants in `src/core/constants.lua`
- Hierarchical structure: `config.c.ground.mlrs.positions`
- Weapon systems, unit IDs, and tactical parameters centralized

### State Management  
- Persistent state in `src/core/saveData.lua`
- Mirrors config structure: `saveData.c.ground.mlrs.batteries`
- Automatic persistence through `gKH.State` system

### Module Organization
- **Core**: System initialization and data structures
- **Modules**: Self-contained feature implementations
- **Scripts**: Scenario-specific event handlers and triggers
- **Utils**: Shared utilities and API wrappers

### Naming Conventions
- **Files**: camelCase for modules, lowercase for utilities
- **Classes**: `SBJ__ClassName` with project prefix
- **Variables**: snake_case for data, camelCase for functions
- **Constants**: UPPER_CASE in config tables

## Development Guidelines
- Keep modules focused on single responsibilities
- Use the GameApi wrapper for all game interactions
- Centralize configuration in constants.lua
- Follow the established saveData structure patterns
- Use Logger for debugging instead of print statements
- Maintain separation between China/Taiwan/US specific code