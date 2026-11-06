import type { AirbaseDeploymentDescriptor } from '@/types/generated';
import type { BudgetState } from '@/pages/control-panel/logic/budgetLedger';
import { CONFIG } from '@/constants/controlPanel';
import { settleQuantityChange } from '@/pages/control-panel/logic/budgetLedger';

// ============================================================================
// BaseEditor
// ============================================================================
interface BaseEditorProps {
  base: AirbaseDeploymentDescriptor;
  /** Same base as injected, before any player edits */
  baseline: AirbaseDeploymentDescriptor | undefined;
  baseIndex: number;
  budget: BudgetState;
  onBudgetChange: (next: BudgetState) => void;
  onUpdateAirbase: (
    index: number,
    updater: (base: AirbaseDeploymentDescriptor) => AirbaseDeploymentDescriptor
  ) => void;
  onError: (message: string) => void;
  /** Quantities show but can no longer be changed */
  isReadOnly?: boolean;
}

export function BaseEditor({
  base,
  baseline,
  baseIndex,
  budget,
  onBudgetChange,
  onUpdateAirbase,
  onError,
  isReadOnly = false,
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
                isReadOnly={isReadOnly}
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
              isReadOnly={isReadOnly}
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
  subtitle?: string;
  quantity: number;
  /** Hides the step buttons, leaving the quantity */
  isReadOnly: boolean;
  onDecrease: () => void;
  onIncrease: () => void;
}

const STEP_BUTTON_CLASSES =
  'border-aip-card-border bg-aip-panel hover:border-aip-link hover:bg-aip-link';

function LoadoutControl({
  name,
  subtitle,
  quantity,
  isReadOnly,
  onDecrease,
  onIncrease,
}: LoadoutControlProps) {
  const stepButton = `flex h-6 w-6 items-center justify-center border font-bold ${STEP_BUTTON_CLASSES}`;
  return (
    <div className="mb-2 flex items-center justify-between border-b border-aip-card-border/50 py-1">
      <div className="flex-1">
        <div className="text-xs font-semibold">{name}</div>
        <div className="text-[10px] text-text-secondary">{subtitle}</div>
      </div>
      <div className="flex items-center gap-1.5">
        {!isReadOnly && (
          <button className={stepButton} onClick={onDecrease}>
            -
          </button>
        )}
        <div className="min-w-5 text-center text-xs font-semibold">{quantity}</div>
        {!isReadOnly && (
          <button className={stepButton} onClick={onIncrease}>
            +
          </button>
        )}
      </div>
    </div>
  );
}
