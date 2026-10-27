import { describe, it, expect, vi, afterEach } from 'vitest';
import { parseInjectedJSON, readInjectedBoolean, readInjectedString } from '@/utils/inject';

const FALLBACK = { mock: true };

afterEach(() => {
  vi.restoreAllMocks();
});

describe('parseInjectedJSON', () => {
  it('parses a filled payload', () => {
    expect(parseInjectedJSON('{"a":1}', FALLBACK)).toEqual({ a: 1 });
  });

  it('tolerates surrounding whitespace', () => {
    expect(parseInjectedJSON('  [1, 2]  ', [] as number[])).toEqual([1, 2]);
  });

  it.each([undefined, '', '   ', '[]', '{}', ' [] '])(
    'falls back on the unfilled placeholder %o',
    (raw) => {
      expect(parseInjectedJSON(raw, FALLBACK)).toBe(FALLBACK);
    }
  );

  it('falls back and reports when the payload is malformed', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(parseInjectedJSON('{oops', FALLBACK, 'UNITS')).toBe(FALLBACK);
    expect(error).toHaveBeenCalledOnce();
    expect(error.mock.calls[0][0]).toContain('[UNITS]');
  });

  it('labels the error as INJECT when no label is given', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    parseInjectedJSON('{oops', FALLBACK);
    expect(error.mock.calls[0][0]).toContain('[INJECT]');
  });

  it('keeps a literal JSON null instead of falling back', () => {
    expect(parseInjectedJSON<unknown>('null', FALLBACK)).toBeNull();
  });
});

describe('readInjectedString', () => {
  it('returns the trimmed payload', () => {
    expect(readInjectedString('  Taiwan  ', 'fallback')).toBe('Taiwan');
  });

  it.each([undefined, '', '   '])('falls back on %o', (raw) => {
    expect(readInjectedString(raw, 'fallback')).toBe('fallback');
  });
});

describe('readInjectedBoolean', () => {
  it.each([
    ['true', true],
    ['false', false],
    ['  TRUE  ', true],
    [' False ', false],
  ])('reads %o as %s whatever the case or spacing', (raw, expected) => {
    expect(readInjectedBoolean(raw, !expected)).toBe(expected);
  });

  it.each([undefined, '', '   ', 'yes', '1', '%s'])(
    'falls back on the unfilled or unknown value %o',
    (raw) => {
      expect(readInjectedBoolean(raw, true)).toBe(true);
      expect(readInjectedBoolean(raw, false)).toBe(false);
    }
  );
});
