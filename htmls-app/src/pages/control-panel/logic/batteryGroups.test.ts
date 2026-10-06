import { describe, it, expect } from 'vitest';
import type { MissileDeployment, MissileSystemTypes } from '@/types/controlPanel';
import type { BatteryStatus } from '@/types/unitStatus';
import { buildBatteryGroups, buildWeaponRanges } from '@/pages/control-panel/logic/batteryGroups';

// ============================================================================
// FIXTURES
// ============================================================================
const MISSILE_SYSTEM_TYPES = {
  ascm: {
    firingUnits: {
      HF3_01: { name: 'HF3 Battery 1', missileSystem: 'HF-3' },
      HF3_02: { name: 'HF3 Battery 2', missileSystem: 'HF-3' },
    },
  },
  // Types without firing units are injected for their ammunition data only
  empty: {},
} as unknown as MissileSystemTypes;

function deployedAt(angle: number): MissileDeployment {
  return { openingAngle: angle } as MissileDeployment;
}

function status(name: string, missileSystemType: string): BatteryStatus {
  return {
    name,
    missileSystemType,
    firingUnitState: 'STATIC',
    resupplyUnitState: 'STATIC',
    firingUnitReloadTime: 0,
    defaultReloadTime: 10,
    resupplyUnitReloadTime: 0,
    missilesInAmmoVehicles: 4,
    missilesInAHA: 8,
  };
}

// ============================================================================
// TESTS
// ============================================================================
describe('buildBatteryGroups', () => {
  it('flattens firing units into unit keys and display names', () => {
    const [group] = buildBatteryGroups(MISSILE_SYSTEM_TYPES, new Map(), []);

    expect(group.missileSystemType).toBe('ascm');
    expect(group.batteries.map((battery) => battery.missileSystemType)).toEqual(['ascm', 'ascm']);
    expect(group.batteries.map((battery) => battery.unitKey)).toEqual([
      'ascm_HF3_01',
      'ascm_HF3_02',
    ]);
    expect(group.batteries.map((battery) => battery.name)).toEqual([
      'HF3 Battery 1',
      'HF3 Battery 2',
    ]);
    expect(group.batteries.map((battery) => battery.missileSystem)).toEqual(['HF-3', 'HF-3']);
  });

  it('skips types that carry no firing units', () => {
    expect(buildBatteryGroups(MISSILE_SYSTEM_TYPES, new Map(), [])).toHaveLength(1);
  });

  it('attaches the deployment and counts deployed batteries per type', () => {
    const deployed = new Map([['ascm_HF3_02', deployedAt(270)]]);
    const [group] = buildBatteryGroups(MISSILE_SYSTEM_TYPES, deployed, []);

    expect(group.deployedCount).toBe(1);
    expect(group.batteries[0].deployment).toBeNull();
    expect(group.batteries[1].deployment?.openingAngle).toBe(270);
  });

  it('pairs each battery with the status of its own type and name', () => {
    const statuses = [status('HF3 Battery 2', 'ascm'), status('HF3 Battery 1', 'srbm')];
    const [group] = buildBatteryGroups(MISSILE_SYSTEM_TYPES, new Map(), statuses);

    expect(group.batteries[0].status).toBeUndefined();
    expect(group.batteries[1].status).toBe(statuses[0]);
  });

  it('tolerates a missing or malformed status payload', () => {
    const bad = { A: 'oops' } as unknown as BatteryStatus[];

    expect(
      buildBatteryGroups(MISSILE_SYSTEM_TYPES, new Map(), undefined)[0].batteries[0].status
    ).toBeUndefined();
    expect(
      buildBatteryGroups(MISSILE_SYSTEM_TYPES, new Map(), bad)[0].batteries[0].status
    ).toBeUndefined();
  });

  it('keeps the type key when the weapon is unnamed', () => {
    const unknown = { xyz: { firingUnits: { u: { name: 'U' } } } } as unknown as MissileSystemTypes;
    expect(buildBatteryGroups(unknown, new Map(), [])[0].batteries[0].missileSystemType).toBe(
      'xyz'
    );
  });
});

describe('buildWeaponRanges', () => {
  it('keys each firing unit range by its unit key', () => {
    const types = {
      ascm: { firingUnits: { HF3_01: { weaponRange: 150 }, HF3_02: { weaponRange: 120 } } },
      empty: {},
    } as unknown as MissileSystemTypes;

    expect(buildWeaponRanges(types)).toEqual(
      new Map([
        ['ascm_HF3_01', 150],
        ['ascm_HF3_02', 120],
      ])
    );
  });
});
