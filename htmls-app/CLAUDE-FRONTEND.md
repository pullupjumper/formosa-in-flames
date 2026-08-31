# CLAUDE-FRONTEND.md

Guidance for working with the React UI layer of the Command: Modern Operations scenario.

## htmls-app (React UI)

The `htmls-app/` directory contains React-based UI panels for CMO's embedded browser. Build output goes to `src/htmls/*.html`; deployment injection is handled by `bin/build.sh` from the project root.

### Tech Stack
React 19 + TypeScript 5.9 + Vite 7 + Tailwind CSS 4 + Leaflet/react-leaflet. Uses `vite-plugin-singlefile` to bundle into single HTML files. ESLint 9 + Prettier for code quality.

### Project Structure
```
htmls-app/src/
├── components/     # Shared components
├── pages/          # Each page has its own main.tsx entry point
├── types/          # TypeScript type definitions
├── utils/          # Utility functions
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

### Data Flow
HTML pages use `window.__INJECT_*__` placeholders. `unitStatusUI.lua` fills them with runtime JSON via `string.format`; during frontend development they fall back to mock data from `src/data/`.

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

- Test files live next to their subject: `src/utils/map.test.ts`, `src/pages/setup-menu/hooks/useDeploymentState.test.ts`
- Global setup lives in `src/test/setup.ts` (jest-dom matchers + auto cleanup)
- Randomness: geometry generators take a `RandomSource` that defaults to `Math.random`. Tests pass `createSeededRandom(seed)` from `@/utils/random` so generated layouts are reproducible
- What to test: pure utilities (`utils/`), geometry invariants (squares do not overlap, vertices stay inside the boundary), and hook state machines via `renderHook`
- What not to test: Leaflet marker rendering, `src/data/` mock data, presentational-only components

```bash
npx vitest run src/utils/map.test.ts   # Single file
```

### Full Deployment Build
From project root:
```bash
bash bin/build.sh      # Builds htmls-app → src/htmls/*.html → slim/main.lua
bash bin/build.sh -t   # Same, but runs busted (Lua) and vitest (frontend) first
```
