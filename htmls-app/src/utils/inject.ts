/**
 * Readers for the `window.__INJECT_*__` placeholders.
 *
 * `unitStatusUI.lua` fills those placeholders with runtime JSON via
 * `string.format` before CMO loads the page. During frontend development they
 * keep the `[]` / `{}` defaults from each page's `index.html`, so every reader
 * falls back to the mock data in `src/data/`.
 */

/** Placeholder values that mean "Lua injected nothing", not real data. */
const EMPTY_PAYLOADS = new Set(['', '[]', '{}']);

/**
 * Parse an injected JSON payload, falling back to mock data when the
 * placeholder is unfilled or the payload is malformed.
 */
export function parseInjectedJSON<T>(raw: string | undefined, fallback: T, label?: string): T {
  if (!raw) return fallback;

  const trimmed = raw.trim();
  if (EMPTY_PAYLOADS.has(trimmed)) return fallback;

  try {
    return JSON.parse(trimmed) as T;
  } catch (error) {
    console.error(`[${label ?? 'INJECT'}] JSON parse failed, using fallback:`, error);
    return fallback;
  }
}

/** Read an injected plain string payload (no JSON envelope). */
export function readInjectedString(raw: string | undefined, fallback: string): string {
  const trimmed = raw?.trim();
  return trimmed ? trimmed : fallback;
}
