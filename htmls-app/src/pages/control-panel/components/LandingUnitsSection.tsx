import type { LandingUnitsData } from '@/types/unitStatus';
import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/Map';
import { InfoCard } from './InfoCard';
import { TreeRow } from './TreeRow';

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
            root={
              <InfoCard
                name={area}
                icon={<ImageIcon image={ICON_IMAGES.suspectedC2} />}
                details={<div>LANDED: {total}</div>}
              />
            }
            leaves={unitTypes.map(([unitType, count]) => ({
              key: unitType,
              node: (
                <InfoCard
                  name={unitType}
                  icon={<ImageIcon image={ICON_IMAGES.suspectedC2} />}
                  details={<div>COUNT: {count}</div>}
                />
              ),
            }))}
            emptyMessage="No unit types"
          />
        );
      })}
    </div>
  );
}
