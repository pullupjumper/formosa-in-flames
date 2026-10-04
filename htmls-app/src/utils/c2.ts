import type { C2Data, C2Node } from '@/types/unitStatus';

/**
 * Flatten injected C2 data into `guid -> node`. Accepts both direct nodes
 * `{ ROCC: {...}, TAAOC: {...} }` and the Lua payload's wrapped groups
 * `{ rocc: { guid1: {...}, guid2: {...} } }`.
 */
export function flattenC2Nodes(data: C2Data | undefined): Record<string, C2Node> {
  const flatNodes: Record<string, C2Node> = {};

  for (const [key, value] of Object.entries(data || {})) {
    if (value && typeof value === 'object' && 'name' in value) {
      flatNodes[key] = value as C2Node;
    } else if (value && typeof value === 'object') {
      for (const [subKey, subValue] of Object.entries(value as Record<string, C2Node>)) {
        flatNodes[subKey] = subValue;
      }
    }
  }

  return flatNodes;
}
