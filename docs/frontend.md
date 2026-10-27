# CLAUDE-FRONTEND.md

Guidance for working with the React UI layer of the Command: Modern Operations scenario. This is the single source of truth for frontend conventions; the root `CLAUDE.md` only points here.

## htmls-app (React UI)

The `htmls-app/` directory contains React-based UI panels for CMO's embedded browser. Build output goes to `src/htmls/*.html`; deployment injection is handled by `bin/build.sh` from the project root.

### Tech Stack
React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet/react-leaflet. Uses `vite-plugin-singlefile` to bundle into single HTML files. ESLint 9 + Prettier for code quality.

### Project Structure
- `types/` — type definitions only (values live in `constants/`)
- `pages/` — each page has its own `main.tsx` entry point. Logic that only serves that page's screens (view models, mode reducers, payload reads) sits in the page folder, next to its `components/` and `hooks/`
- `components/` — shared React components
- `utils/` — utility functions that make no assumption about a page (e.g., `geo.ts` owns all coordinate helpers). If it would only make sense on one page's screen, it belongs in that page folder
- `hooks/` (inside a page) — React hooks only (`useX.ts`); pure reducers and selectors go next to them, not inside
- `logic/` (inside a page) — pure view models, mode reducers, and payload reads for that page, with their tests. No React
- `constants/` — runtime constants and CONFIG objects
- `data/` — mock data for development
- `index.css` — Tailwind @theme custom colors

### Code Style
- Function components + React Hooks only (no class components, no external state libraries)
- Styling: Tailwind utility classes only; custom colors in `index.css` `@theme`
- Path aliases: `@/`, `@components/`, `@pages/`, `@utils/`, `@types/`
- Utility functions: Pure functions with named exports
- Naming: see [Naming](#naming) section

### Data Flow
HTML pages use `window.__INJECT_*__` placeholders filled by `unitStatusUI.lua` with runtime JSON. During development, mock data in `src/data/` provides fallbacks.

**Important**: Lua field names on injected payload types (`Airbase`, `Jammer`, `OODADetection`, etc.) are immutable. If a better name is needed, wrap at the type layer.

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
Vitest + Testing Library (`happy-dom` environment).
- Test files live next to their subject: `src/utils/geo.test.ts`, `src/pages/control-panel/hooks/useDeploymentState.test.ts`
- Randomness: Use `createSeededRandom(seed)` from `@/utils/random` so tests are reproducible
- What to test: pure utilities, geometry invariants, hook state machines
- What not to test: Leaflet rendering, mock data, presentational-only components

## Naming

Scope: `htmls-app/src/**`. One concept, one name.

### Files

| Kind | Rule | Example |
|---|---|---|
| React component | `PascalCase.tsx` | `DeploymentMap.tsx` |
| Hook | `useX.ts` | `useDeploymentState.ts` |
| utils / types / data / constants | `camelCase.ts` | `geo.ts`, `deploymentGeometry/` (a folder with an `index.ts` for a multi-file module) |
| Page directory | `kebab-case/` | `pages/control-panel/` |
| Test | `*.test.ts` next to its subject | `utils/geo.test.ts` |

`types/` holds types only; runtime values live in `constants/` (e.g. `CONFIG` in `constants/controlPanel.ts`).

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
| `build` | deterministic assembly | `buildMovementPaths`, `buildBatteryGroups` |
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
