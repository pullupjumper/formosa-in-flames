import { describe, it, expect } from 'vitest';
import {
  buildInjectedDeployments,
  toExportPaths,
  toControlPanelResult,
} from '@/pages/control-panel/logic/deploymentPayload';
import { buildUnitKey } from '@/pages/control-panel/logic/batteryGroups';
import { createBudgetState } from '@/pages/control-panel/logic/budgetLedger';
import { generateDeploymentData } from '@/utils/deploymentGeometry';
import { calculateCentroid } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { BATTERIES_DATA, JAMMERS_DATA } from '@/data/controlPanelData';

const BATTERY = BATTERIES_DATA[0];
const CATEGORY = BATTERY.missileSystemType;
const UNIT_NAME = BATTERY.name;
const UNIT_KEY = buildUnitKey(CATEGORY, UNIT_NAME);
const INJECTED = buildInjectedDeployments([BATTERY]).get(UNIT_KEY)!;

describe('buildInjectedDeployments', () => {
  it('keeps identity and the placement verbatim', () => {
    expect(INJECTED.unitname).toBe(UNIT_NAME);
    expect(INJECTED.missileSystemType).toBe(CATEGORY);
    expect(INJECTED.center).toBe(BATTERY.placement.center);
    expect(INJECTED.tacticalAreas).toBe(BATTERY.placement.tacticalAreas);
    expect(INJECTED.paths).toEqual(BATTERY.placement.paths);
  });

  it('pins the ATP to its stored square so rotate cannot move it', () => {
    expect(INJECTED.atpRadius).toBeUndefined();
    expect(INJECTED.atpCenter).toEqual(calculateCentroid(BATTERY.placement.tacticalAreas.atpArea!));
  });

  it('reads an empty shelter loop sent as a Lua empty table as no waypoints', () => {
    const noLoop = {
      ...BATTERY,
      placement: {
        ...BATTERY.placement,
        paths: { ...BATTERY.placement.paths, SHRL: JSON.parse('{"waypoints":{}}') },
      },
    };

    expect(buildInjectedDeployments([noLoop]).get(UNIT_KEY)!.paths.SHRL.waypoints).toEqual([]);
  });

  it('creates one entry per battery', () => {
    expect(buildInjectedDeployments(BATTERIES_DATA).size).toBe(BATTERIES_DATA.length);
  });
});

describe('toExportPaths', () => {
  it('drops the leading waypoint only on HA/RL/ATP', () => {
    const paths = INJECTED.paths;
    const exported = toExportPaths(paths);
    expect(exported.HA.waypoints).toEqual(paths.HA.waypoints.slice(1));
    expect(exported.ATP.waypoints).toEqual(paths.ATP.waypoints.slice(1));
    exported.RL.forEach((path, index) =>
      expect(path.waypoints).toEqual(paths.RL[index].waypoints.slice(1))
    );
    expect(exported.FP).toEqual(paths.FP);
    expect(exported.SHRL).toEqual(paths.SHRL);
  });

  it('never trims a single-point path to nothing', () => {
    const paths = INJECTED.paths;
    const single = { ...paths, HA: { waypoints: [paths.HA.waypoints[0]] } };
    expect(toExportPaths(single).HA.waypoints).toHaveLength(1);
  });
});

describe('toControlPanelResult', () => {
  const baseParams = {
    budget: createBudgetState(1000),
    airbases: [],
    jammers: JAMMERS_DATA,
    deployedJammers: new Map(),
  };

  it('leaves out scenario-placed units the player did not move', () => {
    const injected = new Map([['k', INJECTED]]);

    const result = toControlPanelResult({
      ...baseParams,
      deployedMissileSystems: new Map(injected),
      injectedDeployments: injected,
    });

    expect(result.batteries).toEqual([]);
  });

  it('keeps a unit the player redeployed', () => {
    const injected = new Map([['k', INJECTED]]);
    const moved = generateDeploymentData({
      unitname: UNIT_NAME,
      missileSystemType: CATEGORY,
      center: { latitude: 23.9, longitude: 120.75 },
      angle: 90,
      validateTaiwanBoundary: false,
      rng: createSeededRandom(3),
    });

    const result = toControlPanelResult({
      ...baseParams,
      deployedMissileSystems: new Map([['k', moved!]]),
      injectedDeployments: injected,
    });

    expect(result.batteries.map((battery) => battery.name)).toEqual([UNIT_NAME]);
  });

  it('uses the Lua field names and the trimmed paths', () => {
    const rng = createSeededRandom(7);
    const generated = generateDeploymentData({
      unitname: UNIT_NAME,
      missileSystemType: CATEGORY,
      center: { latitude: 23.9, longitude: 120.75 },
      angle: 90,
      validateTaiwanBoundary: false,
      rng,
    });
    expect(generated).not.toBeNull();

    const result = toControlPanelResult({
      budget: createBudgetState(1000),
      airbases: [],
      jammers: JAMMERS_DATA,
      deployedJammers: new Map([[0, { latitude: 24, longitude: 121 }]]),
      deployedMissileSystems: new Map([['k', generated!]]),
      injectedDeployments: new Map(),
    });

    expect(result.budget).toEqual({ initial: 1000, used: 0, remaining: 1000 });
    expect(result.jammers[0]).toMatchObject({
      zoneName: JAMMERS_DATA[0].zoneName,
      pos: { latitude: 24, longitude: 121 },
    });
    const battery = result.batteries[0];
    expect(battery.name).toBe(UNIT_NAME);
    expect(battery.placement.paths).toEqual(toExportPaths(generated!.paths));
    expect(battery.placement).not.toHaveProperty('atpRadius');
  });
});
