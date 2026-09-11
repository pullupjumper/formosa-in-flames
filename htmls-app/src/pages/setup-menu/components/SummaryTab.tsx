import type { Coordinate } from '@/types/geo';
import type {
  BudgetState,
  Airbase,
  Jammer,
  MissileSystems,
  MissileDeployment,
  MovementPaths,
} from '@/types/setupMenu';
import { getWeaponSystemName } from '@/utils/map';

// ============================================================================
// EXPORT HELPERS
// ============================================================================
function trimLeadingWaypoint(waypoints: Coordinate[]): Coordinate[] {
  return waypoints.length > 1 ? waypoints.slice(1) : waypoints;
}

function normalizeExportPaths(paths: MovementPaths): MovementPaths {
  return {
    // FP paths start at the shared gateway (not the vehicle's position);
    // the gateway is an intermediate waypoint every shelter must pass through
    // to stay clear of HA/RL, so keep the full waypoint list intact.
    FP: paths.FP.map((path) => ({ ...path })),
    HA: {
      ...paths.HA,
      waypoints: trimLeadingWaypoint(paths.HA.waypoints),
    },
    RL: paths.RL.map((path) => ({
      ...path,
      waypoints: trimLeadingWaypoint(path.waypoints),
    })),
    AHA: {
      ...paths.AHA,
      waypoints: trimLeadingWaypoint(paths.AHA.waypoints),
    },
    // SHRL follows the same model as FP: gateway is a real waypoint, not origin.
    SHRL: { ...paths.SHRL },
  };
}

function formatPosition(position: Coordinate): string {
  return `${position.latitude.toFixed(6)}, ${position.longitude.toFixed(6)}`;
}

// ============================================================================
// TYPES
// ============================================================================
interface CountedItem {
  name: string;
  count: number;
}

interface BaseStats {
  name: string;
  aircraft: number;
  loadouts: number;
  aircraftDetails: CountedItem[];
  loadoutDetails: CountedItem[];
}

interface SummaryTabProps {
  budget: BudgetState;
  airbases: Airbase[];
  jammers: Jammer[];
  missileSystems: MissileSystems;
  deployedJammers: Map<number, Coordinate>;
  deployedMissileSystems: Map<string, MissileDeployment>;
}

// ============================================================================
// MAIN COMPONENT
// ============================================================================
export function SummaryTab({
  budget,
  airbases,
  jammers,
  missileSystems,
  deployedJammers,
  deployedMissileSystems,
}: SummaryTabProps) {
  const usagePercent = ((budget.used / budget.total) * 100).toFixed(1);

  // Calculate totals and base stats
  let totalAircraft = 0;
  let totalLoadouts = 0;
  const baseStats: BaseStats[] = [];

  airbases.forEach((base) => {
    let baseAircraft = 0;
    let baseLoadouts = 0;
    const aircraftDetails: CountedItem[] = [];
    const loadoutDetails: CountedItem[] = [];

    base.embarkedUnits?.forEach((unit) => {
      const count = unit.loadouts?.reduce((sum, loadout) => sum + loadout.num, 0) || 0;
      if (count > 0) {
        aircraftDetails.push({ name: unit.platformName, count });
        baseAircraft += count;
        totalAircraft += count;
      }
    });

    base.loadouts?.forEach((loadout) => {
      if (loadout.num > 0) {
        loadoutDetails.push({
          name: loadout.name || `Loadout ${loadout.loadoutId}`,
          count: loadout.num,
        });
        baseLoadouts += loadout.num;
        totalLoadouts += loadout.num;
      }
    });

    if (baseAircraft > 0 || baseLoadouts > 0) {
      baseStats.push({
        name: base.name,
        aircraft: baseAircraft,
        loadouts: baseLoadouts,
        aircraftDetails,
        loadoutDetails,
      });
    }
  });

  // Calculate missile system totals
  const totalMissileUnits = Object.values(missileSystems).reduce(
    (sum, category) => sum + (category.firingUnits ? Object.keys(category.firingUnits).length : 0),
    0
  );

  const handleExport = () => {
    const exportData = {
      budget: {
        initial: budget.total,
        used: budget.used,
        remaining: budget.current,
      },
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
      missileSystems: Array.from(deployedMissileSystems.entries()).map(([key, data]) => ({
        key,
        unitname: data.unitName,
        category: data.category,
        center: data.center,
        openingAngle: data.openingAngle,
        tacticalAreas: data.tacticalAreas,
        paths: normalizeExportPaths(data.paths),
      })),
    };
    const jsonString = JSON.stringify(exportData, null, 2);
    const summaryInput = document.getElementById('summaryData') as HTMLInputElement | null;
    if (summaryInput) {
      summaryInput.value = jsonString;
    }
    console.log('Export data:', exportData);
    alert('Configuration exported to console');
  };

  return (
    <div className="mx-auto h-full max-w-300 overflow-y-auto p-8">
      {/* Budget Overview */}
      <SummarySection title="Budget Overview">
        <SummaryItem label="Total Budget" value={budget.total.toString()} />
        <SummaryItem label="Used Budget" value={budget.used.toString()} />
        <SummaryItem label="Remaining Budget" value={budget.current.toString()} />
        <SummaryItem label="Usage" value={`${usagePercent}%`} />
      </SummarySection>

      {/* Aircraft & Loadouts Summary */}
      <SummarySection title="Aircraft & Loadouts Summary">
        <SummaryItem label="Total Aircraft" value={totalAircraft.toString()} />
        <SummaryItem label="Total Ammunition" value={totalLoadouts.toString()} />
      </SummarySection>

      {/* Base Breakdown */}
      {baseStats.length > 0 && (
        <SummarySection title="Base Breakdown">
          <div className="grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-5">
            {baseStats.map((stat) => (
              <BaseCard key={stat.name} stat={stat} />
            ))}
          </div>
        </SummarySection>
      )}

      {/* GPS Jammers */}
      <SummarySection title="GPS Jammers">
        <SummaryItem label="Deployed Units" value={`${deployedJammers.size} / ${jammers.length}`} />
        {Array.from(deployedJammers.entries()).map(([index, position]) => {
          const unit = jammers[index];
          return (
            <DeployedUnitCard key={index}>
              <div className="mb-1.5 font-semibold text-white">{unit.name}</div>
              <div className="text-xs text-text-secondary">
                Location: {formatPosition(position)}
              </div>
              <div className="text-xs text-status-danger">Range: {unit.radius} NM</div>
            </DeployedUnitCard>
          );
        })}
      </SummarySection>

      {/* Missile Systems */}
      <SummarySection title="Missile Systems">
        <SummaryItem
          label="Deployed Units"
          value={`${deployedMissileSystems.size} / ${totalMissileUnits}`}
        />
        {Array.from(deployedMissileSystems.entries()).map(([unitKey, deployment]) => {
          const systemType = getWeaponSystemName(deployment.category);
          return (
            <DeployedUnitCard key={unitKey}>
              <div className="mb-1.5 font-semibold text-white">{deployment.unitName}</div>
              <div className="mb-1 text-[11px] text-purple-400">{systemType}</div>
              <div className="text-xs text-text-secondary">
                Center: {formatPosition(deployment.center)}
              </div>
              <div className="text-xs text-text-secondary">Angle: {deployment.openingAngle}°</div>
            </DeployedUnitCard>
          );
        })}
      </SummarySection>

      {/* Export Button */}
      <button
        className="w-full rounded-sm bg-accent-blue px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-white transition-colors hover:bg-accent-blue-hover"
        onClick={handleExport}
      >
        Submit Configuration
      </button>
    </div>
  );
}

