import { describe, it, expect } from 'vitest';
import type { BatteryStatus } from '@/types/unitStatus';
import { buildBatteryStatusMap, getBatteryStatus } from './batteryStatus';

// ============================================================================
// FIXTURES
// ============================================================================
function row(name: string, missileSystemType: string): BatteryStatus {
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
describe('buildBatteryStatusMap', () => {
  const data: BatteryStatus[] = [
    row('Battery 1', 'sam'),
    row('Battery 2', 'sam'),
    row('Battery 1', 'srbm'),
  ];

  it('finds a row by weapon category and unit name', () => {
    const map = buildBatteryStatusMap(data);

    expect(getBatteryStatus(map, 'sam', 'Battery 2')?.name).toBe('Battery 2');
  });

  it('keeps same-named units of different categories apart', () => {
    const map = buildBatteryStatusMap(data);

    expect(getBatteryStatus(map, 'srbm', 'Battery 1')?.missileSystemType).toBe('srbm');
    expect(getBatteryStatus(map, 'sam', 'Battery 1')?.missileSystemType).toBe('sam');
  });

  it('returns undefined for units the payload does not list', () => {
    expect(getBatteryStatus(buildBatteryStatusMap(data), 'sam', 'Ghost')).toBeUndefined();
  });

  it('tolerates a missing or malformed payload', () => {
    expect(buildBatteryStatusMap(undefined).size).toBe(0);
    expect(buildBatteryStatusMap({ A: 'oops' } as unknown as BatteryStatus[]).size).toBe(0);
  });
});
