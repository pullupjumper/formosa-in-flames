import { describe, it, expect } from 'vitest';
import type { MissileSystemData, MissileSystemUnit } from '@/types/unitStatus';
import { buildLauncherStatusMap, getLauncherStatus } from './launcherStatus';

// ============================================================================
// FIXTURES
// ============================================================================
function row(name: string, missileSystemType: string): MissileSystemUnit {
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
describe('buildLauncherStatusMap', () => {
  const data: MissileSystemData = {
    'Resupply A': [row('Battery 1', 'sam'), row('Battery 2', 'sam')],
    'Resupply B': [row('Battery 1', 'srbm')],
  };

  it('finds a row by weapon category and unit name', () => {
    const map = buildLauncherStatusMap(data);

    expect(getLauncherStatus(map, 'sam', 'Battery 2')?.name).toBe('Battery 2');
  });

  it('keeps same-named units of different categories apart', () => {
    const map = buildLauncherStatusMap(data);

    expect(getLauncherStatus(map, 'srbm', 'Battery 1')?.resupplyUnitName).toBe('Resupply B');
    expect(getLauncherStatus(map, 'sam', 'Battery 1')?.resupplyUnitName).toBe('Resupply A');
  });

  it('returns undefined for units the payload does not list', () => {
    expect(getLauncherStatus(buildLauncherStatusMap(data), 'sam', 'Ghost')).toBeUndefined();
  });

  it('tolerates a missing or malformed payload', () => {
    expect(buildLauncherStatusMap(undefined).size).toBe(0);
    expect(buildLauncherStatusMap({ A: 'oops' } as unknown as MissileSystemData).size).toBe(0);
  });
});