// ============================================================================
// SUB-COMPONENTS
// ============================================================================
interface SummarySectionProps {
  title: string;
  children: React.ReactNode;
}

function SummarySection({ title, children }: SummarySectionProps) {
  return (
    <div className="mb-5 rounded-sm border border-dark-border bg-dark-panel p-5">
      <div className="mb-5 border-b border-dark-border pb-2.5 text-base font-semibold">{title}</div>
      {children}
    </div>
  );
}

interface SummaryItemProps {
  label: string;
  value: string;
}

function SummaryItem({ label, value }: SummaryItemProps) {
  return (
    <div className="flex justify-between border-b border-dark-border py-2.5 text-[13px]">
      <span className="text-text-secondary">{label}</span>
      <span className="font-semibold text-text-primary">{value}</span>
    </div>
  );
}

interface BaseCardProps {
  stat: BaseStats;
}

function BaseCard({ stat }: BaseCardProps) {
  return (
    <div className="rounded-sm border border-dark-border bg-[#182026] p-4">
      <div className="mb-2.5 text-sm font-bold text-accent-blue">{stat.name}</div>

      {stat.aircraftDetails.length > 0 && (
        <div className="mt-2 border-t border-white/10 pt-2">
          <div className="mb-1.5 text-[11px] text-text-secondary">AIRCRAFT</div>
          {stat.aircraftDetails.map((detail) => (
            <div
              key={detail.name}
              className="flex justify-between border-b border-white/5 py-1 text-xs last:border-b-0"
            >
              <span>{detail.name}</span>
              <span>x {detail.count}</span>
            </div>
          ))}
        </div>
      )}

      {stat.loadoutDetails.length > 0 && (
        <div className="mt-2 border-t border-white/10 pt-2">
          <div className="mb-1.5 text-[11px] text-text-secondary">AMMUNITION</div>
          {stat.loadoutDetails.map((detail) => (
            <div
              key={detail.name}
              className="flex justify-between border-b border-white/5 py-1 text-xs last:border-b-0"
            >
              <span>{detail.name}</span>
              <span>x {detail.count}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

interface DeployedUnitCardProps {
  children: React.ReactNode;
}

function DeployedUnitCard({ children }: DeployedUnitCardProps) {
  return <div className="mt-3 rounded border border-dark-border bg-black/30 p-3">{children}</div>;
}
