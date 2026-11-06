import { describe, it, expect } from 'vitest';
import {
  buildInjectedBatteries,
  toExportPaths,
  toControlPanelResult,
} from '@/pages/control-panel/logic/deploymentPayload';
import { createBudgetState } from '@/pages/control-panel/logic/budgetLedger';
import { generateBattery } from '@/utils/deploymentGeometry';
import { calculateCentroid } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { BATTERIES_DATA, JAMMERS_DATA } from '@/data/controlPanelData';

const BATTERY = BATTERIES_DATA[0];
const CATEGORY = BATTERY.missileSystemType;
const UNIT_NAME = BATTERY.name;
const INJECTED = buildInjectedBatteries([BATTERY]).get(UNIT_NAME)!;

describe('buildInjectedBatteries', () => {
  it('keeps identity and the placement verbatim', () => {
    expect(INJECTED.name).toBe(UNIT_NAME);
    expect(INJECTED.missileSystemType).toBe(CATEGORY);
    expect(INJECTED.center).toBe(BATTERY.placement.center);
    expect(INJECTED.tacticalAreas).toBe(BATTERY.placement.tacticalAreas);
    expect(INJECTED.paths).toEqual(BATTERY.placement.paths);
  });

  it('pins the ATP to its stored square so rotate cannot move it', () => {
    expect(INJECTED.atpRadius).toBeUndefined();
    expect(INJECTED.atpCenter).toEqual(calculateCentroid(BATTERY.placement.tacticalAreas.ATP[0]));
  });

  it('reads an empty shelter loop sent as a Lua empty table as no paths', () => {
    const noLoop = {
      ...BATTERY,
      placement: {
        ...BATTERY.placement,
        paths: { ...BATTERY.placement.paths, SHRL: JSON.parse('{}') },
      },
    };

    expect(buildInjectedBatteries([noLoop]).get(UNIT_NAME)!.paths.SHRL).toEqual([]);
  });

  it('rebuilds each fire point way back from its own route and the reload route', () => {
    const { FP, RL } = BATTERY.placement.paths;

    expect(INJECTED.reloadReturnPaths).toHaveLength(FP.length);
    INJECTED.reloadReturnPaths.forEach((path, index) => {
      expect(path.waypoints).toEqual([...FP[index].waypoints.slice(-1), ...RL[0].waypoints]);
    });
  });

  it('creates one entry per battery', () => {
    expect(buildInjectedBatteries(BATTERIES_DATA).size).toBe(BATTERIES_DATA.length);
  });
});

const GENERATED = generateBattery({
  name: UNIT_NAME,
  missileSystemType: CATEGORY,
  center: { latitude: 23.9, longitude: 120.75 },
  angle: 90,
  validateTaiwanBoundary: false,
  rng: createSeededRandom(7),
})!;

describe('toExportPaths', () => {
  it('drops the leading waypoint only on HA/RL/ATP', () => {
    const paths = GENERATED.paths;
    const exported = toExportPaths(paths);
    expect(exported.HA[0].waypoints).toEqual(paths.HA[0].waypoints.slice(1));
    expect(exported.ATP[0].waypoints).toEqual(paths.ATP[0].waypoints.slice(1));
    exported.RL.forEach((path, index) =>
      expect(path.waypoints).toEqual(paths.RL[index].waypoints.slice(1))
    );
    expect(exported.FP).toEqual(paths.FP);
    expect(exported.SHRL).toEqual(paths.SHRL);
  });

  it('never trims a single-point path to nothing', () => {
    const paths = INJECTED.paths;
    const single = { ...paths, HA: [{ waypoints: [paths.HA[0].waypoints[0]] }] };
    expect(toExportPaths(single).HA[0].waypoints).toHaveLength(1);
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
      deployedBatteries: new Map(injected),
      injectedBatteries: injected,
    });

    expect(result.batteries).toEqual([]);
  });

  it('keeps a unit the player redeployed', () => {
    const injected = new Map([['k', INJECTED]]);
    const moved = generateBattery({
      name: UNIT_NAME,
      missileSystemType: CATEGORY,
      center: { latitude: 23.9, longitude: 120.75 },
      angle: 90,
      validateTaiwanBoundary: false,
      rng: createSeededRandom(3),
    });

    const result = toControlPanelResult({
      ...baseParams,
      deployedBatteries: new Map([['k', moved!]]),
      injectedBatteries: injected,
    });

    expect(result.batteries.map((battery) => battery.name)).toEqual([UNIT_NAME]);
  });

  it('uses the Lua field names and the trimmed paths', () => {
    const rng = createSeededRandom(7);
    const generated = generateBattery({
      name: UNIT_NAME,
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
      deployedBatteries: new Map([['k', generated!]]),
      injectedBatteries: new Map(),
    });

    expect(result.budget).toEqual({ initial: 1000, used: 0, remaining: 1000 });
    expect(result.jammers[0]).toMatchObject({
      zoneName: JAMMERS_DATA[0].zoneName,
      pos: { latitude: 24, longitude: 121 },
    });
    const battery = result.batteries[0];
    expect(battery.name).toBe(UNIT_NAME);
    expect(battery.placement.paths).toEqual(toExportPaths(generated!.paths));
    expect(battery.placement.paths.RL[0].waypoints).toEqual(
      generated!.reloadReturnPaths[0].waypoints.slice(1)
    );
    expect(battery.placement).not.toHaveProperty('reloadReturnPaths');
    expect(battery.placement).not.toHaveProperty('atpRadius');
  });
});
