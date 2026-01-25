local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")
local Utils = require("src.utils.utils")

local IADS = {}

---Disable units under C2 node by setting them out of communications
---@param C2Context SBJ__C2Context The C2 context containing the units to disable
---@param type string Unit type to disable ('radar' or 'SAM')
local function disableUnitsUnderC2Node(C2Context, type)
  local ctxs = C2Context[type]

  if ctxs then
    for _, ctx in pairs(ctxs) do
      local actualUnit = GameApi.ScenEdit_GetUnit(ctx.guid)

      if not actualUnit then
        goto continue
      end

      GameApi.ScenEdit_SetUnit({ guid = ctx.guid, outofcomms = true })
      ctx.isOutOfComms = true
      ::continue::
    end
  end
end

---Process command and control disruption when C2 node is destroyed
---@param IADSContext SBJ__IADSContext IADS context containing C2 nodes
---@param C2 CMO__Unit The destroyed command and control node unit
function IADS.processC2Disruption(IADSContext, C2)
  -- Check China C2 nodes
  if IADSContext.C2 and IADSContext.C2[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.C2[C2.guid], "radar")
    disableUnitsUnderC2Node(IADSContext.C2[C2.guid], "SAM")
    IADSContext.C2[C2.guid] = nil
    Logger.log("IADS", C2.name .. "'s C2 is destroyed")
  end

  -- Check Taiwan ROCC nodes
  if IADSContext.ROCC and IADSContext.ROCC[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.ROCC[C2.guid], "radar")
    disableUnitsUnderC2Node(IADSContext.ROCC[C2.guid], "SAM")
    IADSContext.ROCC[C2.guid] = nil
    Logger.log("IADS", C2.name .. "'s ROCC is destroyed")
  end

  -- Check Taiwan TAAOC nodes
  if IADSContext.TAAOC and IADSContext.TAAOC[C2.guid] then
    disableUnitsUnderC2Node(IADSContext.TAAOC[C2.guid], "SAM")
    IADSContext.TAAOC[C2.guid] = nil
    Logger.log("IADS", C2.name .. "'s TAAOC is destroyed")
  end
end

---Remove destroyed unit from IADS tracking by clearing its data from C2 context
---@param C2TypeContext table<string, SBJ__C2Context> C2 type context (e.g., IADSContext.C2, IADSContext.ROCC, or IADSContext.TAAOC)
---@param type string Unit type ('radar' or 'SAM')
---@param destroyedUnit CMO__Unit The destroyed radar or SAM unit to remove from tracking
function IADS.removeDestroyedUnitContextFromIADS(C2TypeContext, type, destroyedUnit)
  -- Iterate through all C2 nodes to check if destroyed unit is within their coverage areas
  for _, ctx in pairs(C2TypeContext) do
    for _, area in pairs(ctx.areas) do
      if destroyedUnit:inArea(area) and C2TypeContext[ctx.guid] then
        C2TypeContext[ctx.guid][type][destroyedUnit.guid] = nil
        Logger.log("IADS", destroyedUnit.name .. "'s " .. type .. " is destroyed")
      end
    end
  end
end

---Activate nearest backup radar when a radar is destroyed to maintain coverage
---@param config SBJ__Config Configuration parameters containing platform DBIDs and radar distance threshold
---@param sideUnits CMO__SideUnit[] Array of available radar units to search through for potential backups
---@param destroyedRadar CMO__Unit The destroyed radar whose position is used as reference point for finding nearest backup
function IADS.activateNearestRadar(config, sideUnits, destroyedRadar)
  local temp = { unit = nil, distance = config.radarDistance }
  local latitude = destroyedRadar.latitude
  local longitude = destroyedRadar.longitude

  -- First priority: Search for dedicated radars (JY-26, YLC-8B)
  for _, u in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit == nil then
      goto continue
    end

    local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)
    if (actualUnit.dbid == constants.PLATFORMS.JY26 or actualUnit.dbid == constants.PLATFORMS.YLC8B) then
      if distance < temp.distance then
        temp.unit = actualUnit
        temp.distance = distance
      end
    end

    ::continue::
  end

  -- Second priority: If no dedicated radars, search for SAM system radars
  if temp.unit == nil then
    for _, u in ipairs(sideUnits) do
      local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

      if not actualUnit then
        goto continue
      end

      local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)
      if actualUnit.dbid == constants.PLATFORMS.HQ22 or
          actualUnit.dbid == constants.PLATFORMS.S300 or
          actualUnit.dbid == constants.PLATFORMS.S400 or
          actualUnit.dbid == constants.PLATFORMS.HQ12 then
        if distance < temp.distance then
          temp.unit = actualUnit
          temp.distance = distance
        end
      end

      ::continue::
    end
  end

  -- Activate the nearest radar found
  if temp.unit then
    GameApi.ScenEdit_SetEMCON("Unit", temp.unit.guid, "Radar=Active")
    Logger.log("IADS", tostring(temp.unit.name) .. "'s radar is activated.")
  end
end

