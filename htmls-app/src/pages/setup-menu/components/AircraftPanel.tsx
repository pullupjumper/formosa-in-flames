import type { Airbase, BudgetState } from '@/types/setupMenu';
import { CONFIG } from '@/constants/setupMenu';
import { settleQuantityChange } from '@/utils/budgetLedger';

// ============================================================================
// AircraftPanel — sidebar panel for loadout budget and per-base editing
// ============================================================================
interface AircraftPanelProps {
  airbases: Airbase[];
  /**
   * Untouched injected airbases. Quantities present at scenario load were never
   * charged, so they are the floor: only the part above them moves budget.
   */
  baselineAirbases: Airbase[];
  budget: BudgetState;
  selectedBaseIndex: number | null;
  onBudgetChange: (next: BudgetState) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
  /** Routed to the shared status line instead of a modal alert */
  onError: (message: string) => void;
}

export function AircraftPanel({
  airbases,
  baselineAirbases,
  budget,
  selectedBaseIndex,
  onBudgetChange,
  onUpdateAirbase,
  onError,
}: AircraftPanelProps) {
  const percentage = (budget.current / budget.total) * 100;
  const selectedBase = selectedBaseIndex !== null ? airbases[selectedBaseIndex] : null;

  return (
    <>
      {/* Budget Section */}
      <div className="mb-5 border-b border-dark-border pb-4">
        <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
          Loadout Budget
        </div>
        <div className="mb-2">
          <div className="mb-2 text-xs font-semibold">Remaining Budget</div>
          <div
            className={`mb-1 text-2xl font-bold ${
              budget.current < 200
                ? 'text-status-danger'
                : budget.current < 400
                  ? 'text-status-warning'
                  : 'text-status-success'
            }`}
          >
            {budget.current}
          </div>
          <div className="text-[11px] text-text-secondary">
            Used: {budget.used} / Total: {budget.total}
          </div>
          <div className="mt-2 h-1 rounded-sm bg-dark-border">
            <div
              className={`h-full rounded-sm transition-[width] duration-300 ${
                budget.current < 200
                  ? 'bg-status-danger'
                  : budget.current < 400
                    ? 'bg-status-warning'
                    : 'bg-status-success'
              }`}
              style={{ width: `${percentage}%` }}
            />
          </div>
        </div>
      </div>

      {/* Base Editor Section */}
      <div className="mb-5">
        <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
          Base Editor
        </div>
        {selectedBase ? (
          <BaseEditor
            base={selectedBase}
            baseline={baselineAirbases[selectedBaseIndex!]}
            baseIndex={selectedBaseIndex!}
            budget={budget}
            onBudgetChange={onBudgetChange}
            onUpdateAirbase={onUpdateAirbase}
            onError={onError}
          />
        ) : (
          <div className="text-xs italic text-text-secondary">
            Select an airbase on the map to edit loadouts
          </div>
        )}
      </div>
    </>
  );
}

// ============================================================================
// BaseEditor
// ============================================================================
interface BaseEditorProps {
  base: Airbase;
  /** Same base as injected, before any player edits */
  baseline: Airbase | undefined;
  baseIndex: number;
  budget: BudgetState;
  onBudgetChange: (next: BudgetState) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
  onError: (message: string) => void;
}

