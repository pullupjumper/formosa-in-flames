import { describe, it, expect } from 'vitest';
import { formatTimestamp, formatCoordinates, calculateProgress, isDataEmpty } from '@/utils/format';

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

describe('formatCoordinates', () => {
  it('labels the northern/eastern hemisphere', () => {
    expect(formatCoordinates(23.5, 121.25)).toEqual({
      lat: '23.5000° N',
      lng: '121.2500° E',
    });
  });

  it('labels the southern/western hemisphere with absolute values', () => {
    expect(formatCoordinates(-23.5, -121.25)).toEqual({
      lat: '23.5000° S',
      lng: '121.2500° W',
    });
  });

  it('treats undefined as zero', () => {
    expect(formatCoordinates(undefined, undefined)).toEqual({
      lat: '0.0000° N',
      lng: '0.0000° E',
    });
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

describe('isDataEmpty', () => {
  it.each([undefined, null, 0, '', [], {}])('treats %o as empty', (value) => {
    expect(isDataEmpty(value)).toBe(true);
  });

  it.each([[[1]], [{ a: 1 }]])('treats %o as non-empty', (value) => {
    expect(isDataEmpty(value)).toBe(false);
  });

  it('treats a non-empty primitive as empty (no container to inspect)', () => {
    expect(isDataEmpty('text')).toBe(true);
    expect(isDataEmpty(42)).toBe(true);
  });
});
