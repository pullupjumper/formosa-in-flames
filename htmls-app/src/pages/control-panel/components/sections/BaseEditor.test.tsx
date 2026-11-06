import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { AirbaseDeploymentDescriptor } from '@/types/generated';
import { BaseEditor } from './BaseEditor';

const BASE: AirbaseDeploymentDescriptor = {
  name: 'AB-1',
  embarkedUnits: [
    {
      side: 'Taiwan',
      type: 'Aircraft',
      platformName: 'F-16V',
      dbid: 1,
      loadouts: [{ loadoutId: 1, num: 4 }],
    },
  ],
  loadouts: [{ loadoutId: 2, name: 'AIM-120', num: 8 }],
};

function renderEditor(isReadOnly: boolean) {
  render(
    <BaseEditor
      base={BASE}
      baseline={BASE}
      baseIndex={0}
      budget={{ current: 100, used: 0, total: 100 }}
      onBudgetChange={() => {}}
      onUpdateAirbase={() => {}}
      onError={() => {}}
      isReadOnly={isReadOnly}
    />
  );
}

describe('BaseEditor', () => {
  it('shows step buttons while editable', () => {
    renderEditor(false);
    expect(screen.getAllByRole('button', { name: '+' })).toHaveLength(2);
  });

  it('read-only shows the quantities without step buttons', () => {
    renderEditor(true);
    expect(screen.queryAllByRole('button')).toHaveLength(0);
    expect(screen.getByText('F-16V')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
    expect(screen.getByText('8')).toBeInTheDocument();
  });
});
