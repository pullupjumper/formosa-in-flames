local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")

local IADS = {}

--- Sets units of specified type to out-of-communications state
--- When a C2 node is destroyed, this function disables all radars or SAMs under its control
--- by setting their communication status to offline
--- @param C2Context SBJ__C2Context The C2 context containing the units to disable
--- @param type string Unit type to disable ('radar' or 'SAM')
local function disableUnitsUnderC2Node(C2Context, type)
  for _, data in pairs(C2Context[type]) do
    local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

    if actualUnit == nil then goto continue end
    GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
    data.isOutOfComms = true

    ::continue::
  end
end

--- Disrupts command and control communications
--- When a C2 node is destroyed, this function automatically checks all C2 types
--- (C2, ROCC, TAAOC) and disables associated radars and SAMs
--- @param IADSContext SBJ__IADSContext IADS context containing C2 nodes
--- @param C2 CMO__Unit The destroyed command and control node unit
function IADS.processC2Disruption(IADSContext, C2)
  -- Check China C2 nodes
  if IADSContext.C2 and IADSContext.C2[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.C2[C2.guid], 'radar')
    disableUnitsUnderC2Node(IADSContext.C2[C2.guid], 'SAM')
    IADSContext.C2[C2.guid] = nil
    Logger.log(C2.name .. '\'s C2 is destroyed')
  end

  -- Check Taiwan ROCC nodes
  if IADSContext.ROCC and IADSContext.ROCC[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.ROCC[C2.guid], 'radar')
    disableUnitsUnderC2Node(IADSContext.ROCC[C2.guid], 'SAM')
    IADSContext.ROCC[C2.guid] = nil
    Logger.log(C2.name .. '\'s ROCC is destroyed')
  end

  -- Check Taiwan TAAOC nodes
  if IADSContext.TAAOC and IADSContext.TAAOC[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.TAAOC[C2.guid], 'SAM')
    IADSContext.TAAOC[C2.guid] = nil
    Logger.log(C2.name .. '\'s TAAOC is destroyed')
  end
end

--- Clears data for destroyed units
--- Removes destroyed radars or SAMs from air defense system data structure
--- Iterates through all C2 nodes to find which one was managing the destroyed unit
--- and removes it from that C2 node's inventory
--- @param C2TypeContext table<string, SBJ__C2Context> C2 type context (e.g., IADSContext.C2, IADSContext.ROCC, or IADSContext.TAAOC)
--- @param type string Unit type ('radar' or 'SAM')
--- @param destroyedUnit CMO__Unit The destroyed radar or SAM unit to remove from tracking
function IADS.removeDestroyedUnitContextFromIADS(C2TypeContext, type, destroyedUnit)
  -- Iterate through all C2 nodes to check if destroyed unit is within their coverage areas
  for _, ctx in pairs(C2TypeContext) do
    for _, area in pairs(ctx.areas) do
      if destroyedUnit:inArea(area) and C2TypeContext[ctx.guid] then
        C2TypeContext[ctx.guid][type][destroyedUnit.guid] = nil
        Logger.log(destroyedUnit.name .. '\'s ' .. type .. ' is destroyed')
      end
    end
  end
end

