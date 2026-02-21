---
name: generate-module-docs
description: Analyze Lua modules in a specified directory and generate system architecture documentation (README.md + per-module docs) under docs/, following the strikePlanner documentation style with Mermaid diagrams, tables, and ASCII data structure trees.
---

# Generate Module Documentation

Analyze all Lua modules in the specified directory and generate a complete documentation set under `docs/`.

## Input

`$ARGUMENTS` is the relative path to the module directory to analyze (e.g., `src/modules/ew`).

The directory name will be used as the documentation subdirectory name under `docs/` (e.g., `docs/ew/`).

## Analysis Steps

For each `.lua` file in the target directory, perform a thorough analysis:

1. **Dependencies**: All `require()` imports and their roles
2. **Constants & Enumerations**: Local enum tables, constant values, their naming prefixes
3. **Configuration Usage**: Which `config.*` and `constants.*` values are referenced, with their paths and purposes
4. **Internal Helper Functions**: Each local function's signature, parameters, return values, and single-line responsibility description
5. **Architectural Patterns**: Design patterns used (Strategy, State Machine, Event-Driven, Descriptor, Factory, etc.)
6. **Public API**: All functions exported via the module table, their signatures, callers, and trigger mechanisms
7. **Data Flow**: How data enters the module, transforms, and flows to other systems
8. **State Management**: What `saveData` fields are read/written, what game API side effects occur

## Documentation Style Reference

Follow the exact formatting conventions used in `docs/strikePlanner/`. Read `docs/strikePlanner/README.md` and at least one module doc (e.g., `docs/strikePlanner/targetingProcess.md` or `docs/strikePlanner/fireSupportPlan.md`) to match:

- Section separator: `---` between major sections
- Mermaid diagrams: `flowchart`, `stateDiagram-v2`, `sequenceDiagram` as appropriate
- Tables with `|---|` alignment
- ASCII tree for data structures using `├──`, `└──`, `│` characters
- Blockquote for source path: `> source code path`
- Bold one-line responsibility summary

## Output Files

### README.md (System Architecture Overview)

Generate `docs/<dirname>/README.md` containing:

1. **Title**: `# <SystemName> System Architecture` (in Traditional Chinese)
2. **Overview paragraph**: What the system does, its subsystems, and a bullet list of capabilities
3. **Capability mapping table**: Map each module to its role (like the F2T2EA Kill Chain table in strikePlanner)
4. **Module summary table**: Module name (linked), source file, one-line responsibility
5. **System architecture diagram** (Mermaid flowchart): Show trigger mechanisms, module interactions, and target systems
6. **Integration diagram** (Mermaid flowchart): Show how this system connects to upstream/downstream systems
7. **Core data structures** (ASCII tree): All relevant `saveData` structures with field types
8. **Module dependency graph** (Mermaid flowchart BT): Show dependencies on utility/core modules
9. **Config reference table**: All `config.lua` settings used, with paths and purposes
10. **Constants reference table**: All `constants.lua` values used, with paths and purposes
11. **Related files table**: Event scripts, upstream/downstream modules, core files

### Per-Module Documentation

For each `.lua` file, generate `docs/<dirname>/<moduleName>.md` containing:

1. **Title**: `# <moduleName> --- <Chinese description>`
2. **Source path** (blockquote): `> source code: \`path/to/file.lua\``
3. **Responsibility** (bold): One-line summary
4. **Overview**: 2-3 paragraph description covering purpose, trigger mechanism, and core design
5. **Key mechanism sections**: Each major functional area with:
   - Explanation text
   - Mermaid diagram (flowchart for processes, stateDiagram for state machines)
   - Tables for configuration/parameter details
6. **Execution flow** (Mermaid flowchart): Main entry point through all processing steps
7. **Public API table**: Function name, description
8. **Related modules**: Links to sibling modules and upstream/downstream dependencies

## Language

All documentation content must be written in **Traditional Chinese** (Taiwan terminology). Technical terms (function names, variable names, file paths) remain in English.

## Quality Checks

Before finalizing, verify:
- All Mermaid diagrams use valid syntax
- All internal links between docs use correct relative paths
- All public API functions from source code are documented
- ASCII trees match actual `saveData` structure
- Config/constants references match actual values in `config.lua` and `constants.lua`
