import type { AddUnitOption } from '@/types/generated';
import { useState, useCallback } from 'react';

export interface UseActionSelectionParams {
  actions: AddUnitOption[];
}

/** Checked action ids, always returned in the order of `actions`. */
export function useActionSelection({ actions }: UseActionSelectionParams) {
  const [checked, setChecked] = useState<ReadonlySet<string>>(new Set());

  const toggle = useCallback((id: string) => {
    setChecked((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  }, []);

  const toggleAll = useCallback(() => {
    setChecked((prev) =>
      prev.size === actions.length ? new Set() : new Set(actions.map((action) => action.id))
    );
  }, [actions]);

  const selectedIds = actions.filter((action) => checked.has(action.id)).map((action) => action.id);

  return { checked, selectedIds, toggle, toggleAll };
}