--- Activates backup radar
--- When a radar is destroyed, automatically activates the nearest backup radar to maintain air defense coverage
--- Search priority: 1) Dedicated radars (JY-26, YLC-8B), 2) SAM system radars (HQ-22, S-300, S-400, HQ-12)
--- @param config SBJ__CONFIG Configuration parameters containing platform DBIDs and radar distance threshold
--- @param sideUnits CMO__SideUnit[] Array of available radar units to search through for potential backups
--- @param destroyedRadar CMO__Unit The destroyed radar whose position is used as reference point for finding nearest backup
function IADS.activateNearestRadar(config, sideUnits, destroyedRadar)
  local temp = { unit = nil, distance = config.radarDistance }

  local latitude = destroyedRadar.latitude
  local longitude = destroyedRadar.longitude

  -- First priority: Search for dedicated radars (JY-26, YLC-8B)
  for _, value in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(value.guid)
    if actualUnit == nil then goto continue end
    local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)

    if (actualUnit.dbid == config.platform.JY26 or actualUnit.dbid == config.platform.YLC8B) then
      if distance < temp.distance then
        temp.unit = actualUnit
        temp.distance = distance
      end
    end

    ::continue::
  end

  -- Second priority: If no dedicated radars, search for SAM system radars
  if temp.unit == nil then
    for _, value in ipairs(sideUnits) do
      local actualUnit = GameApi.ScenEdit_GetUnit(value.guid)
      if actualUnit == nil then goto continue end

      local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)

      if actualUnit.dbid == config.platform.HQ22 or
          actualUnit.dbid == config.platform.S300 or
          actualUnit.dbid == config.platform.S400 or
          actualUnit.dbid == config.platform.HQ12 then
        if distance < temp.distance then
          temp.unit = actualUnit
          temp.distance = distance
        end
      end

      ::continue::
    end
  end

  -- Activate the nearest radar found
  if temp.unit ~= nil then
    GameApi.ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    Logger.log(tostring(temp.unit.name) .. '\'s radar is activated.')
  end
end

--- Add C2 facilities to the scenario
--- Creates multiple C2 facility units at random positions within configured areas
--- These facilities serve as suspected command and control nodes for the Chinese forces
--- @param IADSConfig SBJ__IADSConfig IADS configuration containing C2 settings, facility DBIDs, and deployment parameters
--- @return boolean Returns true if all C2 facilities were successfully created, false if any creation failed
function IADS.addC2Facilities(IADSConfig)
  for _, setting in ipairs(IADSConfig.C2Settings) do
    local units = GameUtils.createRandomUnits({
      centerPoint = setting.position,
      dbids = IADSConfig.C2FacilityDBIDs,
      count = 3,
      randomRadius = IADSConfig.randomRadius,
      sideName = 'China',
      unitType = 'Facility',
      unitname = "Suspected C2 Facility#",
      autodetectable = true
    })

    if not units or (type(units) == "table" and #units == 0) then
      Logger.error("Failed to create C2 facilities")
      return false
    end
  end

  Logger.log("Successfully added C2 facilities")
  return true
end

--- Initialize C2 facilities for China's IADS
--- This function:
--- 1. Identifies all facility units on China's side
--- 2. Randomly selects one facility per configured area to act as the active C2 node
--- 3. Associates all radars (JY-26, YLC-8B) and SAMs (HQ-22, S-300, S-400, HQ-12) in each area with their C2 node
--- 4. Initializes tracking data for each unit including OODA loop timing and EMCON settings
--- @param config SBJ__CONFIG Global configuration containing platform DBIDs and unit types
--- @param IADSConfig SBJ__IADSConfig IADS-specific configuration with C2 settings and deployment areas
--- @param IADSContext SBJ__IADSContext IADS context object that will be populated with C2 node data and associated units
--- @return boolean Returns true if initialization succeeded, false if no units found
function IADS.initC2FacilitiesContext(config, IADSConfig, IADSContext)
  local filteredUnits = GameApi.VP_GetSide({ name = 'China' }):unitsBy(config.unitType.FACILITY)
  IADSContext.C2 = {}

  if not filteredUnits then
    return false
  end

  for _, setting in ipairs(IADSConfig.C2Settings) do
    local facilities = {}

    for _, u in ipairs(filteredUnits) do
      local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)
      if actualUnit then
        for _, area in ipairs(setting.areas) do
          for _, DBID in ipairs(IADSConfig.C2FacilityDBIDs) do
            if actualUnit.dbid == DBID and actualUnit:inArea(area) then
              table.insert(facilities, actualUnit)
              break
            end
          end
        end
      end
    end

    if #facilities > 0 then
      local randomIdx = math.random(#facilities)
      IADSContext.C2[facilities[randomIdx].guid] = {
        name = facilities[randomIdx].name .. '/' .. setting.areaName,
        msg = 'Radio source, ' .. facilities[randomIdx].name,
        guid = facilities[randomIdx].guid,
        areas = setting.areas,
        SAM = {},
        radar = {}
      }
    end
  end

  -- Initialize SAM and radar systems
  for _, unit in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    for C2GUID, C2Ctx in pairs(IADSContext.C2) do
      for _, area in ipairs(C2Ctx.areas) do
        if actualUnit and actualUnit:inArea(area) then
          -- SAM systems
          if (actualUnit.dbid == config.platform.HQ22 or
                actualUnit.dbid == config.platform.S300 or
                actualUnit.dbid == config.platform.S400 or
                actualUnit.dbid == config.platform.HQ12) and
              not string.find(actualUnit.name, 'DECOY') then
            IADSContext.C2[C2GUID].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }
          end

          -- Radar systems
          if actualUnit.dbid == config.platform.JY26 or actualUnit.dbid == config.platform.YLC8B then
            IADSContext.C2[C2GUID].radar[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }
          end
        end
      end
    end
  end

  Logger.log("Successfully initialized C2 facilities")
  return true
