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
```

### Full Deployment Build
From project root:
```bash
bash bin/build.sh    # Builds htmls-app → src/htmls/*.html → slim/main.lua
```
