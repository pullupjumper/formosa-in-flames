local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local AirbaseAttrition = {}

-- ============================================================================
-- Public API
-- ============================================================================

---Calculate aggregated aircraft attrition across multiple configured airbases
---Aircraft count as combat-capable iff both they and their home base are alive; destroyed base zeroes the wing.
---@param deployments SBJ__AirbaseDeploymentDescriptor[] Airbase deployment descriptors
---@param baseNames string[] Airbase names to query (empty array yields a zero summary)
---@param side? string Side name to enumerate aircraft from (default: constants.SIDES.ENEMY)
---@return SBJ__AirbaseAttritionSummary # Per-base details and overall attrition summary
function AirbaseAttrition.calculate(deployments, baseNames, side)
  side = side or constants.SIDES.ENEMY

  -- Phase 1: Build lookup tables.
  -- descriptorByName: translate user-supplied baseName -> descriptor.
  -- baseAcc: GUID-keyed accumulator for aircraft attribution (stable identity).
  local descriptorByName = {}
  for _, descriptor in ipairs(deployments) do
    if descriptor.name then
      descriptorByName[descriptor.name] = descriptor
    end
  end

  ---@type SBJ__AirbaseAttritionSummary
  local summary = {
    queriedBaseNames = Utils.deepCopy(baseNames),
    expectedTotal = 0,
    currentTotal = 0,
    lossTotal = 0,
    attritionPct = 0,
    bases = {},
    missingBases = {}
  }

  ---@type table<string, table>
  local baseAcc = {}
  -- Preserve query order so summary.bases output is deterministic.
  local orderedGUIDs = {}

  for _, baseName in ipairs(baseNames) do
    local descriptor = descriptorByName[baseName]
    if not descriptor or not descriptor.baseGUID then
      table.insert(summary.missingBases, baseName)
    else
      local expectedByDBID = {}
      local expectedTotal = 0

      for _, group in ipairs(descriptor.embarkedUnits or {}) do
        local groupExpected = 0
        for _, loadout in ipairs(group.loadouts or {}) do
          groupExpected = groupExpected + (loadout.num or 0)
        end

        if group.dbid and groupExpected > 0 then
          expectedByDBID[group.dbid] = (expectedByDBID[group.dbid] or 0) + groupExpected
          expectedTotal = expectedTotal + groupExpected
        end
      end

      baseAcc[descriptor.baseGUID] = {
        baseName = baseName,
        baseGUID = descriptor.baseGUID,
        expectedByDBID = expectedByDBID,
        expectedTotal = expectedTotal,
        actualByDBID = {},
        currentTotal = 0,
        isDestroyed = false
      }
      table.insert(orderedGUIDs, descriptor.baseGUID)
    end
  end

  -- Phase 2: Detect destroyed airbases.
  -- A destroyed base means the wing is combat-incapable (no ground crew/runway/refuel),
  -- so currentTotal stays at 0 even if some of its aircraft are still airborne.
  for _, baseGUID in ipairs(orderedGUIDs) do
    local base = baseAcc[baseGUID]
    local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)
    if not baseUnit then
      base.isDestroyed = true
    end
  end

  -- Phase 3: Enumerate side-wide aircraft and attribute by aircraft.base.guid.
  -- This counts both grounded and airborne aircraft as long as their home base is alive.
  local sideObj = GameApi.VP_GetSide({ side = side })
  if sideObj then
    local aircraftList = sideObj:unitsBy(constants.UNIT_TYPES.AIRCRAFT) or {}
    for _, entry in ipairs(aircraftList) do
      local aircraft = GameApi.ScenEdit_GetUnit(entry.guid)
      if aircraft and aircraft.dbid and aircraft.base and aircraft.base.guid then
        local base = baseAcc[aircraft.base.guid]
        if base and not base.isDestroyed and base.expectedByDBID[aircraft.dbid] then
          base.actualByDBID[aircraft.dbid] = (base.actualByDBID[aircraft.dbid] or 0) + 1
          base.currentTotal = base.currentTotal + 1
        end
      end
    end
  end

  -- Phase 4: Per-base settlement and aggregate.
  for _, baseGUID in ipairs(orderedGUIDs) do
    local base = baseAcc[baseGUID]
    local lossTotal = math.max(base.expectedTotal - base.currentTotal, 0)
    local attritionPct = 0
    if base.expectedTotal > 0 then
      attritionPct = (lossTotal / base.expectedTotal) * 100
    end

    local details = {}
    for dbid, expected in pairs(base.expectedByDBID) do
      local current = base.actualByDBID[dbid] or 0
      table.insert(details, {
        dbid = dbid,
        expected = expected,
        current = current,
        loss = math.max(expected - current, 0)
      })
    end
    table.sort(details, function(a, b) return a.dbid < b.dbid end)

    table.insert(summary.bases, {
      baseName = base.baseName,
      baseGUID = base.baseGUID,
      expectedTotal = base.expectedTotal,
      currentTotal = base.currentTotal,
      lossTotal = lossTotal,
      attritionPct = attritionPct,
      isDestroyed = base.isDestroyed,
      details = details
    })

    summary.expectedTotal = summary.expectedTotal + base.expectedTotal
    summary.currentTotal = summary.currentTotal + base.currentTotal
    summary.lossTotal = summary.lossTotal + lossTotal
  end

  if summary.expectedTotal > 0 then
    summary.attritionPct = (summary.lossTotal / summary.expectedTotal) * 100
  end

  return summary
end

return AirbaseAttrition
