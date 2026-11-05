import { describe, it, expect } from 'vitest';
import {
  buildInjectedDeployments,
  fromOperationalArea,
  toExportPaths,
  toControlPanelResult,
} from '@/pages/control-panel/logic/deploymentPayload';
import { createBudgetState } from '@/pages/control-panel/logic/budgetLedger';
import { generateDeploymentData } from '@/utils/deploymentGeometry';
import { calculateCentroid } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { MISSILE_SYSTEMS_DATA, JAMMERS_DATA } from '@/data/controlPanelData';
import type { OperationalArea } from '@/types/controlPanel';

const [CATEGORY, SYSTEM] = Object.entries(MISSILE_SYSTEMS_DATA)[0];
const [UNIT_NAME, UNIT] = Object.entries(SYSTEM.firingUnits)[0];
const AREA: OperationalArea = UNIT.operationalArea;

describe('fromOperationalArea', () => {
  const deployment = fromOperationalArea(CATEGORY, UNIT_NAME, AREA);

  it('keeps identity and stored areas verbatim', () => {
    expect(deployment.unitname).toBe(UNIT_NAME);
    expect(deployment.missileSystemType).toBe(CATEGORY);
    expect(deployment.tacticalAreas.uShapeVertices).toBe(AREA.uShapeVertices);
    expect(deployment.tacticalAreas.atpArea).toBe(AREA.ATP[0].area);
    expect(deployment.tacticalAreas.firePoints).toHaveLength(AREA.FP.length);
  });

  it('pins the ATP to its stored square so rotate cannot move it', () => {
    expect(deployment.atpRadius).toBeUndefined();
    expect(deployment.atpCenter).toEqual(calculateCentroid(AREA.ATP[0].area));
  });

  it('stitches HA/ATP paths back onto the reload leg', () => {
    const reloadCourse = AREA.RL[0].course;
    expect(deployment.paths.HA.waypoints.slice(0, reloadCourse.length)).toEqual(reloadCourse);
    expect(deployment.paths.ATP.waypoints.slice(0, reloadCourse.length)).toEqual(reloadCourse);
  });
});

describe('buildInjectedDeployments', () => {
  it('creates one entry per firing unit across categories', () => {
    const expected = Object.values(MISSILE_SYSTEMS_DATA).reduce(
      (sum, system) => sum + Object.keys(system.firingUnits ?? {}).length,
      0
    );
    expect(buildInjectedDeployments(MISSILE_SYSTEMS_DATA).size).toBe(expected);
  });
});

describe('toExportPaths', () => {
  it('drops the leading waypoint only on HA/RL/ATP', () => {
    const paths = fromOperationalArea(CATEGORY, UNIT_NAME, AREA).paths;
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
    const paths = fromOperationalArea(CATEGORY, UNIT_NAME, AREA).paths;
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
    const injected = new Map([['k', fromOperationalArea(CATEGORY, UNIT_NAME, AREA)]]);

    const result = toControlPanelResult({
      ...baseParams,
      deployedMissileSystems: new Map(injected),
      injectedDeployments: injected,
    });

    expect(result.missileSystems).toEqual([]);
  });

  it('keeps a unit the player redeployed', () => {
    const injected = new Map([['k', fromOperationalArea(CATEGORY, UNIT_NAME, AREA)]]);
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

    expect(result.missileSystems.map((system) => system.key)).toEqual(['k']);
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
    const system = result.missileSystems[0];
    expect(system.key).toBe('k');
    expect(system.unitname).toBe(UNIT_NAME);
    expect(system.paths).toEqual(toExportPaths(generated!.paths));
    expect(system).not.toHaveProperty('atpRadius');
  });

  it('round-trips a generated deployment through the Lua area shape', () => {
    const rng = createSeededRandom(11);
    const generated = generateDeploymentData({
      unitname: UNIT_NAME,
      missileSystemType: CATEGORY,
      center: { latitude: 23.9, longitude: 120.75 },
      angle: 45,
      validateTaiwanBoundary: false,
      rng,
    })!;
    const exported = toControlPanelResult({
      budget: createBudgetState(0),
      airbases: [],
      jammers: [],
      deployedJammers: new Map(),
      deployedMissileSystems: new Map([['k', generated]]),
      injectedDeployments: new Map(),
    }).missileSystems[0];

    // Mirror what unitStatusUI.lua's transformData stores per area.
    const reloadPoint = exported.paths.RL[0].waypoints[0];
    const area: OperationalArea = {
      uShapeVertices: exported.tacticalAreas.uShapeVertices,
      shelterPoints: exported.tacticalAreas.shelterPoints ?? [],
      FP: exported.paths.FP.map((path, index) => ({
        course: path.waypoints,
        area: exported.tacticalAreas.firePoints![index],
      })),
      RL: [{ course: [reloadPoint], area: exported.tacticalAreas.reloadArea! }],
      ATP: [{ course: exported.paths.ATP.waypoints, area: exported.tacticalAreas.atpArea! }],
      HA: [{ course: exported.paths.HA.waypoints, area: exported.tacticalAreas.hideArea! }],
      SHRL: [{ course: exported.paths.SHRL.waypoints, area: [] }],
    };

    const restored = fromOperationalArea(CATEGORY, UNIT_NAME, area);
    expect(restored.tacticalAreas).toEqual(generated.tacticalAreas);
    expect(restored.paths.FP).toEqual(generated.paths.FP);
    expect(restored.paths.SHRL).toEqual(generated.paths.SHRL);
    expect(restored.atpCenter).toEqual(calculateCentroid(generated.tacticalAreas.atpArea!));
  });
});
