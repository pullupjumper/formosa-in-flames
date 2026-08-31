/**
 * Random source abstraction for the geometry generators.
 *
 * The generators place squares and fire points by rejection sampling, so they
 * need randomness at runtime but must be reproducible under test. Every entry
 * point takes a `RandomSource` that defaults to `Math.random`.
 */

/** Returns a number in [0, 1), same contract as `Math.random`. */
export type RandomSource = () => number;

/**
 * Deterministic `RandomSource` (mulberry32): the same seed always yields the
 * same sequence, which is what lets tests assert on generated geometry.
 */
export function createSeededRandom(seed: number): RandomSource {
  let state = seed >>> 0;

  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
