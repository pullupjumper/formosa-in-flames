# Repository Guidelines

## Project Structure & Module Organization
`src/` holds core game logic: `src/core` for config/state, `src/modules` for feature packs (strike planner, landing ops), `src/utils` for API helpers, `src/scripts` for scenario entry points. Tests mirror module layout under `test/modules` with `_spec.lua` files. `docs/` contains design notes such as `DynamicFireSupportPlan.md`. Build artifacts live in `slim/` including the packaged `merged_scenario.lua`. Use `references/` and `specs/` for doctrine documents and scenario briefs.

## Build, Test, and Development Commands
Run `python tools/build_lua_scenario.py` from the repo root to clean, merge, and emit `slim/merged_scenario.lua`; add `--include-schema` when schema updates are required. Use `python tools/build_lua_scenario.py --clean` before committing to strip stray whitespace. Execute `busted test/modules` to run the full suite or target a single spec via `busted test/modules/dynamicATOInsertion_spec.lua`.

## Coding Style & Naming Conventions
Lua files use 4 spaces and avoid tabs. Module files use descriptive lowerCamelCase names that match their `require` paths (`src.modules.landingOps.shipMovement`). Keep tables and functions lowerCamelCase, reserve PascalCase for imported module handles, and keep constant tables under `src/core/constants.lua`. Preserve EmmyLua annotations (`---@class`, `---@param`) to keep tooling accurate, and prefer explicit return tables over globals.

## Testing Guidelines
Add a `_spec.lua` alongside new modules and exercise both success paths and failure handling. Arrange tests in Given/When/Then blocks, mirroring the runtime module namespace. Run `busted` before pushing; new features should include assertions that cover scenario side-effects (events created, units spawned) rather than only pure helpers.

## Commit & Pull Request Guidelines
Follow the existing `type: short action` subject style (e.g., `refactor: rebuild GPS jamming control`). Squash noisy fix-ups before opening a PR. Each PR should describe motivation, summarize gameplay impact, list testing commands run, and link the relevant task or issue; attach screenshots or in-sim logs for UI or event-flow changes.
