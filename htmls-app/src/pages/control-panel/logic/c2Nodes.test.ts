import { describe, it, expect } from 'vitest';
import type { C2Data, C2Unit } from '@/types/unitStatus';
import type { Battery } from '@pages/control-panel/logic/batteryGroups';
import {
  applySamWeaponsFree,
  buildC2MapLayers,
  buildC2NodeViews,
  collectSamUnits,
} from './c2Nodes';

// ============================================================================
// FIXTURES
// ============================================================================
const ORIGIN = { latitude: 23, longitude: 120 };

function c2Unit(name: string, type = 'c2'): C2Unit {
  return {
    type,
    name,
    OODADetection: '15/15',
    OODATargeting: '5/5',
    isOutOfComms: false,
    EMCONSetting: 'Radar=Passive',
    isDestroyed: false,
    weaponFree: false,
    pos: { latitude: 23, longitude: 120 },
  };
}

function battery(unitKey: string, name: string): Battery {
  return {
    unitKey,
    name,
    missileSystem: 'PAC-3',
    missileSystemType: 'sam',
    deployment: null,
    status: undefined,
  };
}

// ============================================================================
// TESTS
// ============================================================================
describe('buildC2NodeViews', () => {
  it('lists radar before SAM units under each node', () => {
    const nodes: C2Data = {
      n1: {
        type: 'c2',
        name: 'C2 One',
        pos: ORIGIN,
        areas: [],
        radar: { r1: c2Unit('Radar A') },
        sam: { s1: c2Unit('SAM A') },
      },
    };

    const [view] = buildC2NodeViews(nodes, []);

    expect(view.name).toBe('C2 One');
    expect(view.children.map((child) => [child.type, child.unit.name])).toEqual([
      ['radar', 'Radar A'],
      ['sam', 'SAM A'],
    ]);
  });

  it('pairs a SAM unit with its battery by name', () => {
    const nodes: C2Data = {
      n1: { name: 'C2', type: 'c2', pos: ORIGIN, areas: [], sam: { g1: c2Unit('Same Name') } },
    };
    const batteries = [battery('sam_a', 'Same Name')];

    expect(buildC2NodeViews(nodes, batteries)[0].children[0].battery?.unitKey).toBe('sam_a');
  });

  it('leaves SAM units without a battery as plain cards', () => {
    const nodes: C2Data = {
      n1: { name: 'C2', type: 'c2', pos: ORIGIN, areas: [], sam: { g1: c2Unit('Unknown') } },
    };

    expect(buildC2NodeViews(nodes, [battery('sam_a', 'Other')])[0].children[0].battery).toBe(null);
  });

  it('never gives one battery to two SAM units', () => {
    const nodes: C2Data = {
      n1: {
        type: 'c2',
        name: 'C2',
        pos: ORIGIN,
        areas: [],
        sam: { g1: c2Unit('Twin'), g2: c2Unit('Twin') },
      },
    };

    const children = buildC2NodeViews(nodes, [battery('sam_a', 'Twin')])[0].children;

    expect(children.map((child) => child.battery?.unitKey ?? null)).toEqual(['sam_a', null]);
  });
});

