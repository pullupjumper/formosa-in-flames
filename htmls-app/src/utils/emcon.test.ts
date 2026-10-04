import { describe, it, expect } from 'vitest';
import { toEmconResult, type SamDoctrineEntry } from './emcon';

describe('toEmconResult', () => {
  it('carries each unit identity and weapons status through', () => {
    const sams: SamDoctrineEntry[] = [
      { guid: 'g1', name: 'SAM Bn A', weaponFree: false },
      { guid: 'g2', name: 'SAM Bn B', weaponFree: true },
    ];

    expect(toEmconResult(sams)).toEqual({ sams });
  });

  it('is empty when there are no SAM units', () => {
    expect(toEmconResult([])).toEqual({ sams: [] });
  });
});
