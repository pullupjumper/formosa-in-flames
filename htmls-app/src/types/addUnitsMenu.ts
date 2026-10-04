/** One `addXXX` option the side can run. */
export interface AddUnitAction {
  id: string;
  label: string;
}

/** What `selectedActions` sends back to `addUnitsMenu.lua`. */
export interface AddUnitsMenuResult {
  actionIds: string[];
}
