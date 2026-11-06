import type {
  AirbaseDeploymentDescriptor,
  ControlPanelResult,
  GNSSJammerDescriptor,
  MovementPath,
  MovementPathSet,
  PanelBattery,
} from '@/types/generated';
import type { BudgetState } from '@/pages/control-panel/logic/budgetLedger';
import type { Coordinate } from '@/types/geo';
import type { DeployedBattery } from '@/types/deployment';
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
 * Lua stores one reload route, so each fire point's way back is that route
 * from where the fire point's own route ends.
 */
export function buildInjectedDeployments(batteries: PanelBattery[]): Map<string, DeployedBattery> {
  return new Map(
    batteries.map(({ name, missileSystemType, placement }) => {
      const { tacticalAreas, paths } = placement;
      const reloadWaypoints = paths.RL[0]?.waypoints ?? [];

      return [
        name,
        {
          ...placement,
          name,
          missileSystemType,
          atpCenter: tacticalAreas.ATP[0] && calculateCentroid(tacticalAreas.ATP[0]),
          paths: {
            ...paths,
            // Lua encodes an empty table as `{}`; areas without a shelter loop send one
            SHRL: Array.isArray(paths.SHRL) ? paths.SHRL : [],
          },
          reloadReturnPaths: paths.FP.map((path) => ({
            waypoints: [...path.waypoints.slice(-1), ...reloadWaypoints],
          })),
        },
      ];
    })
  );
}

// ============================================================================
// EXPORT
// ============================================================================
function trimLeadingWaypoint(waypoints: Coordinate[]): Coordinate[] {
  return waypoints.length > 1 ? waypoints.slice(1) : waypoints;
}

function trimPath(path: MovementPath): MovementPath {
  return { ...path, waypoints: trimLeadingWaypoint(path.waypoints) };
}

/**
 * The Lua side prepends the reload point itself, so HA/RL/ATP paths drop their
 * first waypoint. FP and SHRL start at a shared gateway that every shelter must
 * pass through, so those stay intact.
 */
export function toExportPaths(paths: MovementPathSet): MovementPathSet {
  return {
    FP: paths.FP.map((path) => ({ ...path })),
    HA: paths.HA.map(trimPath),
    RL: paths.RL.map(trimPath),
    ATP: paths.ATP.map(trimPath),
    SHRL: paths.SHRL.map((path) => ({ ...path })),
  };
}

export interface ToControlPanelResultParams {
  budget: BudgetState;
  airbases: AirbaseDeploymentDescriptor[];
  jammers: GNSSJammerDescriptor[];
  deployedJammers: Map<number, Coordinate>;
  deployedBatteries: Map<string, DeployedBattery>;
  /** The scenario's own placements; a unit still holding its entry was not moved */
  injectedDeployments: ReadonlyMap<string, DeployedBattery>;
}

export function toControlPanelResult({
  budget,
  airbases,
  jammers,
  deployedJammers,
  deployedBatteries,
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
    batteries: Array.from(deployedBatteries.entries())
      .filter(([key, deployment]) => injectedDeployments.get(key) !== deployment)
      .map(([, deployment]) => ({
        name: deployment.name,
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