end

--- Initialize Command and Control systems for Taiwan's IADS
--- This function associates Taiwan's air defense units with their respective C2 nodes:
--- 1. ROCC (Regional Operations Control Center) manages strategic SAMs (TK-3, PAC-3) and long-range radars (FPS-117, TPS-43F, HR-3000, GE-592)
--- 2. TAAOC (Tactical Air Operations Center) manages tactical SAMs (TC-2, Sky Guard)
--- All units are initialized with passive EMCON settings for emission control
--- @param config SBJ__CONFIG Global configuration containing platform DBIDs for Taiwan's air defense systems
--- @param IADSContext SBJ__IADSContext IADS context object containing pre-configured ROCC and TAAOC nodes to populate with units
function IADS.initC2Contexts(config, IADSContext)
  local filteredUnits = GameApi.VP_GetSide({ side = "Taiwan" }):unitsBy(config.unitType.FACILITY)

  if not filteredUnits then
    return
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    for _, C2Ctx in pairs(IADSContext.ROCC) do
      for _, area in ipairs(C2Ctx.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if actualUnit.dbid == config.platform.CUSTOMED_TK3 or actualUnit.dbid == config.platform.PAC3 then
            IADSContext.ROCC[C2Ctx.guid].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }
          end

          if actualUnit.dbid == config.platform.FPS117 or
              actualUnit.dbid == config.platform.TPS43F or
              actualUnit.dbid == config.platform.HR3000 or
              actualUnit.dbid == config.platform.GE592 then
            IADSContext.ROCC[C2Ctx.guid].radar[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }
          end
        end
      end
    end

    for _, C2Ctx in pairs(IADSContext.TAAOC) do
      for _, area in ipairs(C2Ctx.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if actualUnit.dbid == config.platform.TC2 or actualUnit.dbid == config.platform.SKY_GUARD then
            IADSContext.TAAOC[C2Ctx.guid].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }
          end
        end
      end
    end
  end
end

--- Remove C2 facilities from the scenario
--- Deletes all C2 facility units that match the configured DBIDs from China's side
--- Used for cleaning up existing C2 facilities before redeployment or scenario reset
--- @param config SBJ__CONFIG Global configuration containing unit type definitions
--- @param IADSConfig SBJ__IADSConfig IADS configuration containing C2 facility DBIDs to identify units for removal
--- @return boolean Returns true if removal operation completed (even if 0 units removed), false if unit query failed
function IADS.removeC2Facilities(config, IADSConfig)
  local filteredUnits = GameApi.VP_GetSide({ name = 'China' }):unitsBy(config.unitType.FACILITY)
  local removedCount = 0

  if not filteredUnits then
    return false
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)
    if actualUnit then
      for _, DBID in ipairs(IADSConfig.C2FacilityDBIDs) do
        if actualUnit.dbid == DBID then
          GameApi.ScenEdit_DeleteUnit({ side = 'China', guid = actualUnit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(string.format("Removed %d C2 facilities", removedCount))
  return true
end

return IADS
