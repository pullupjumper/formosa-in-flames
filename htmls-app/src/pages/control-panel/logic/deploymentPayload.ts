import type {
  Airbase,
  ControlPanelResult,
  GNSSJammerDescriptor,
  MovementPathSet,
  PanelBattery,
} from '@/types/generated';
import type { BudgetState } from '@/pages/control-panel/logic/budgetLedger';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment } from '@/types/deployment';
import { buildUnitKey } from './batteryGroups';
import { calculateCentroid } from '@/utils/geo';

/**
 * Shape conversion between the Lua payload and the map-side deployment
 * (`controlPanelPayload.ts` owns the `window` reads and host writes).
 *
 * Import side: `buildInjectedDeployments`.
 * Export side: `toControlPanelResult`.
 * Both are pure, so a round-trip test can pin the payload convention without
 * a browser.
 */

// ============================================================================
// IMPORT
// ============================================================================
/**
 * Every scenario-placed battery as a map-side deployment, keyed the same way as
 * player placements. `atpCenter` pins the ATP to its stored square; without it
 * a later rotate would regenerate the ATP from `AREA_CONFIG` and move it.
 */
export function buildInjectedDeployments(
  batteries: PanelBattery[]
): Map<string, MissileDeployment> {
  return new Map(
    batteries.map(({ name, missileSystemType, placement }) => [
      buildUnitKey(missileSystemType, name),
      {
        ...placement,
        unitname: name,
        missileSystemType,
        atpCenter:
          placement.tacticalAreas.atpArea && calculateCentroid(placement.tacticalAreas.atpArea),
        paths: {
          ...placement.paths,
          // Lua encodes an empty table as `{}`; areas without a shelter loop send one
          SHRL: {
            waypoints: Array.isArray(placement.paths.SHRL.waypoints)
              ? placement.paths.SHRL.waypoints
              : [],
          },
        },
      },
    ])
  );
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
export function toExportPaths(paths: MovementPathSet): MovementPathSet {
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
  jammers: GNSSJammerDescriptor[];
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
    batteries: Array.from(deployedMissileSystems.entries())
      .filter(([key, deployment]) => injectedDeployments.get(key) !== deployment)
      .map(([, deployment]) => ({
        name: deployment.unitname,
        missileSystemType: deployment.missileSystemType,
        placement: {
          center: deployment.center,
          openingAngle: deployment.openingAngle,
          tacticalAreas: deployment.tacticalAreas,
          paths: toExportPaths(deployment.paths),
        },
      })),
  };
}
