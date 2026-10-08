import type { Airbase, BudgetState } from '@/types/controlPanel';
import { AIRBASE_ICON_URL, AIRBASE_ICON_SIZE } from '@/components/map';
import { BaseEditor } from '@pages/control-panel/components/sections/BaseEditor';

// ============================================================================
// AircraftBasesSection — budget plus one loadout card per airbase
// ============================================================================
interface AircraftBasesSectionProps {
  airbases: Airbase[];
  /** Untouched injected airbases, used as the budget floor. See BaseEditor. */
  baselineAirbases: Airbase[];
  budget: BudgetState;
  onBudgetChange: (next: BudgetState) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
  onError: (message: string) => void;
}

export function AircraftBasesSection({
  airbases,
  baselineAirbases,
  budget,
  onBudgetChange,
  onUpdateAirbase,
  onError,
}: AircraftBasesSectionProps) {
  return (
    <div>
      <BudgetMeter budget={budget} />

      {airbases.length === 0 ? (
        <div className="text-xs italic text-text-secondary">No airbases available</div>
      ) : (
        <div className="space-y-2">
          {airbases.map((base, index) => (
            <div
              key={base.baseGUID}
              className="rounded-xs border-2 border-aip-card-border bg-aip-card p-2.5 text-xs"
            >
              <div className="mb-2 flex items-center gap-2.5">
                <img
                  src={AIRBASE_ICON_URL}
                  alt="Airbase"
                  width={AIRBASE_ICON_SIZE.width * 1.4}
                  height={AIRBASE_ICON_SIZE.height * 1.4}
                  className="shrink-0 object-contain"
                />
                <div className="text-[13px] text-text-primary">{base.name}</div>
              </div>
              <BaseEditor
                base={base}
                baseline={baselineAirbases[index]}
                baseIndex={index}
                budget={budget}
                onBudgetChange={onBudgetChange}
                onUpdateAirbase={onUpdateAirbase}
                onError={onError}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ============================================================================
// BudgetMeter — remaining budget at a glance
// ============================================================================
function budgetTone(current: number): { text: string; bar: string } {
  if (current < 200) return { text: 'text-status-danger', bar: 'bg-status-danger' };
  if (current < 400) return { text: 'text-status-warning', bar: 'bg-status-warning' };
  return { text: 'text-status-success', bar: 'bg-status-success' };
}

function BudgetMeter({ budget }: { budget: BudgetState }) {
  const tone = budgetTone(budget.current);
  const percentage = budget.total > 0 ? Math.min(100, (budget.current / budget.total) * 100) : 0;

  return (
    <div className="mb-3 rounded-xs border-2 border-aip-card-border bg-aip-card p-3">
      <div className="flex items-baseline justify-between">
        <span className="text-[11px] font-bold uppercase tracking-wide text-text-secondary">
          Loadout Budget
        </span>
        <span className="text-[11px] text-text-secondary">Used {budget.used}</span>
      </div>
      <div className="mt-1 flex items-baseline gap-1.5">
        <span className={`text-2xl font-bold leading-none ${tone.text}`}>{budget.current}</span>
        <span className="text-xs text-text-secondary">/ {budget.total}</span>
      </div>
      <div className="mt-2.5 h-1.5 overflow-hidden bg-aip-pane">
        <div
          className={`h-full transition-[width] duration-300 ${tone.bar}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
}
