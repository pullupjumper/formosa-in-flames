/** One `addXXX` option the side can run. */
export interface AddUnitAction {
  id: string;
  label: string;
}

/** Root payload injected by `addUnitsMenu.lua`. */
export interface AddUnitsMenuData {
  sideName: string;
  actions: AddUnitAction[];
}

/** What `selectedActions` sends back to `addUnitsMenu.lua`. */
export interface AddUnitsMenuResult {
  actionIds: string[];
}
