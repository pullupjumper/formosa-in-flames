import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { resolve } from 'path';

// Get the page to build from environment variable
const page = process.env.BUILD_PAGE;

// Page configurations: root directory for each page
const pageConfigs: Record<string, string> = {
  'setup-menu': resolve(__dirname, 'src/pages/setup-menu'),
  'emcon-setting': resolve(__dirname, 'src/pages/emcon-setting'),
  'unit-status': resolve(__dirname, 'src/pages/unit-status'),
};

const pageRoot = page ? pageConfigs[page] : __dirname;

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), viteSingleFile()],
  base: './',
  root: pageRoot,
  // Emit ASCII-only JS: non-ASCII glyphs (°, ✓, —) become \uXXXX escapes.
  // CMO injects these files as Lua strings into an embedded browser that decodes
  // bytes as the system ANSI code page (CP950), not UTF-8, so any raw non-ASCII
  // byte is mangled. ASCII escapes survive that path; the JS engine restores the
  // real glyph at runtime.
  esbuild: { charset: 'ascii' },
  resolve: {
    alias: {
      '@': resolve(__dirname, './src'),
      '@components': resolve(__dirname, './src/components'),
      '@pages': resolve(__dirname, './src/pages'),
      '@hooks': resolve(__dirname, './src/hooks'),
      '@utils': resolve(__dirname, './src/utils'),
      '@types': resolve(__dirname, './src/types'),
    },
  },
  build: {
    outDir: resolve(__dirname, '../src/htmls'),
    emptyOutDir: false,
  },
});
