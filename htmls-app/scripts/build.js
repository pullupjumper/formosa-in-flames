import { execSync } from 'child_process';
import { renameSync, rmSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(__dirname, '../../src/htmls');

const pages = ['setup-menu', 'emcon-setting', 'unit-status'];

// Clean output directory
if (existsSync(outDir)) {
  rmSync(outDir, { recursive: true });
}

// Build each page
for (const page of pages) {
  console.log(`\nBuilding ${page}...`);
  execSync('vite build', {
    stdio: 'inherit',
    cwd: resolve(__dirname, '..'),
    env: { ...process.env, BUILD_PAGE: page },
  });

  // Rename index.html to {page}.html
  const srcFile = resolve(outDir, 'index.html');
  const destFile = resolve(outDir, `${page}.html`);

  if (existsSync(srcFile)) {
    renameSync(srcFile, destFile);
    console.log(`Renamed to ${page}.html`);
  }
}

console.log('\nBuild complete! Output files:');
for (const page of pages) {
  console.log(`  - src/htmls/${page}.html`);
}
