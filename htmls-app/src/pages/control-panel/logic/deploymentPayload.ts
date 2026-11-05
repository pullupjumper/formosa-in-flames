import type { BudgetState } from '@/pages/control-panel/logic/budgetLedger';
import type { Coordinate } from '@/types/geo';
import type {
  Airbase,
  Jammer,
  MissileSystemTypes,
  OperationalArea,
  ControlPanelResult,
} from '@/types/controlPanel';
import type { MissileDeployment, MovementPaths } from '@/types/deployment';
import { buildUnitKey } from './batteryGroups';
import { calculateCentroid } from '@/utils/geo';

/**
 * Shape conversion between the Lua payload and the map-side deployment
 * (`controlPanelPayload.ts` owns the `window` reads and host writes).
 *
 * Import side: `fromOperationalArea` + `buildInjectedDeployments`.
 * Export side: `toControlPanelResult`.
 * Both are pure, so a round-trip test can pin the payload convention without
 * a browser.
 */

// ============================================================================
// IMPORT
// ============================================================================
/**
 * Rebuild the map-side deployment for a unit the scenario already placed, so it
 * renders and rotates exactly like a player-placed one.
 *
 * The Lua side stores one course per area that already includes the reload leg,
 * so HA/ATP paths are stitched back from RL + area course. `atpCenter` is the
 * centroid of the stored ATP square; without it a later rotate would regenerate
 * the ATP from `AREA_CONFIG` and move it.
 */
export function fromOperationalArea(
  missileSystemType: string,
  unitname: string,
  operationalArea: OperationalArea
): MissileDeployment {
  const reloadCourse = operationalArea.RL[0].course;
  const atpArea = operationalArea.ATP[0].area;

  return {
    unitname,
    missileSystemType,
    center: calculateCentroid(operationalArea.uShapeVertices),
    openingAngle: 0,
    atpCenter: calculateCentroid(atpArea),
    tacticalAreas: {
      uShapeVertices: operationalArea.uShapeVertices,
      atpArea,
      hideArea: operationalArea.HA[0].area,
      reloadArea: operationalArea.RL[0].area,
      firePoints: operationalArea.FP.map((position) => position.area),
      shelterPoints: operationalArea.shelterPoints,
    },
    paths: {
      FP: operationalArea.FP.map((position) => ({ waypoints: position.course })),
      HA: { waypoints: reloadCourse.concat(operationalArea.HA[0].course) },
      ATP: { waypoints: reloadCourse.concat(operationalArea.ATP[0].course) },
      RL: operationalArea.FP.map((position) => ({
        waypoints: [position.course[position.course.length - 1]].concat(reloadCourse),
      })),
      SHRL: { waypoints: operationalArea.SHRL?.[0]?.course ?? [] },
    },
  };
}

/** Every scenario-placed firing unit, keyed the same way as player placements. */
export function buildInjectedDeployments(
  missileSystems: MissileSystemTypes
): Map<string, MissileDeployment> {
  const deployments = new Map<string, MissileDeployment>();

  for (const [missileSystemType, system] of Object.entries(missileSystems)) {
    for (const [unitname, unit] of Object.entries(system.firingUnits ?? {})) {
      deployments.set(
        buildUnitKey(missileSystemType, unitname),
        fromOperationalArea(missileSystemType, unitname, unit.operationalArea)
      );
    }
  }

  return deployments;
}

// ============================================================================
// EXPORT
// ============================================================================
function trimLeadingWaypoint(waypoints: Coordinate[]): Coordinate[] {
  return waypoints.length > 1 ? waypoints.slice(1) : waypoints;
}

/**
 * The Lua side prepends the reload point itself, so HA/RL/ATP paths drop their
 * first waypoint. FP and SHRL start at a shared gateway that every shelter must
 * pass through, so those stay intact.
 */
export function toExportPaths(paths: MovementPaths): MovementPaths {
  return {
    FP: paths.FP.map((path) => ({ ...path })),
    HA: { ...paths.HA, waypoints: trimLeadingWaypoint(paths.HA.waypoints) },
    RL: paths.RL.map((path) => ({ ...path, waypoints: trimLeadingWaypoint(path.waypoints) })),
    ATP: { ...paths.ATP, waypoints: trimLeadingWaypoint(paths.ATP.waypoints) },
    SHRL: { ...paths.SHRL },
  };
}

export interface ToControlPanelResultParams {
  budget: BudgetState;
  airbases: Airbase[];
  jammers: Jammer[];
  deployedJammers: Map<number, Coordinate>;
  deployedMissileSystems: Map<string, MissileDeployment>;
  /** The scenario's own placements; a unit still holding its entry was not moved */
  injectedDeployments: ReadonlyMap<string, MissileDeployment>;
}

export function toControlPanelResult({
  budget,
  airbases,
  jammers,
  deployedJammers,
  deployedMissileSystems,
  injectedDeployments,
}: ToControlPanelResultParams): ControlPanelResult {
  return {
    budget: { initial: budget.total, used: budget.used, remaining: budget.current },
    airbases,
    jammers: Array.from(deployedJammers.entries()).map(([index, position]) => {
      const unit = jammers[index];
      return {
        zoneName: unit.zoneName,
        name: unit.name,
        pos: position,
        randomRadiusNm: unit.randomRadiusNm,
        radiusNm: unit.radiusNm,
      };
    }),
    missileSystems: Array.from(deployedMissileSystems.entries())
      .filter(([key, deployment]) => injectedDeployments.get(key) !== deployment)
      .map(([key, deployment]) => ({
        key,
        unitname: deployment.unitname,
        missileSystemType: deployment.missileSystemType,
        center: deployment.center,
        openingAngle: deployment.openingAngle,
        tacticalAreas: deployment.tacticalAreas,
        paths: toExportPaths(deployment.paths),
      })),
  };
}
