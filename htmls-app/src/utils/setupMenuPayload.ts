import type { Coordinate } from '@/types/geo';
import type {
  Airbase,
  AmphibiousLocation,
  Jammer,
  MissileDeployment,
  MissileSystems,
  MovementPaths,
  OperationalArea,
  SetupMenuData,
  SetupResult,
  BudgetState,
} from '@/types/setupMenu';
import { parseInjectedJSON, readInjectedString } from '@/utils/inject';
import {
  AIRBASES_DATA,
  JAMMERS_DATA,
  MISSILE_SYSTEMS_DATA,
  AMPHIBIOUS_LOCATION_DATA,
} from '@/data/setupMenuData';
import { makeUnitKey } from '@/utils/map';
import { calculateCentroid } from '@/utils/geo';

/**
 * The one place that knows the shape of what `unitStatusUI.lua` injects into
 * the setup menu and what it reads back from `summaryData`.
 *
 * Import side: `readSetupMenuData` + `fromOperationalArea`.
 * Export side: `toSetupResult`.
 * Both are pure apart from the `window` read, so a round-trip test can pin the
 * payload convention without a browser.
 */

declare global {
  interface Window {
    __INJECT_JAMMERS__?: string;
    __INJECT_AIRBASES__?: string;
    __INJECT_MISSILE_SYSTEMS__?: string;
    __INJECT_SIDE_NAME__?: string;
    __INJECT_AMPHIBIOUS_LOCATIONS__?: string;
  }
}

// ============================================================================
// IMPORT
// ============================================================================
export function readSetupMenuData(): SetupMenuData {
  return {
    airbases: parseInjectedJSON<Airbase[]>(window.__INJECT_AIRBASES__, AIRBASES_DATA, 'AIRBASES'),
    jammers: parseInjectedJSON<Jammer[]>(window.__INJECT_JAMMERS__, JAMMERS_DATA, 'JAMMERS'),
    missileSystems: parseInjectedJSON<MissileSystems>(
      window.__INJECT_MISSILE_SYSTEMS__,
      MISSILE_SYSTEMS_DATA,
      'MISSILE_SYSTEMS'
    ),
    sideName: readInjectedString(window.__INJECT_SIDE_NAME__, 'Taiwan'),
    amphibiousLocations: parseInjectedJSON<AmphibiousLocation[]>(
      window.__INJECT_AMPHIBIOUS_LOCATIONS__,
      AMPHIBIOUS_LOCATION_DATA,
      'AMPHIBIOUS_LOCATIONS'
    ),
  };
}

/**
 * Rebuild the map-side deployment for a unit the scenario already placed, so it
 * renders and rotates exactly like a player-placed one.
 *
 * The Lua side stores one course per area that already includes the reload leg,
 * so HA/AHA paths are stitched back from RL + area course. `ahaCenter` is the
 * centroid of the stored AHA square; without it a later rotate would regenerate
 * the AHA from `AREA_CONFIG` and move it.
 */
export function fromOperationalArea(
  category: string,
  unitName: string,
  operationalArea: OperationalArea
): MissileDeployment {
  const reloadCourse = operationalArea.RL[0].course;
  const ammoArea = operationalArea.AHA[0].area;

  return {
    unitName,
    category,
    center: calculateCentroid(operationalArea.uShapeVertices),
    openingAngle: 0,
    ahaCenter: calculateCentroid(ammoArea),
    tacticalAreas: {
      uShapeVertices: operationalArea.uShapeVertices,
      ammoArea,
      hideArea: operationalArea.HA[0].area,
      reloadArea: operationalArea.RL[0].area,
      firePoints: operationalArea.FP.map((position) => position.area),
      shelterPoints: operationalArea.shelterPoints,
    },
    paths: {
      FP: operationalArea.FP.map((position) => ({ waypoints: position.course })),
      HA: { waypoints: reloadCourse.concat(operationalArea.HA[0].course) },
      AHA: { waypoints: reloadCourse.concat(operationalArea.AHA[0].course) },
      RL: operationalArea.FP.map((position) => ({
        waypoints: [position.course[position.course.length - 1]].concat(reloadCourse),
      })),
      SHRL: { waypoints: operationalArea.SHRL?.[0]?.course ?? [] },
    },
  };
}

/** Every scenario-placed firing unit, keyed the same way as player placements. */
export function buildInjectedDeployments(
  missileSystems: MissileSystems
): Map<string, MissileDeployment> {
  const deployments = new Map<string, MissileDeployment>();

  for (const [category, system] of Object.entries(missileSystems)) {
    for (const [unitName, unit] of Object.entries(system.firingUnits ?? {})) {
      deployments.set(
        makeUnitKey(category, unitName),
        fromOperationalArea(category, unitName, unit.operationalArea)
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
 * The Lua side prepends the reload point itself, so HA/RL/AHA paths drop their
 * first waypoint. FP and SHRL start at a shared gateway that every shelter must
 * pass through, so those stay intact.
 */
export function toExportPaths(paths: MovementPaths): MovementPaths {
  return {
    FP: paths.FP.map((path) => ({ ...path })),
    HA: { ...paths.HA, waypoints: trimLeadingWaypoint(paths.HA.waypoints) },
    RL: paths.RL.map((path) => ({ ...path, waypoints: trimLeadingWaypoint(path.waypoints) })),
    AHA: { ...paths.AHA, waypoints: trimLeadingWaypoint(paths.AHA.waypoints) },
    SHRL: { ...paths.SHRL },
  };
}

export interface ToSetupResultParams {
  budget: BudgetState;
  airbases: Airbase[];
  jammers: Jammer[];
  deployedJammers: Map<number, Coordinate>;
  deployedMissileSystems: Map<string, MissileDeployment>;
}

export function toSetupResult({
  budget,
  airbases,
  jammers,
  deployedJammers,
  deployedMissileSystems,
}: ToSetupResultParams): SetupResult {
  return {
    budget: { initial: budget.total, used: budget.used, remaining: budget.current },
    airbases,
    jammers: Array.from(deployedJammers.entries()).map(([index, position]) => {
      const unit = jammers[index];
      return {
        zoneName: unit.zoneName,
        name: unit.name,
        point: position,
        randomRadius: unit.randomRadius,
        radius: unit.radius,
      };
    }),
    missileSystems: Array.from(deployedMissileSystems.entries()).map(([key, deployment]) => ({
      key,
      unitname: deployment.unitName,
      category: deployment.category,
      center: deployment.center,
      openingAngle: deployment.openingAngle,
      tacticalAreas: deployment.tacticalAreas,
      paths: toExportPaths(deployment.paths),
    })),
  };
}
