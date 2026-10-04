import { describe, it, expect, afterEach } from 'vitest';
import { MOCK_ADD_UNIT_ACTIONS } from '@/data/addUnitsMenuData';
import { AIRBASES_DATA } from '@/data/controlPanelData';
import { UNIT_STATUS_DATA } from '@/data/unitStatusData';
import {
  readControlPanelPayload,
  submitDeployment,
  submitSelectedActions,
} from './controlPanelPayload';

const INJECT_KEYS = [
  '__INJECT_JAMMERS__',
  '__INJECT_AIRBASES__',
  '__INJECT_MISSILE_SYSTEMS__',
  '__INJECT_SIDE_NAME__',
  '__INJECT_ADD_UNIT_ACTIONS__',
  '__INJECT_AMPHIBIOUS_LOCATIONS__',
  '__INJECT_C2__',
  '__INJECT_SIGNALS__',
  '__INJECT_LAUNCHERS__',
  '__INJECT_LANDING_UNITS__',
  '__INJECT_IS_EDIT_MODE__',
  '__INJECT_IS_DEPLOY_LOCKED__',
] as const;

afterEach(() => {
  for (const key of INJECT_KEYS) delete window[key];
  document.body.innerHTML = '';
});

describe('readControlPanelPayload', () => {
  it('falls back to mock data and edit mode when nothing is injected', () => {
    const payload = readControlPanelPayload();

    expect(payload.sideName).toBe('Taiwan');
    expect(payload.mode).toEqual({ isEditMode: true, isDeployLocked: false });
    expect(payload.airbases).toBe(AIRBASES_DATA);
    expect(payload.c2Data).toBe(UNIT_STATUS_DATA.c2);
    expect(payload.addUnitActions).toBe(MOCK_ADD_UNIT_ACTIONS);
  });

  it('prefers injected values over mock data', () => {
    window.__INJECT_SIDE_NAME__ = 'China';
    window.__INJECT_IS_EDIT_MODE__ = 'false';
    window.__INJECT_IS_DEPLOY_LOCKED__ = 'true';
    window.__INJECT_ADD_UNIT_ACTIONS__ = '[{"id":"a","label":"A"}]';

    const payload = readControlPanelPayload();

    expect(payload.sideName).toBe('China');
    expect(payload.mode).toEqual({ isEditMode: false, isDeployLocked: true });
    expect(payload.addUnitActions).toEqual([{ id: 'a', label: 'A' }]);
  });
});

describe('host writes', () => {
  const addInput = (id: string) => {
    const input = document.createElement('input');
    input.id = id;
    document.body.appendChild(input);
    return input;
  };

  it('writes the selected actions as JSON', () => {
    const input = addInput('selectedActions');

    expect(submitSelectedActions({ actionIds: ['a'] })).toBe(true);
    expect(JSON.parse(input.value)).toEqual({ actionIds: ['a'] });
  });

  it('reports a deployment submit as failed unless both inputs exist', () => {
    addInput('summaryData');
    const result = { budget: {}, airbases: [], jammers: [], missileSystems: [] };

    expect(submitDeployment(result as never, { sams: [] } as never)).toBe(false);

    addInput('emconData');
    expect(submitDeployment(result as never, { sams: [] } as never)).toBe(true);
  });
});
