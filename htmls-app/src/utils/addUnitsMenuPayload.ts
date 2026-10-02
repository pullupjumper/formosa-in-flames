import type { AddUnitsMenuData } from '@/types/addUnitsMenu';
import { MOCK_ADD_UNIT_ACTIONS } from '@/data/addUnitsMenuData';
import { parseInjectedJSON, readInjectedString } from '@/utils/inject';

declare global {
  interface Window {
    __INJECT_ADD_UNIT_ACTIONS__?: string;
    __INJECT_SIDE_NAME__?: string;
  }
}

/** Read the add-units menu payload Lua injected, falling back to mock data. */
export function readAddUnitsMenuData(): AddUnitsMenuData {
  return {
    sideName: readInjectedString(window.__INJECT_SIDE_NAME__, 'Taiwan'),
    actions: parseInjectedJSON(
      window.__INJECT_ADD_UNIT_ACTIONS__,
      MOCK_ADD_UNIT_ACTIONS,
      'ADD_UNIT_ACTIONS'
    ),
  };
}
