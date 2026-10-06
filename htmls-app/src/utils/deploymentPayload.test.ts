import { describe, it, expect } from 'vitest';
import {
  buildInjectedDeployments,
  fromOperationalArea,
  toExportPaths,
  toControlPanelResult,
} from '@/utils/deploymentPayload';
import { createBudgetState } from '@/utils/budgetLedger';
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
    expect(deployment.tacticalAreas.ammoArea).toBe(AREA.AHA[0].area);
    expect(deployment.tacticalAreas.firePoints).toHaveLength(AREA.FP.length);
  });

  it('pins the AHA to its stored square so rotate cannot move it', () => {
    expect(deployment.ahaRadius).toBeUndefined();
    expect(deployment.ahaCenter).toEqual(calculateCentroid(AREA.AHA[0].area));
  });

  it('stitches HA/AHA paths back onto the reload leg', () => {
    const reloadCourse = AREA.RL[0].course;
    expect(deployment.paths.HA.waypoints.slice(0, reloadCourse.length)).toEqual(reloadCourse);
    expect(deployment.paths.AHA.waypoints.slice(0, reloadCourse.length)).toEqual(reloadCourse);
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
  it('drops the leading waypoint only on HA/RL/AHA', () => {
    const paths = fromOperationalArea(CATEGORY, UNIT_NAME, AREA).paths;
    const exported = toExportPaths(paths);
    expect(exported.HA.waypoints).toEqual(paths.HA.waypoints.slice(1));
    expect(exported.AHA.waypoints).toEqual(paths.AHA.waypoints.slice(1));
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
    expect(system).not.toHaveProperty('ahaRadius');
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
      AHA: [{ course: exported.paths.AHA.waypoints, area: exported.tacticalAreas.ammoArea! }],
      HA: [{ course: exported.paths.HA.waypoints, area: exported.tacticalAreas.hideArea! }],
      SHRL: [{ course: exported.paths.SHRL.waypoints, area: [] }],
    };

    const restored = fromOperationalArea(CATEGORY, UNIT_NAME, area);
    expect(restored.tacticalAreas).toEqual(generated.tacticalAreas);
    expect(restored.paths.FP).toEqual(generated.paths.FP);
    expect(restored.paths.SHRL).toEqual(generated.paths.SHRL);
    expect(restored.ahaCenter).toEqual(calculateCentroid(generated.tacticalAreas.ammoArea!));
  });
});
