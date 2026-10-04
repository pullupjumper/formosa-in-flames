import { describe, it, expect } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { useActionSelection } from '@/pages/control-panel/hooks/useActionSelection';

const ACTIONS = [
  { id: 'a', label: 'A' },
  { id: 'b', label: 'B' },
  { id: 'c', label: 'C' },
];

describe('useActionSelection', () => {
  it('starts with nothing selected', () => {
    const { result } = renderHook(() => useActionSelection({ actions: ACTIONS }));
    expect(result.current.selectedIds).toEqual([]);
  });

  it('toggles one id on and off', () => {
    const { result } = renderHook(() => useActionSelection({ actions: ACTIONS }));
    act(() => result.current.toggle('b'));
    expect(result.current.selectedIds).toEqual(['b']);
    act(() => result.current.toggle('b'));
    expect(result.current.selectedIds).toEqual([]);
  });

  it('returns ids in action order, not click order', () => {
    const { result } = renderHook(() => useActionSelection({ actions: ACTIONS }));
    act(() => result.current.toggle('c'));
    act(() => result.current.toggle('a'));
    expect(result.current.selectedIds).toEqual(['a', 'c']);
  });

  it('toggleAll selects everything, then clears', () => {
    const { result } = renderHook(() => useActionSelection({ actions: ACTIONS }));
    act(() => result.current.toggleAll());
    expect(result.current.selectedIds).toEqual(['a', 'b', 'c']);
    act(() => result.current.toggleAll());
    expect(result.current.selectedIds).toEqual([]);
  });
});
