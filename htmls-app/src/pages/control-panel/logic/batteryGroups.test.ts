import type { BatteryStatus, PanelBattery } from '@/types/generated';
import { describe, it, expect } from 'vitest';
import type { DeployedBattery } from '@/types/deployment';
import { buildBatteryGroups, buildWeaponRanges } from '@/pages/control-panel/logic/batteryGroups';

// ============================================================================
// FIXTURES
// ============================================================================
const STATUS: BatteryStatus = {
  firingPosture: 'STATIC',
  resupplyPosture: 'STATIC',
  firingReloadMinutes: 0,
  reloadMinutesDefault: 10,
  resupplyReloadMinutes: 0,
  resupplyMissiles: 4,
  resupplyMissilesDefault: 8,
  canisterMissiles: 8,
  canisterMissilesDefault: 16,
};

function battery(
  name: string,
  missileSystemType: string,
  overrides: Partial<PanelBattery> = {}
): PanelBattery {
  return {
    name,
    missileSystem: 'HF-3',
    missileSystemType,
    weaponRange: 0,
    placement: {} as PanelBattery['placement'],
    ...overrides,
  };
}

const BATTERIES = [
  battery('HF3 Battery 1', 'ascm'),
  battery('TK Battery', 'sam'),
  battery('HF3 Battery 2', 'ascm', { status: STATUS }),
];

function deployedAt(angle: number): DeployedBattery {
  return { openingAngle: angle } as DeployedBattery;
}

// ============================================================================
// TESTS
// ============================================================================
describe('buildBatteryGroups', () => {
  it('groups batteries by type in the order each type first appears', () => {
    const groups = buildBatteryGroups(BATTERIES, new Map());

    expect(groups.map((group) => group.missileSystemType)).toEqual(['ascm', 'sam']);
    expect(groups[0].batteries.map((item) => item.name)).toEqual([
      'HF3 Battery 1',
      'HF3 Battery 2',
    ]);
    expect(groups[0].batteries.map((item) => item.missileSystem)).toEqual(['HF-3', 'HF-3']);
  });

  it('returns no groups when there are no batteries', () => {
    expect(buildBatteryGroups([], new Map())).toEqual([]);
  });

  it('attaches the deployment and counts deployed batteries per type', () => {
    const deployed = new Map([['HF3 Battery 2', deployedAt(270)]]);
    const [group] = buildBatteryGroups(BATTERIES, deployed);

    expect(group.deployedCount).toBe(1);
    expect(group.batteries[0].deployment).toBeNull();
    expect(group.batteries[1].deployment?.openingAngle).toBe(270);
  });

  it("keeps each battery's own status, absent before its first deploy", () => {
    const [group] = buildBatteryGroups(BATTERIES, new Map());

    expect(group.batteries[0].status).toBeUndefined();
    expect(group.batteries[1].status).toBe(STATUS);
  });
});

describe('buildWeaponRanges', () => {
  it('keys each battery range by its name', () => {
    const batteries = [
      battery('HF3_01', 'ascm', { weaponRange: 150 }),
      battery('HF3_02', 'ascm', { weaponRange: 120 }),
    ];

    expect(buildWeaponRanges(batteries)).toEqual(
      new Map([
        ['HF3_01', 150],
        ['HF3_02', 120],
      ])
    );
  });
});
