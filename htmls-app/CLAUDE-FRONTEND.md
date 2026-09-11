# CLAUDE-FRONTEND.md

Guidance for working with the React UI layer of the Command: Modern Operations scenario. This is the single source of truth for frontend conventions; the root `CLAUDE.md` only points here.

## htmls-app (React UI)

The `htmls-app/` directory contains React-based UI panels for CMO's embedded browser. Build output goes to `src/htmls/*.html`; deployment injection is handled by `bin/build.sh` from the project root.

### Tech Stack
React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet/react-leaflet. Uses `vite-plugin-singlefile` to bundle into single HTML files. ESLint 9 + Prettier for code quality.

### Project Structure
```
htmls-app/src/
├── components/     # Shared components
├── pages/          # Each page has its own main.tsx entry point
├── types/          # TypeScript type definitions (types only; geo.ts owns Coordinate)
├── constants/      # Runtime constants (CONFIG, Taiwan boundary)
├── utils/          # Utility functions (geo.ts owns every coordinate helper)
├── data/           # Static mock data for development
├── test/           # Vitest global setup
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
- Naming: see the [Naming](#naming) section below

### Data Flow
HTML pages use `window.__INJECT_*__` placeholders. `unitStatusUI.lua` fills them with runtime JSON via `string.format`; during frontend development they fall back to mock data from `src/data/`.

Field names on injected payload types (`Airbase`, `Jammer`, `OperationalArea`, `wpnCurrent`, `OODADetection`, ...) are dictated by the Lua side and must not be renamed; wrap them at the type layer if a better name is needed.

### Build Commands
```bash
# From htmls-app/ directory
npm run dev          # Development server
npm run build        # Rebuild src/htmls only; full deployment uses bin/build.sh from project root
npm run lint         # Run ESLint
npm run format       # Format with Prettier
npm test             # Run Vitest once (CI mode)
npm run test:watch   # Run Vitest in watch mode
```

### Testing
Vitest + Testing Library (`happy-dom` environment). `vitest.config.ts` is separate from `vite.config.ts` because the deployment build swaps `root` per page and adds Tailwind/singlefile; only the path aliases are shared.

- Test files live next to their subject: `src/utils/geo.test.ts`, `src/pages/setup-menu/hooks/useDeploymentState.test.ts`
- Global setup lives in `src/test/setup.ts` (jest-dom matchers + auto cleanup)
- Randomness: geometry generators take a `RandomSource` that defaults to `Math.random`. Tests pass `createSeededRandom(seed)` from `@/utils/random` so generated layouts are reproducible
- What to test: pure utilities (`utils/`), geometry invariants (squares do not overlap, vertices stay inside the boundary), and hook state machines via `renderHook`
- What not to test: Leaflet marker rendering, `src/data/` mock data, presentational-only components

```bash
npx vitest run src/utils/geo.test.ts   # Single file
```

### Full Deployment Build
From project root:
```bash
bash bin/build.sh      # Builds htmls-app → src/htmls/*.html → slim/main.lua
bash bin/build.sh -t   # Same, but runs busted (Lua) and vitest (frontend) first
```

## Naming

Scope: `htmls-app/src/**`. One concept, one name.

### Files

| Kind | Rule | Example |
|---|---|---|
| React component | `PascalCase.tsx` | `DeploymentMap.tsx` |
| Hook | `useX.ts` | `useDeploymentState.ts` |
| utils / types / data / constants | `camelCase.ts` | `missileDeployment.ts`, `geo.ts` |
| Page directory | `kebab-case/` | `pages/setup-menu/` |
| Test | `*.test.ts` next to its subject | `utils/geo.test.ts` |

`types/` holds types only; runtime values live in `constants/` (e.g. `CONFIG` in `constants/setupMenu.ts`).

### Types

- PascalCase, no `I` prefix.
- Suffixes carry fixed meaning:
  - `Props` — component props (`{ComponentName}Props`)
  - `Params` — object argument of a function or hook (`Use{Hook}Params`, `GenerateDeploymentParams`)
  - `Result` — object returned by a function (`GenerateResult`, `RelocateResult`)
  - `Config` — static option object (`AreaConfig`, `GatewayConfig`)
  - `State` — reducer / `useState` shape (`BudgetState`, `DeploymentModeState`)
  - `Data` — **only** the root type of a Lua-injected payload (`SetupMenuData`, `UnitStatusData`)
- Domain objects are bare nouns: `Airbase`, `Jammer`, `MissileDeployment`, `Coordinate`.
- String literal unions are lowercase-kebab (`'signal-data'`, `'outside-boundary'`); reducer action `type`s stay camelCase (`'relocateArea'`).

### Coordinates

- One spelling everywhere: `latitude` / `longitude`, typed as `Coordinate` from `types/geo.ts`.
- `lat` / `lng` / `lon` are **forbidden** in identifiers and object fields. Leaflet's `LatLng` is converted only in `utils/geo.ts` (`toLeafletLatLng`, `fromLeafletLatLng`).
- Public functions take a `Coordinate` object, never two scalar parameters.
- Deltas use `CoordinateOffset { latitudeDelta, longitudeDelta }`.

### Function verbs

| Verb | Meaning | Example |
|---|---|---|
| `get` | O(1) lookup | `getWeaponSystemName` |
| `calculate` | geometry / numeric work | `calculateCentroid`, `calculateBearing` |
| `generate` | produce new data, may be random | `generateShelterPoints` |
| `build` | deterministic assembly | `buildMovementPaths`, `buildMissileGroups` |
| `create` | third-party object factory | `createIcon`, `createSeededRandom` |
| `resolve` / `select` | pick one of several candidates | `resolveOpeningAngle`, `selectFpGateway` |
| `parse` / `read` | decode input | `parseInjectedJSON`, `readInjectedString` |
| `format` | to display string | `formatTimestamp`, `formatRelocateFailure` |
| `to` / `from` | type conversion | `toLeafletPositions`, `fromLeafletLatLng` |
| `is` / `has` / `can` / `should` / `does` / `do` | returns boolean | `isPointInTaiwan`, `doSquaresOverlap` |
| `toggle` | flip state | `toggleCategory` |

**Forbidden**: `check`, `calc`, `determine`, `describe` — use the table above.

### Events

- Component props are always `onX` (`onMapClick`, `onAreaClick`).
- Implementations inside components/hooks are always `handleX` (`handleMapClick`); no `Cb` suffix.
- Leaflet `eventHandlers` objects are named `{area}EventHandlers`.

### Variables

- Booleans carry `is` / `has` / `can` / `should`: `isCollapsed`, `isPlacementActive`.
- Arrays are plural nouns, no `List` suffix: `firePointPositions`, not `fpPositionsList`.
- Module-level constants are `SCREAMING_SNAKE`, including icons, palettes and pathOptions: `EW_ICON`, `PATH_OPTIONS_RANGE`.
- React refs end in `Ref`: `modeRef`, `ushapePolygonRef`.

### Abbreviations

Allowed:
- `id` / `guid` / `dbid`
- Unit suffixes `Nm`, `Meters`, `Ms` (`rangeNm`, `radiusMeters`, `MOUSE_MOVE_THROTTLE_MS`)
- Game-domain codes `fp` / `ha` / `rl` / `aha` / `shrl`: camelCase inside identifiers (`fpGateway`, `shrlPathPositions`); JSON keys keep the Lua-side uppercase (`paths.FP`)

Forbidden: `ctr`, `idx`, `cb`, `lo`, `e`, `evt`, `coords`, `pos`. Single-letter names only inside one-line lambdas (`_` for ignored params is fine).

### Parameters

| Concept | Name |
|---|---|
| single position | `point` or `position` |
| area center | `center` |
| polygon vertices | `vertices` |
| path points | `waypoints` |
| polygon used for containment | `polygon` |
| angle in degrees | `angle` / `openingAngle` / `bearing` |
| unit identity | `unitKey` / `unitName` / `category` / `index` |
| event object | `event` |