describe('collectSamUnits', () => {
  it('lists live SAM units with their GUID, name and weapons status', () => {
    const destroyed = { ...c2Unit('Dead SAM'), isDestroyed: true };
    const nodes: C2Data = {
      n1: {
        type: 'c2',
        name: 'C2',
        pos: ORIGIN,
        areas: [],
        radar: { r1: c2Unit('Radar A') },
        sam: { s1: { ...c2Unit('SAM A'), weaponFree: true }, s2: destroyed },
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
      type: 'c2',
      name: 'C2',
      pos: ORIGIN,
      areas: [],
      radar: { r1: { ...c2Unit('Radar A'), weaponFree: false } },
      sam: { s1: { ...c2Unit('SAM A'), weaponFree: true } },
    },
  };

  it('sets every SAM unit to the chosen status and leaves radars alone', () => {
    const [view] = applySamWeaponsFree(buildC2NodeViews(nodes, []), false);

    expect(view.children.map((child) => [child.type, child.unit.weaponFree])).toEqual([
      ['radar', false],
      ['sam', false],
    ]);
  });

  it('returns the nodes untouched when nothing was chosen', () => {
    const views = buildC2NodeViews(nodes, []);

    expect(applySamWeaponsFree(views, null)).toBe(views);
  });
});

describe('buildC2MapLayers', () => {
  const zone = [
    { latitude: 23, longitude: 120 },
    { latitude: 24, longitude: 120 },
    { latitude: 24, longitude: 121 },
  ];

  it('draws a zone shared by two nodes once and marks every unit', () => {
    const nodes: C2Data = {
      n1: {
        type: 'c2',
        name: 'A',
        pos: { latitude: 23, longitude: 120 },
        areas: [zone],
        radar: { r1: c2Unit('R') },
      },
      n2: {
        type: 'c2',
        name: 'B',
        pos: { latitude: 24, longitude: 120 },
        areas: [zone],
        sam: { s1: c2Unit('S') },
      },
    };

    const layers = buildC2MapLayers(buildC2NodeViews(nodes, []));

    expect(layers.zones).toHaveLength(1);
    expect(layers.links.map((link) => link.key)).toEqual(['n1-r1', 'n2-s1']);
    expect(layers.markers.map((marker) => marker.kind)).toEqual(['c2', 'radar', 'c2', 'sam']);
  });

  describe('deployed SAM', () => {
    const square = (latitude: number, longitude: number) => [
      { latitude: latitude - 0.01, longitude: longitude - 0.01 },
      { latitude: latitude - 0.01, longitude: longitude + 0.01 },
      { latitude: latitude + 0.01, longitude: longitude + 0.01 },
      { latitude: latitude + 0.01, longitude },
    ];
    const bigZone = [
      { latitude: 22, longitude: 119 },
      { latitude: 22, longitude: 121 },
      { latitude: 24, longitude: 121 },
      { latitude: 24, longitude: 119 },
    ];

    function layersFor(hideCenter: { latitude: number; longitude: number }, zone = bigZone) {
      const nodes: C2Data = {
        far: {
          type: 'c2',
          name: 'Far',
          pos: { latitude: 30, longitude: 130 },
          areas: [bigZone],
          sam: { s1: c2Unit('SAM') },
        },
        near: { type: 'c2', name: 'Near', pos: { latitude: 23, longitude: 120 }, areas: [zone] },
      };
      const deployed = {
        ...battery('b1', 'SAM'),
        deployment: {
          tacticalAreas: { hideArea: square(hideCenter.latitude, hideCenter.longitude) },
        } as Battery['deployment'],
      };
      return buildC2MapLayers(buildC2NodeViews(nodes, [deployed]));
    }

    it('links to the nearest C2 when the position is inside its zone', () => {
      const layers = layersFor({ latitude: 23.2, longitude: 120.2 });

      expect(layers.markers.map((marker) => marker.kind)).toEqual(['c2', 'c2']);
      expect(layers.links.map((link) => link.key)).toEqual(['near-s1']);
    });

    it('ignores nearer C2 nodes of another type', () => {
      const nodes: C2Data = {
        rocc: {
          type: 'rocc',
          name: 'ROCC',
          pos: { latitude: 23, longitude: 120 },
          areas: [bigZone],
        },
        taaoc: {
          type: 'taaoc',
          name: 'TAAOC',
          pos: { latitude: 23.5, longitude: 120.5 },
          areas: [bigZone],
          sam: { s1: c2Unit('SAM', 'taaoc') },
        },
      };
      const deployed = {
        ...battery('b1', 'SAM'),
        deployment: {
          tacticalAreas: { hideArea: square(23, 120) },
        } as Battery['deployment'],
      };

      const layers = buildC2MapLayers(buildC2NodeViews(nodes, [deployed]));

      expect(layers.links.map((link) => link.key)).toEqual(['taaoc-s1']);
    });

    it('draws no line when the position is outside the nearest C2 zone', () => {
      const layers = layersFor({ latitude: 23.2, longitude: 120.2 }, square(21, 118));

      expect(layers.links).toEqual([]);
    });
  });
});
