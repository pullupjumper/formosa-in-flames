import type { BudgetState } from '@/types/setupMenu';

/**
 * Pure loadout-budget rules. The page owns one `BudgetState`; every change goes
 * through here and returns the next state instead of mutating anything.
 */

export function createBudgetState(initial: number): BudgetState {
  return { current: initial, used: 0, total: initial };
}

export type SpendResult = { ok: true; next: BudgetState } | { ok: false; next: BudgetState };

export function spend(state: BudgetState, amount: number): SpendResult {
  if (state.current < amount) return { ok: false, next: state };
  return {
    ok: true,
    next: { ...state, current: state.current - amount, used: state.used + amount },
  };
}

export function refund(state: BudgetState, amount: number): BudgetState {
  return { ...state, current: state.current + amount, used: state.used - amount };
}

export interface QuantityChangeParams {
  /** Quantity after the +/-1 click */
  newNum: number;
  /** Quantity that shipped with the scenario and was never paid for */
  baselineNum: number;
  /** +1 or -1 */
  delta: number;
  cost: number;
}

/**
 * Budget movement for a +/-1 quantity change. Stock up to `baselineNum` is
 * free, so only the part above the baseline is charged on the way up and
 * refunded on the way down. `ok: false` means the player cannot afford it.
 */
export function settleQuantityChange(
  state: BudgetState,
  { newNum, baselineNum, delta, cost }: QuantityChangeParams
): SpendResult {
  if (delta > 0 && newNum > baselineNum) return spend(state, cost);
  if (delta < 0 && newNum >= baselineNum) return { ok: true, next: refund(state, cost) };
  return { ok: true, next: state };
}