---Add C2 facility units at random positions within configured areas
---@param IADSConfig SBJ__IADSConfig IADS configuration containing C2 settings, facility DBIDs, and deployment parameters
---@return boolean # True if all C2 facilities were successfully created, false if any creation failed
function IADS.addC2Facilities(IADSConfig)
  for _, setting in ipairs(IADSConfig.C2Deployments) do
    local units = GameUtils.createRandomUnits({
      centerPoint = setting.position,
      dbids = IADSConfig.C2FacilityDBIDs,
      count = 3,
      randomRadius = IADSConfig.randomRadius,
      sideName = "China",
      unitType = "Facility",
      unitname = "Suspected C2 Facility#",
      autodetectable = true
    })

    if not units or (type(units) == "table" and #units == 0) then
      Logger.error("Failed to create C2 facilities")
      return false
    end
  end

  Logger.log("IADS", "Successfully added C2 facilities")
  return true
end

---Initialize C2 facilities context for China's IADS with radar and SAM associations
---@param IADSConfig SBJ__IADSConfig IADS-specific configuration with C2 settings and deployment areas
---@param IADSContext SBJ__IADSContext IADS context object that will be populated with C2 node data and associated units
---@return boolean # True if initialization succeeded, false if no units found
function IADS.initC2FacilitiesContext(IADSConfig, IADSContext)
  local filteredUnits = GameApi.VP_GetSide({ name = "China" }):unitsBy(constants.UNIT_TYPES.FACILITY)
  IADSContext.C2 = {}

  if not filteredUnits then
    return false
  end

  for _, setting in ipairs(IADSConfig.C2Deployments) do
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
      ---@type CMO__Unit
      local randomFacility = facilities[randomIdx]
      IADSContext.C2[randomFacility.guid] = {
        name = randomFacility.name .. "/" .. setting.name,
        msg = "Radio source, " .. randomFacility.name,
        guid = randomFacility.guid,
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
          if (actualUnit.dbid == constants.PLATFORMS.HQ22 or
                actualUnit.dbid == constants.PLATFORMS.S300 or
                actualUnit.dbid == constants.PLATFORMS.S400 or
                actualUnit.dbid == constants.PLATFORMS.HQ12) and
              not string.find(actualUnit.name, "DECOY") then
            IADSContext.C2[C2GUID].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end

          -- Radar systems
          if actualUnit.dbid == constants.PLATFORMS.JY26 or actualUnit.dbid == constants.PLATFORMS.YLC8B then
            IADSContext.C2[C2GUID].radar[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end
        end
      end
    end
  end

  Logger.log("IADS", "Successfully initialized C2 facilities")
  return true
end

---Initialize C2 context for a specific C2 facility unit
---@param c2Context table<string, SBJ__C2Context> C2 context mapping to be populated with C2 node data
---@param c2Descriptor SBJ__C2Descriptor C2 descriptor containing name and deployment areas
---@param c2GUID string GUID of the C2 facility unit being initialized
---@param c2Type string C2 type ('C2', 'ROCC', or 'TAAOC') determining which sub-tables to initialize
local function initC2Context(c2Context, c2Descriptor, c2GUID, c2Type)
  c2Context[c2GUID] = {
    name = c2Descriptor.name,
    msg = "Radio source, C2",
    guid = c2GUID,
    areas = c2Descriptor.areas,
    SAM = {},
  }

  if c2Type == "C2" or c2Type == "ROCC" then
    c2Context[c2GUID].radar = {}
  end
end

---Initialize command and control contexts for Taiwan's ROCC and TAAOC systems
---@param IADSConfig SBJ__IADSFactionConfig IADS configuration for faction
---@param IADSContext SBJ__IADSContext IADS context object containing pre-configured ROCC and TAAOC nodes to populate with units
function IADS.initIADSContexts(IADSConfig, IADSContext)
  local filteredUnits = GameApi.VP_GetSide({ side = "Taiwan" }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not filteredUnits then
    return
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    for _, descriptor in pairs(IADSConfig.ROCC) do
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, "Taiwan")

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if actualUnit.dbid == constants.PLATFORMS.CUSTOMED_TK3 or actualUnit.dbid == constants.PLATFORMS.PAC3 then
            if not IADSContext.ROCC[c2.guid] then
              initC2Context(IADSContext.ROCC, descriptor, c2.guid, "ROCC")
            end

            IADSContext.ROCC[c2.guid].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end

          if actualUnit.dbid == constants.PLATFORMS.FPS117 or
              actualUnit.dbid == constants.PLATFORMS.TPS43F or
              actualUnit.dbid == constants.PLATFORMS.HR3000 or
              actualUnit.dbid == constants.PLATFORMS.GE592 then
            if not IADSContext.ROCC[c2.guid] then
              initC2Context(IADSContext.ROCC, descriptor, c2.guid, "ROCC")
            end

            IADSContext.ROCC[c2.guid].radar[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end
        end
      end
    end

    for _, descriptor in pairs(IADSConfig.TAAOC) do
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, "Taiwan")

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if actualUnit.dbid == constants.PLATFORMS.TC2 or actualUnit.dbid == constants.PLATFORMS.SKY_GUARD then
            if not IADSContext.TAAOC[c2.guid] then
              initC2Context(IADSContext.TAAOC, descriptor, c2.guid, "TAAOC")
            end

            IADSContext.TAAOC[c2.guid].SAM[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end
        end
      end
    end
  end
end

---Remove C2 facility units from scenario by deleting units matching configured DBIDs
---@param IADSConfig SBJ__IADSConfig IADS configuration containing C2 facility DBIDs to identify units for removal
---@return boolean # True if removal operation completed, false if unit query failed
function IADS.removeC2Facilities(IADSConfig)
  local filteredUnits = GameApi.VP_GetSide({ name = "China" }):unitsBy(constants.UNIT_TYPES.FACILITY)
  local removedCount = 0

  if not filteredUnits then
    return false
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit then
      for _, DBID in ipairs(IADSConfig.C2FacilityDBIDs) do
        if actualUnit.dbid == DBID then
          GameApi.ScenEdit_DeleteUnit({ side = "China", guid = actualUnit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log("IADS", string.format("Removed %d C2 facilities", removedCount))
  return true
end

return IADS
