import { describe, it, expect } from 'vitest';
import { createSeededRandom } from '@/utils/random';

describe('createSeededRandom', () => {
  it('yields the same sequence for the same seed', () => {
    const a = createSeededRandom(1234);
    const b = createSeededRandom(1234);
    const seqA = Array.from({ length: 20 }, () => a());
    const seqB = Array.from({ length: 20 }, () => b());
    expect(seqA).toEqual(seqB);
  });

  it('yields different sequences for different seeds', () => {
    const a = createSeededRandom(1);
    const b = createSeededRandom(2);
    expect(Array.from({ length: 10 }, () => a())).not.toEqual(
      Array.from({ length: 10 }, () => b())
    );
  });

  it('stays inside [0, 1)', () => {
    const rng = createSeededRandom(0xc0ffee);
    for (let i = 0; i < 5000; i++) {
      const value = rng();
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });

  it('does not immediately repeat itself', () => {
    const rng = createSeededRandom(7);
    const values = new Set(Array.from({ length: 500 }, () => rng()));
    expect(values.size).toBeGreaterThan(490);
  });
});
