import { describe, it, expect } from 'vitest';
import type { MissileDeployment, MissileSystems } from '@/types/controlPanel';
import { buildMissileGroups } from '@/pages/control-panel/missileGroups';

// ============================================================================
// FIXTURES
// ============================================================================
const MISSILE_SYSTEMS = {
  ascm: {
    firingUnits: {
      HF3_01: { name: 'HF3 Battery 1', missileSystem: 'HF-3' },
      HF3_02: { name: 'HF3 Battery 2', missileSystem: 'HF-3' },
    },
  },
  // Categories without firing units are injected for their ammunition data only
  empty: {},
} as unknown as MissileSystems;

function deployedAt(angle: number): MissileDeployment {
  return { openingAngle: angle } as MissileDeployment;
}

// ============================================================================
// TESTS
// ============================================================================
describe('buildMissileGroups', () => {
  it('flattens firing units into unit keys and display names', () => {
    const [group] = buildMissileGroups(MISSILE_SYSTEMS, new Map());

    expect(group.missileSystemType).toBe('ascm');
    expect(group.units.map((unit) => unit.missileSystemType)).toEqual(['ASCM', 'ASCM']);
    expect(group.units.map((unit) => unit.unitKey)).toEqual(['ascm_HF3_01', 'ascm_HF3_02']);
    expect(group.units.map((unit) => unit.name)).toEqual(['HF3 Battery 1', 'HF3 Battery 2']);
    expect(group.units.map((unit) => unit.missileSystem)).toEqual(['HF-3', 'HF-3']);
  });

  it('skips categories that carry no firing units', () => {
    expect(buildMissileGroups(MISSILE_SYSTEMS, new Map())).toHaveLength(1);
  });

  it('marks deployed units and counts them per category', () => {
    const deployed = new Map([['ascm_HF3_02', deployedAt(270)]]);
    const [group] = buildMissileGroups(MISSILE_SYSTEMS, deployed);

    expect(group.deployedCount).toBe(1);
    expect(group.units[0]).toMatchObject({ isDeployed: false, openingAngle: null });
    expect(group.units[1]).toMatchObject({ isDeployed: true, openingAngle: 270 });
  });

  it('falls back to the uppercased category when the weapon is unnamed', () => {
    const unknown = { xyz: { firingUnits: { u: { name: 'U' } } } } as unknown as MissileSystems;
    expect(buildMissileGroups(unknown, new Map())[0].units[0].missileSystemType).toBe('XYZ');
  });
});
