import type { LandingUnitsData } from '@/types/unitStatus';
import { getLandingUnitImage } from '@/components/map';
import { ImageIcon } from '@/components/ImageIcon';
import { InfoCard } from '@pages/control-panel/components/shared/InfoCard';
import { TreeRow } from '@pages/control-panel/components/shared/TreeRow';

// ============================================================================
// LandingUnitsSection — landing areas on the left, their unit counts on the right
// ============================================================================
interface LandingUnitsSectionProps {
  landingUnits: LandingUnitsData;
}

export function LandingUnitsSection({ landingUnits }: LandingUnitsSectionProps) {
  const areas = Object.entries(landingUnits || {});

  if (areas.length === 0) {
    return (
      <div className="text-xs italic text-text-secondary">No landing units data available</div>
    );
  }

  return (
    <div className="space-y-4">
      {areas.map(([area, counts]) => {
        const unitTypes = Object.entries(counts || {});
        const total = unitTypes.reduce((sum, [, count]) => sum + count, 0);

        return (
          <TreeRow
            key={area}
            root={<InfoCard name={area} details={<div>LANDED: {total}</div>} />}
            leaves={unitTypes.map(([unitType, count]) => {
              const image = getLandingUnitImage(unitType);
              return {
                key: unitType,
                node: (
                  <InfoCard
                    name={unitType}
                    icon={image && <ImageIcon image={image} />}
                    details={<div>COUNT: {count}</div>}
                  />
                ),
              };
            })}
            emptyMessage="No unit types"
          />
        );
      })}
    </div>
  );
}
