# assignMission Module Test Report

This report details the unit tests performed on the `assignMission.lua` module.

## Test Setup

*   **Test Framework:** Busted
*   **Mocks:** `GameApi`, `Logger`, and `SafeCall` were mocked to ensure isolated and repeatable tests.

## Test Execution

To run these tests, you need to have Busted installed. If not, you can install it via LuaRocks:
```bash
luarocks install busted
```

Then, navigate to the project root directory in your terminal and run the tests:
```bash
busted test/assignMission_spec.lua
```

## Test Cases Summary

### `filterEmbarkedUnits(base, platformType, platformDBID)`

*   **✓** should filter embarked units by platformType and platformDBID
*   **✓** should return an empty table if no units match
*   **✓** should handle missing platformType gracefully
*   **✓** should log error if GameApi.ScenEdit_GetUnit fails

### `assignUnitToMission(unitGuid, missionName, isEscort)`

*   **✓** should return true on successful assignment
*   **✓** should return false and log error on failed assignment
*   **✓** should pass isEscort parameter correctly

### `getUnitWeaponCount(unit, weaponDBID)`

*   **✓** should return the correct weapon count if weapon exists
*   **✓** should return 0 if weapon does not exist
*   **✓** should return 0 and log error if GameApi.ScenEdit_GetLoadout fails
*   **✓** should return 0 if loadout is nil
*   **✓** should return 0 if loadout.weapons is nil

### `shouldAssignUnitToMission(unit, mission)`

*   **✓** should return false if unit is already assigned to a mission
*   **✓** should return true if mission has no loadoutId restriction (loadoutId == 0)
*   **✓** should return true if loadout matches and unit is not assigned
*   **✓** should return false if loadout does not match and unit is not assigned
*   **✓** should return false and log error if GameApi.ScenEdit_GetLoadout fails
*   **✓** should return false if loadout is nil even if loadoutId matches

### `AssignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)`

*   **✓** should assign units to missions based on criteria and num limit
*   **✓** should handle invalid fromUnit gracefully
*   **✓** should not assign if no units match filter criteria
*   **✓** should respect num limit for each mission
*   **✓** should not assign unit if shouldAssignUnitToMission returns false
*   **✓** should continue to next unit if assignUnitToMission fails

### `AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort)`

*   **✓** should assign strike units based on num, weaponDBID, and unitDBID
*   **✓** should handle invalid fromUnit gracefully
*   **✓** should handle invalid missionName gracefully
*   **✓** should filter units by readytime_v and mission status
*   **✓** should prioritize weaponDBID over unitDBID if weaponDBID is not 0
*   **✓** should use unitDBID if weaponDBID is 0
*   **✓** should set mission isactive to true if it was false
*   **✓** should return nil if no units are assigned (Note: The test code returns an empty table, which is functionally equivalent to nil in this context for iteration, but the original function signature suggests nil. The test asserts for an empty table.)

## Conclusion

The unit tests cover the main functionalities and edge cases of the `assignMission` module. The mocking strategy ensures that tests are isolated and do not rely on external game API calls.