function BaseEditor({
  base,
  baseline,
  baseIndex,
  budget,
  onBudgetChange,
  onUpdateAirbase,
  onError,
}: BaseEditorProps) {
  /** Apply the ledger rule; false when the player cannot afford the increment. */
  const settleBudget = (newNum: number, baselineNum: number, delta: number): boolean => {
    const result = settleQuantityChange(budget, {
      newNum,
      baselineNum,
      delta,
      cost: CONFIG.LOADOUT_COST,
    });
    if (!result.ok) {
      onError('Warning: Insufficient budget');
      return false;
    }
    if (result.next !== budget) onBudgetChange(result.next);
    return true;
  };

  const adjustAircraft = (unitIndex: number, delta: number) => {
    const unit = base.embarkedUnits?.[unitIndex];
    if (!unit?.loadouts?.[0]) return;

    const newNum = unit.loadouts[0].num + delta;
    if (newNum < 0) return;

    const baselineNum = baseline?.embarkedUnits?.[unitIndex]?.loadouts?.[0]?.num ?? 0;
    if (!settleBudget(newNum, baselineNum, delta)) return;

    onUpdateAirbase(baseIndex, (prev) => ({
      ...prev,
      embarkedUnits: prev.embarkedUnits?.map((unit, index) =>
        index === unitIndex
          ? {
              ...unit,
              loadouts: unit.loadouts?.map((loadout, loadoutIndex) =>
                loadoutIndex === 0 ? { ...loadout, num: newNum } : loadout
              ),
            }
          : unit
      ),
    }));
  };

  const adjustLoadout = (loadoutIndex: number, delta: number) => {
    const loadout = base.loadouts?.[loadoutIndex];
    if (!loadout) return;

    const newNum = loadout.num + delta;
    if (newNum < 0) return;

    const baselineNum = baseline?.loadouts?.[loadoutIndex]?.num ?? 0;
    if (!settleBudget(newNum, baselineNum, delta)) return;

    onUpdateAirbase(baseIndex, (prev) => ({
      ...prev,
      loadouts: prev.loadouts?.map((loadout, index) =>
        index === loadoutIndex ? { ...loadout, num: newNum } : loadout
      ),
    }));
  };

  return (
    <div>
      <div className="mb-2.5 font-bold">{base.name}</div>

      {/* Deployed Aircraft */}
      {base.embarkedUnits && base.embarkedUnits.length > 0 && (
        <div className="mb-4">
          <div className="mb-2 text-[11px] text-text-secondary">DEPLOYED AIRCRAFT</div>
          {base.embarkedUnits.map((unit, unitIndex) => {
            const total = unit.loadouts?.reduce((sum, loadout) => sum + loadout.num, 0) || 0;
            return (
              <LoadoutControl
                key={unitIndex}
                name={unit.platformName}
                subtitle={unit.name}
                quantity={total}
                onDecrease={() => adjustAircraft(unitIndex, -1)}
                onIncrease={() => adjustAircraft(unitIndex, 1)}
              />
            );
          })}
        </div>
      )}

      {/* Base Ammunition Storage */}
      {base.loadouts && base.loadouts.length > 0 && (
        <div>
          <div className="mb-2 text-[11px] text-text-secondary">BASE AMMUNITION STORAGE</div>
          {base.loadouts.map((loadout, loadoutIndex) => (
            <LoadoutControl
              key={loadoutIndex}
              name={loadout.name || `Loadout ${loadout.loadoutId}`}
              subtitle={`Cost: ${CONFIG.LOADOUT_COST}`}
              quantity={loadout.num}
              onDecrease={() => adjustLoadout(loadoutIndex, -1)}
              onIncrease={() => adjustLoadout(loadoutIndex, 1)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ============================================================================
// LoadoutControl
// ============================================================================
interface LoadoutControlProps {
  name: string;
  subtitle: string;
  quantity: number;
  onDecrease: () => void;
  onIncrease: () => void;
}

function LoadoutControl({ name, subtitle, quantity, onDecrease, onIncrease }: LoadoutControlProps) {
  return (
    <div className="mb-2 flex items-center justify-between border-b border-white/5 py-1">
      <div className="flex-1">
        <div className="text-xs font-semibold">{name}</div>
        <div className="text-[10px] text-text-secondary">{subtitle}</div>
      </div>
      <div className="flex items-center gap-1.5">
        <button
          className="flex h-6 w-6 items-center justify-center rounded-sm border border-dark-border bg-dark-hover font-bold hover:border-accent-blue hover:bg-accent-blue"
          onClick={onDecrease}
        >
          -
        </button>
        <div className="min-w-5 text-center text-xs font-semibold">{quantity}</div>
        <button
          className="flex h-6 w-6 items-center justify-center rounded-sm border border-dark-border bg-dark-hover font-bold hover:border-accent-blue hover:bg-accent-blue"
          onClick={onIncrease}
        >
          +
        </button>
      </div>
    </div>
  );
}
