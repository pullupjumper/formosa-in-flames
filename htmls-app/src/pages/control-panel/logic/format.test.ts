import { describe, it, expect } from 'vitest';
import { formatTimestamp, calculateProgress } from '@/pages/control-panel/logic/format';

describe('formatTimestamp', () => {
  it('formats a Unix timestamp in UTC', () => {
    expect(formatTimestamp(1_700_000_000)).toBe('2023-11-14 22:13:20');
  });

  it('accepts a numeric string', () => {
    expect(formatTimestamp('1700000000')).toBe('2023-11-14 22:13:20');
  });

  it.each([undefined, 0, ''])('returns N/A for the empty input %o', (input) => {
    expect(formatTimestamp(input as number | string | undefined)).toBe('N/A');
  });

  it('echoes an unparsable string back', () => {
    expect(formatTimestamp('not-a-time')).toBe('not-a-time');
  });
});

describe('calculateProgress', () => {
  it('rounds to whole percent', () => {
    expect(calculateProgress(1, 3)).toBe(33);
    expect(calculateProgress(2, 3)).toBe(67);
  });

  it('returns 0 for a non-positive total', () => {
    expect(calculateProgress(5, 0)).toBe(0);
    expect(calculateProgress(5, -1)).toBe(0);
  });

  it('does not clamp above 100', () => {
    expect(calculateProgress(3, 2)).toBe(150);
  });
});
