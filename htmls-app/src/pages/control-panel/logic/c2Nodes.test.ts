import type { C2NodeSet, C2SamUnit, C2Unit } from '@/types/generated';
import { describe, it, expect } from 'vitest';
import type { Battery } from '@pages/control-panel/logic/batteryGroups';
import {
  applySamWeaponsFree,
  buildC2MapLayers,
  buildC2NodeViews,
  getSamDeploymentWarning,
  collectC2ContextUpdates,
  collectSamUnits,
  OUTSIDE_OPERATING_ZONE,
} from './c2Nodes';

// ============================================================================
// FIXTURES
// ============================================================================
const ORIGIN = { latitude: 23, longitude: 120 };

function radarUnit(name: string, type = 'c2'): C2Unit {
  return {
    type,
    name,
    OODADetection: '15/15',
    OODATargeting: '5/5',
    isOutOfComms: false,
    EMCONSetting: 'Radar=Passive',
    isDestroyed: false,
    pos: { latitude: 23, longitude: 120 },
  };
}

function c2Unit(name: string, type = 'c2'): C2SamUnit {
  return { ...radarUnit(name, type), weaponFree: false };
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
    const nodes: C2NodeSet = {
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
    const nodes: C2NodeSet = {
      n1: { name: 'C2', type: 'c2', pos: ORIGIN, areas: [], sam: { g1: c2Unit('Same Name') } },
    };
    const batteries = [battery('sam_a', 'Same Name')];

    expect(buildC2NodeViews(nodes, batteries)[0].children[0].battery?.unitKey).toBe('sam_a');
  });

  it('leaves SAM units without a battery as plain cards', () => {
    const nodes: C2NodeSet = {
      n1: { name: 'C2', type: 'c2', pos: ORIGIN, areas: [], sam: { g1: c2Unit('Unknown') } },
    };

    expect(buildC2NodeViews(nodes, [battery('sam_a', 'Other')])[0].children[0].battery).toBe(null);
  });

  it('never gives one battery to two SAM units', () => {
    const nodes: C2NodeSet = {
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

  describe('redeployed SAM', () => {
    const zone = (latitude: number, longitude: number) => [
      { latitude: latitude - 1, longitude: longitude - 1 },
      { latitude: latitude - 1, longitude: longitude + 1 },
      { latitude: latitude + 1, longitude: longitude + 1 },
      { latitude: latitude + 1, longitude: longitude - 1 },
    ];
    const deployedAt = (latitude: number, longitude: number): Battery => ({
      ...battery('b1', 'SAM'),
      deployment: {
        tacticalAreas: { hideArea: zone(latitude, longitude).map((p) => ({ ...p })) },
      } as Battery['deployment'],
    });
    const twoNodes = (): C2NodeSet => ({
      a: {
        type: 'c2',
        name: 'A',
        pos: { latitude: 23, longitude: 120 },
        areas: [zone(23, 120)],
        sam: { s1: c2Unit('SAM') },
      },
      b: {
        type: 'c2',
        name: 'B',
        pos: { latitude: 30, longitude: 130 },
        areas: [zone(30, 130)],
      },
    });
    const childNames = (views: ReturnType<typeof buildC2NodeViews>) =>
      Object.fromEntries(views.map((view) => [view.key, view.children.map((c) => c.key)]));

    it('moves to the node whose zone it was redeployed into', () => {
      const views = buildC2NodeViews(twoNodes(), [deployedAt(30, 130)]);

      expect(childNames(views)).toEqual({ a: [], b: ['s1'] });
    });

    it('stays under its own node when still inside that zone', () => {
      const views = buildC2NodeViews(twoNodes(), [deployedAt(23, 120)]);

      expect(childNames(views)).toEqual({ a: ['s1'], b: [] });
    });

    it('keeps the pinned node after the deployment is cancelled', () => {
      const pinned = new Map([['s1', 'b']]);
      const views = buildC2NodeViews(twoNodes(), [battery('b1', 'SAM')], pinned);

      expect(childNames(views)).toEqual({ a: [], b: ['s1'] });
    });

    it('stays under its own node when redeployed outside every zone', () => {
      const views = buildC2NodeViews(twoNodes(), [deployedAt(10, 100)]);

      expect(childNames(views)).toEqual({ a: ['s1'], b: [] });
    });
  });
});

describe('collectSamUnits', () => {
  it('lists live SAM units with their GUID, name and weapons status', () => {
    const destroyed = { ...c2Unit('Dead SAM'), isDestroyed: true };
    const nodes: C2NodeSet = {
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
  const nodes: C2NodeSet = {
    n1: {
      type: 'c2',
      name: 'C2',
      pos: ORIGIN,
      areas: [],
      radar: { r1: radarUnit('Radar A') },
      sam: { s1: { ...c2Unit('SAM A'), weaponFree: true } },
    },
  };

  it('sets every SAM unit to the chosen status and leaves radars alone', () => {
    const [view] = applySamWeaponsFree(buildC2NodeViews(nodes, []), false);

    expect(
      view.children.map((child) => [
        child.type,
        'weaponFree' in child.unit ? child.unit.weaponFree : 'none',
      ])
    ).toEqual([
      ['radar', 'none'],
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
    const nodes: C2NodeSet = {
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
      const nodes: C2NodeSet = {
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
      const nodes: C2NodeSet = {
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

    it('draws neither marker nor line for a cancelled deployment', () => {
      const nodes: C2NodeSet = {
        n1: { type: 'c2', name: 'N', pos: ORIGIN, areas: [], sam: { s1: c2Unit('SAM') } },
      };
      const views = buildC2NodeViews(nodes, [battery('b1', 'SAM')]);

      const layers = buildC2MapLayers(views, new Map([['s1', 'n1']]));

      expect(layers.markers.map((marker) => marker.kind)).toEqual(['c2']);
      expect(layers.links).toEqual([]);
    });

    it('draws no line when the position is outside the nearest C2 zone', () => {
      const layers = layersFor({ latitude: 23.2, longitude: 120.2 }, square(21, 118));

      expect(layers.links).toEqual([]);
    });
  });
});

describe('getSamDeploymentWarning', () => {
  const zone = [
    { latitude: 22, longitude: 119 },
    { latitude: 22, longitude: 121 },
    { latitude: 24, longitude: 121 },
    { latitude: 24, longitude: 119 },
  ];
  const views = () =>
    buildC2NodeViews(
      {
        n1: { type: 'c2', name: 'N', pos: ORIGIN, areas: [zone], sam: { s1: c2Unit('SAM') } },
      },
      [battery('b1', 'SAM')]
    );

  it('lets a SAM deploy inside the zone of a node of its type', () => {
    expect(getSamDeploymentWarning(views(), 'b1', { latitude: 23, longitude: 120 })).toBeNull();
  });

  it('warns when the position is outside every zone', () => {
    expect(getSamDeploymentWarning(views(), 'b1', { latitude: 30, longitude: 130 })).toBe(
      OUTSIDE_OPERATING_ZONE
    );
  });

  it('ignores batteries that are no SAM unit of any node', () => {
    expect(getSamDeploymentWarning(views(), 'other', { latitude: 30, longitude: 130 })).toBeNull();
  });
});

describe('collectC2ContextUpdates', () => {
  const zone = (latitude: number, longitude: number) => [
    { latitude: latitude - 1, longitude: longitude - 1 },
    { latitude: latitude - 1, longitude: longitude + 1 },
    { latitude: latitude + 1, longitude: longitude + 1 },
    { latitude: latitude + 1, longitude: longitude - 1 },
  ];
  const nodes = (): C2NodeSet => ({
    a: {
      type: 'rocc',
      name: 'A',
      pos: { latitude: 23, longitude: 120 },
      areas: [zone(23, 120)],
      radar: { r1: c2Unit('Radar', 'rocc') },
      sam: { s1: c2Unit('SAM', 'rocc') },
    },
    b: {
      type: 'rocc',
      name: 'B',
      pos: { latitude: 30, longitude: 130 },
      areas: [zone(30, 130)],
    },
  });
  const deployedAt = (latitude: number, longitude: number): Battery => ({
    ...battery('b1', 'SAM'),
    deployment: {
      tacticalAreas: { hideArea: zone(latitude, longitude) },
    } as Battery['deployment'],
  });

  it('reports both nodes when a SAM moves, keyed like a C2 context', () => {
    const data = nodes();
    const views = buildC2NodeViews(data, [deployedAt(30, 130)]);

    expect(collectC2ContextUpdates(data, views)).toEqual([
      { guid: 'a', type: 'rocc', name: 'A', sam: {} },
      { guid: 'b', type: 'rocc', name: 'B', sam: { s1: { guid: 's1', name: 'SAM' } } },
    ]);
  });

  it('reports nothing when every SAM stays under its node', () => {
    const data = nodes();

    expect(collectC2ContextUpdates(data, buildC2NodeViews(data, [deployedAt(23, 120)]))).toEqual(
      []
    );
  });
});
