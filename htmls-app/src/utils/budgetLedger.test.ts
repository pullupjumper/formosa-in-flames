import { describe, it, expect } from 'vitest';
import { createBudgetState, spend, refund, settleQuantityChange } from '@/utils/budgetLedger';

describe('budgetLedger', () => {
  const start = createBudgetState(1000);

  it('starts with nothing used', () => {
    expect(start).toEqual({ current: 1000, used: 0, total: 1000 });
  });

  it('spend moves amount from current to used', () => {
    const result = spend(start, 300);
    expect(result.ok).toBe(true);
    expect(result.next).toEqual({ current: 700, used: 300, total: 1000 });
  });

  it('spend refuses when short and leaves state untouched', () => {
    const result = spend(start, 1001);
    expect(result.ok).toBe(false);
    expect(result.next).toBe(start);
  });

  it('refund reverses spend', () => {
    const spent = spend(start, 300).next;
    expect(refund(spent, 300)).toEqual(start);
  });

  describe('settleQuantityChange', () => {
    const cost = 100;

    it('charges when going above the baseline', () => {
      const result = settleQuantityChange(start, { newNum: 3, baselineNum: 2, delta: 1, cost });
      expect(result.ok).toBe(true);
      expect(result.next.used).toBe(cost);
    });

    it('is free while still at or below the baseline going up', () => {
      const result = settleQuantityChange(start, { newNum: 2, baselineNum: 2, delta: 1, cost });
      expect(result.ok).toBe(true);
      expect(result.next).toBe(start);
    });

    it('refunds when coming back down to the baseline or above it', () => {
      const spent = spend(start, cost).next;
      const result = settleQuantityChange(spent, { newNum: 2, baselineNum: 2, delta: -1, cost });
      expect(result.next).toEqual(start);
    });

    it('does not refund below the baseline', () => {
      const result = settleQuantityChange(start, { newNum: 1, baselineNum: 2, delta: -1, cost });
      expect(result.next).toBe(start);
    });

    it('fails when the player cannot afford the increment', () => {
      const broke = createBudgetState(50);
      const result = settleQuantityChange(broke, { newNum: 1, baselineNum: 0, delta: 1, cost });
      expect(result.ok).toBe(false);
      expect(result.next).toBe(broke);
    });
  });
});
