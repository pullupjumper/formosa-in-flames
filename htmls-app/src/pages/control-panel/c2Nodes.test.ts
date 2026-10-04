import { describe, it, expect } from 'vitest';
import type { C2Data, C2Unit } from '@/types/unitStatus';
import type { MissileGroupUnit } from '@pages/control-panel/missileGroups';
import { applySamWeaponsFree, buildC2NodeViews, collectSamUnits } from './c2Nodes';

// ============================================================================
// FIXTURES
// ============================================================================
function c2Unit(name: string): C2Unit {
  return {
    name,
    OODADetection: '15/15',
    OODATargeting: '5/5',
    isOutOfComms: false,
    EMCONSetting: 'Radar=Passive',
    isDestroyed: false,
    weaponFree: false,
  };
}

function launcher(unitKey: string, name: string, guid: string): MissileGroupUnit {
  return { unitKey, name, guid, isDeployed: false, openingAngle: null };
}

// ============================================================================
// TESTS
// ============================================================================
describe('buildC2NodeViews', () => {
  it('lists radar before SAM units under each node', () => {
    const nodes: C2Data = {
      n1: {
        name: 'C2 One',
        radar: { r1: c2Unit('Radar A') },
        SAM: { s1: c2Unit('SAM A') },
      },
    };

    const [view] = buildC2NodeViews(nodes, []);

    expect(view.name).toBe('C2 One');
    expect(view.children.map((child) => [child.type, child.unit.name])).toEqual([
      ['Radar', 'Radar A'],
      ['SAM', 'SAM A'],
    ]);
  });

  it('pairs a SAM unit with its launcher by GUID', () => {
    const nodes: C2Data = { n1: { name: 'C2', SAM: { g1: c2Unit('Renamed') } } };
    const launchers = [launcher('sam_a', 'Original', 'g1')];

    expect(buildC2NodeViews(nodes, launchers)[0].children[0].launcher?.unitKey).toBe('sam_a');
  });

  it('falls back to the unit name when no GUID matches', () => {
    const nodes: C2Data = { n1: { name: 'C2', SAM: { gX: c2Unit('Same Name') } } };
    const launchers = [launcher('sam_a', 'Same Name', 'g1')];

    expect(buildC2NodeViews(nodes, launchers)[0].children[0].launcher?.unitKey).toBe('sam_a');
  });

  it('leaves SAM units without a launcher as plain cards', () => {
    const nodes: C2Data = { n1: { name: 'C2', SAM: { g1: c2Unit('Unknown') } } };

    expect(
      buildC2NodeViews(nodes, [launcher('sam_a', 'Other', 'g9')])[0].children[0].launcher
    ).toBe(null);
  });

  it('never gives one launcher to two SAM units', () => {
    const nodes: C2Data = {
      n1: { name: 'C2', SAM: { g1: c2Unit('Twin'), g2: c2Unit('Twin') } },
    };

    const children = buildC2NodeViews(nodes, [launcher('sam_a', 'Twin', 'gZ')])[0].children;

    expect(children.map((child) => child.launcher?.unitKey ?? null)).toEqual(['sam_a', null]);
  });
});

describe('collectSamUnits', () => {
  it('lists live SAM units with their GUID, name and weapons status', () => {
    const destroyed = { ...c2Unit('Dead SAM'), isDestroyed: true };
    const nodes: C2Data = {
      n1: {
        name: 'C2',
        radar: { r1: c2Unit('Radar A') },
        SAM: { s1: { ...c2Unit('SAM A'), weaponFree: true }, s2: destroyed },
      },
    };

    expect(collectSamUnits(buildC2NodeViews(nodes, []))).toEqual([
      { guid: 's1', name: 'SAM A', weaponFree: true },
    ]);
  });
});

describe('applySamWeaponsFree', () => {
  const nodes: C2Data = {
    n1: {
      name: 'C2',
      radar: { r1: { ...c2Unit('Radar A'), weaponFree: false } },
      SAM: { s1: { ...c2Unit('SAM A'), weaponFree: true } },
    },
  };

  it('sets every SAM unit to the chosen status and leaves radars alone', () => {
    const [view] = applySamWeaponsFree(buildC2NodeViews(nodes, []), false);

    expect(view.children.map((child) => [child.type, child.unit.weaponFree])).toEqual([
      ['Radar', false],
      ['SAM', false],
    ]);
  });

  it('returns the nodes untouched when nothing was chosen', () => {
    const views = buildC2NodeViews(nodes, []);

    expect(applySamWeaponsFree(views, null)).toBe(views);
  });
});
