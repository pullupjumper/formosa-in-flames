/**
 * SAM systems the WCS doctrine applies to. Ids are the menu ids `unitStatusUI.lua`
 * maps to platform DBIDs (`BLUE_SAM_DBIDS_BY_MENU_ID`), so they must not change.
 */
export const SAM_DOCTRINE_SYSTEMS = [
  { id: 'pac23', label: 'Pac-2/3' },
  { id: 'skybow3', label: 'Sky Bow-3' },
  { id: 'tc2', label: 'TC-2' },
] as const;
