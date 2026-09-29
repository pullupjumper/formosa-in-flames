local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")

local IntegratedAirDefenseSystem = {}

local PLA_RADAR_DBIDS = {
  [constants.PLATFORMS.JY26] = true,
  [constants.PLATFORMS.YLC2] = true,
  [constants.PLATFORMS.YLC8B] = true,
  [constants.PLATFORMS.SLC7] = true,
  [constants.PLATFORMS.OTH_SW] = true,
}

local PLA_SAM_DBIDS = {
  [constants.PLATFORMS.S300] = true,
  [constants.PLATFORMS.S400] = true,
  [constants.PLATFORMS.HQ12] = true,
  [constants.PLATFORMS.HQ22] = true,
}

local TAIWAN_SAM_DBIDS = {
  [constants.PLATFORMS.CUSTOMED_TK3] = true,
  [constants.PLATFORMS.CUSTOMED_SAM] = true,
  [constants.PLATFORMS.PAC3] = true,
}

local TAIWAN_MRAD_DBIDS = {
  [constants.PLATFORMS.TC2] = true,
  [constants.PLATFORMS.SKY_GUARD] = true,
}

local TAIWAN_RADAR_DBIDS = {
  [constants.PLATFORMS.FPS117] = true,
  [constants.PLATFORMS.TPS43F] = true,
  [constants.PLATFORMS.HR3000] = true,
  [constants.PLATFORMS.GE592] = true,
}

---Taiwan SAM platforms keyed by their WCS setting menu id
local TAIWAN_SAM_DBIDS_BY_MENU_ID = {
  pac23 = constants.PLATFORMS.PAC3,
  skybow3 = constants.PLATFORMS.CUSTOMED_TK3,
  tc2 = constants.PLATFORMS.TC2,
}

---Disable units under C2 node by setting them out of communications
---@param c2Ctx SBJ__C2Context The C2 context containing the units to disable
---@param type string Unit type to disable ('radar' or 'sam')
local function disableUnitsUnderC2Node(c2Ctx, type)
  local ctxMap = c2Ctx[type]

  if ctxMap then
    for _, ctx in pairs(ctxMap) do
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

---Returns whether the given DBID corresponds to a PLA SAM unit
---@param dbid number The DBID to check
---@return boolean Whether the DBID corresponds to a PLA SAM unit
local function isPLASAM(dbid)
  return PLA_SAM_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a radar unit
---@param dbid number The DBID to check
---@return boolean Whether the DBID corresponds to a radar unit
local function isPLARadar(dbid)
  return PLA_RADAR_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a MRADS unit
---@param dbid number The DBID to check
---@return boolean Whether the DBID corresponds to a MRADS unit
local function isMRADS(dbid)
  return TAIWAN_MRAD_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a Taiwan radar unit
---@param dbid number The DBID to check
---@return boolean Whether the DBID corresponds to a Taiwan radar unit
local function isTaiwanRadar(dbid)
  return TAIWAN_RADAR_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a Taiwan SAM unit
---@param dbid number The DBID to check
---@return boolean Whether the DBID corresponds to a Taiwan SAM unit
local function isTaiwanSAM(dbid)
  return TAIWAN_SAM_DBIDS[dbid]
end

---Apply the WCS setting menu's per-SAM-type doctrine to matching units
---Weapons free sets WCS tight and wakes emissions on threat; otherwise WCS hold and emissions stay asleep.
---@param doctrineItems {id: string, weaponsFree: boolean}[] Per-SAM-type choices from the WCS setting menu
---@param units {guid: string}[] Candidate units; only those matching an item's platform are changed
function IntegratedAirDefenseSystem.setSamDoctrine(doctrineItems, units)
  for _, item in ipairs(doctrineItems) do
    local dbid = TAIWAN_SAM_DBIDS_BY_MENU_ID[item.id]
    local wcs = item.weaponsFree and constants.WCS.TIGHT or constants.WCS.HOLD
    local emissionFlag = item.weaponsFree and 1 or 0

    for _, u in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if unit and unit.dbid == dbid then
        GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = wcs })
        GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(unit.guid, "Green",
          { WakeWhenDetectingThreat = emissionFlag, UseEmissionInterval = emissionFlag }
        )
      end
    end
  end
end

---Process command and control disruption when C2 node is destroyed
---@param saveData SBJ__SaveData Persistent save data; the C2 node's side IADS slice is mutated
---@param c2 CMO__Unit The destroyed command and control node unit
function IntegratedAirDefenseSystem.processC2Disruption(saveData, c2)
  local iadsCtx = PersistentState.iads(saveData, c2.side)

  -- Check China C2 nodes
  if iadsCtx.c2 and iadsCtx.c2[c2.guid] then
    disableUnitsUnderC2Node(iadsCtx.c2[c2.guid], "radar")
    disableUnitsUnderC2Node(iadsCtx.c2[c2.guid], "sam")
    iadsCtx.c2[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s C2 is destroyed")
  end

  -- Check Taiwan ROCC nodes
  if iadsCtx.rocc and iadsCtx.rocc[c2.guid] then
    disableUnitsUnderC2Node(iadsCtx.rocc[c2.guid], "radar")
    disableUnitsUnderC2Node(iadsCtx.rocc[c2.guid], "sam")
    iadsCtx.rocc[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s ROCC is destroyed")
  end

  -- Check Taiwan TAAOC nodes
  if iadsCtx.taaoc and iadsCtx.taaoc[c2.guid] then
    disableUnitsUnderC2Node(iadsCtx.taaoc[c2.guid], "sam")
    iadsCtx.taaoc[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s TAAOC is destroyed")
  end
end

---Remove destroyed unit from IADS tracking by clearing its data from C2 context
---@param c2TypeCtx table<string, SBJ__C2Context> C2 type context (e.g., IADSContext.c2, IADSContext.rocc, or IADSContext.taaoc)
---@param type string Unit type ('radar' or 'sam')
---@param destroyedUnit CMO__Unit The destroyed radar or SAM unit to remove from tracking
local function removeDestroyedUnitFromC2(c2TypeCtx, type, destroyedUnit)
  -- Iterate through all C2 nodes to check if destroyed unit is within their coverage areas
  for _, ctx in pairs(c2TypeCtx) do
    for _, area in pairs(ctx.areas) do
      if destroyedUnit:inArea(area) and c2TypeCtx[ctx.guid] then
        c2TypeCtx[ctx.guid][type][destroyedUnit.guid] = nil
        Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, destroyedUnit.name .. "'s " .. type .. " is destroyed")
      end
    end
  end
end

---Activate China's nearest backup radar when a radar is destroyed to maintain coverage
---@param config SBJ__Config Configuration parameters containing the radar distance threshold
---@param destroyedRadar CMO__Unit The destroyed radar whose position is used as reference point for finding nearest backup
local function activateNearestRadar(config, destroyedRadar)
  local sideUnits = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.FACILITY)
  if not sideUnits then
    return
  end

  local temp = { unit = nil, distance = config.radarDistance }
  local latitude = destroyedRadar.latitude
  local longitude = destroyedRadar.longitude

  -- First priority: Search for dedicated radars (JY-26, YLC-8B)
  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    if actualUnit == nil then
      goto continue
    end

    local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)
    if isPLARadar(actualUnit.dbid) then
      if distance < temp.distance then
        temp.unit = actualUnit
        temp.distance = distance
      end
    end

    ::continue::
  end

  -- Second priority: If no dedicated radars, search for SAM system radars
  if temp.unit == nil then
    for _, sideUnit in ipairs(sideUnits) do
      local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

      if not actualUnit then
        goto continue
      end

      local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, actualUnit.guid)
      if isPLASAM(actualUnit.dbid) then
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
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, tostring(temp.unit.name) .. "'s radar is activated.")
  end
end

---Stop tracking a destroyed radar or SAM under its C2 node; a lost China radar or SAM wakes the nearest backup radar
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data; the unit's side IADS slice is mutated
---@param unit CMO__Unit The destroyed unit
---@return boolean handled Whether the unit was an IADS radar or SAM
function IntegratedAirDefenseSystem.processUnitDestruction(config, saveData, unit)
  local iadsCtx = PersistentState.iads(saveData, unit.side)
  local dbid = unit.dbid

  if isPLASAM(dbid) then
    removeDestroyedUnitFromC2(iadsCtx.c2, "sam", unit)
    activateNearestRadar(config, unit)
  elseif dbid == constants.PLATFORMS.JY26 or dbid == constants.PLATFORMS.YLC8B then
    removeDestroyedUnitFromC2(iadsCtx.c2, "radar", unit)
    activateNearestRadar(config, unit)
  elseif isTaiwanRadar(dbid) then
    removeDestroyedUnitFromC2(iadsCtx.rocc, "radar", unit)
  elseif isTaiwanSAM(dbid) then
    removeDestroyedUnitFromC2(iadsCtx.rocc, "sam", unit)
  elseif isMRADS(dbid) then
    removeDestroyedUnitFromC2(iadsCtx.taaoc, "sam", unit)
  else
    return false
  end

  return true
end

---Add C2 facility units at random positions within configured areas
---@param iadsConfig SBJ__IADSConfig IADS configuration containing C2 settings, facility DBIDs, and deployment parameters
local function addC2Facilities(iadsConfig)
  for _, setting in ipairs(iadsConfig.c2Deployments) do
    local units = GameUtils.createRandomUnits({
      centerPoint = setting.position,
      dbids = iadsConfig.c2FacilityDBIDs,
      count = 3,
      randomRadius = iadsConfig.randomRadius,
      sideName = constants.SIDES.ENEMY,
      unitType = constants.UNIT_TYPES.FACILITY,
      unitname = "Suspected C2 Facility#",
      autodetectable = true
    })

    if not units or (type(units) == "table" and #units == 0) then
      Logger.error("Failed to create C2 facilities")
      return
    end
  end

  Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, "Successfully added C2 facilities")
end

---Initialize C2 facilities context for China's IADS with radar and SAM associations
---@param iadsConfig SBJ__IADSConfig IADS-specific configuration with C2 settings and deployment areas
---@param iadsCtx SBJ__IADSContext IADS context object that will be populated with C2 node data and associated units
local function initC2FacilitiesContext(iadsConfig, iadsCtx)
  local sideUnits = GameApi.VP_GetSide({ name = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.FACILITY)
  iadsCtx.c2 = {}

  if not sideUnits then
    return
  end

  for _, setting in ipairs(iadsConfig.c2Deployments) do
    local facilities = {}

    for _, sideUnit in ipairs(sideUnits) do
      local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)
      if actualUnit then
        for _, area in ipairs(setting.areas) do
          for _, dbid in ipairs(iadsConfig.c2FacilityDBIDs) do
            if actualUnit.dbid == dbid and actualUnit:inArea(area) then
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
      iadsCtx.c2[randomFacility.guid] = {
        name = randomFacility.name .. "/" .. setting.name,
        msg = "Radio source, " .. randomFacility.name,
        guid = randomFacility.guid,
        areas = setting.areas,
        sam = {},
        radar = {}
      }
    end
  end

  -- Initialize SAM and radar systems
  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    for c2GUID, c2Ctx in pairs(iadsCtx.c2) do
      for _, area in ipairs(c2Ctx.areas) do
        if actualUnit and actualUnit:inArea(area) then
          -- SAM systems
          if isPLASAM(actualUnit.dbid) and not string.find(actualUnit.name, "DECOY") then
            iadsCtx.c2[c2GUID].sam[actualUnit.guid] = {
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
          if isPLARadar(actualUnit.dbid) then
            iadsCtx.c2[c2GUID].radar[actualUnit.guid] = {
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

  Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, "Successfully initialized C2 facilities")
end

---Initialize C2 context for a specific C2 facility unit
---@param c2Ctx table<string, SBJ__C2Context> C2 context mapping to be populated with C2 node data
---@param c2Descriptor SBJ__C2Descriptor C2 descriptor containing name and deployment areas
---@param c2GUID string GUID of the C2 facility unit being initialized
---@param c2Type string C2 type ('c2', 'rocc', or 'taaoc') determining which sub-tables to initialize
local function initC2Context(c2Ctx, c2Descriptor, c2GUID, c2Type)
  c2Ctx[c2GUID] = {
    name = c2Descriptor.name,
    msg = "Radio source, C2",
    guid = c2GUID,
    areas = c2Descriptor.areas,
    sam = {},
  }

  if c2Type == "c2" or c2Type == "rocc" then
    c2Ctx[c2GUID].radar = {}
  end
end

---Initialize command and control contexts for Taiwan's ROCC and TAAOC systems
---@param iadsConfig SBJ__IADSFactionConfig IADS configuration for faction
---@param iadsCtx SBJ__IADSContext IADS context object containing pre-configured ROCC and TAAOC nodes to populate with units
local function initIADSContexts(iadsConfig, iadsCtx)
  local sideUnits = GameApi.VP_GetSide({ side = constants.SIDES.PLAYER }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not sideUnits then
    return
  end

  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    for _, descriptor in pairs(iadsConfig.rocc) do
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, constants.SIDES.PLAYER)

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if isTaiwanSAM(actualUnit.dbid) then
            if not iadsCtx.rocc[c2.guid] then
              initC2Context(iadsCtx.rocc, descriptor, c2.guid, "rocc")
            end

            iadsCtx.rocc[c2.guid].sam[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end

          if isTaiwanRadar(actualUnit.dbid) then
            if not iadsCtx.rocc[c2.guid] then
              initC2Context(iadsCtx.rocc, descriptor, c2.guid, "rocc")
            end

            iadsCtx.rocc[c2.guid].radar[actualUnit.guid] = {
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

    for _, descriptor in pairs(iadsConfig.taaoc) do
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, constants.SIDES.PLAYER)

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if isMRADS(actualUnit.dbid) then
            if not iadsCtx.taaoc[c2.guid] then
              initC2Context(iadsCtx.taaoc, descriptor, c2.guid, "taaoc")
            end

            iadsCtx.taaoc[c2.guid].sam[actualUnit.guid] = {
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
---@param iadsConfig SBJ__IADSConfig IADS configuration containing C2 facility DBIDs to identify units for removal
local function removeC2Facilities(iadsConfig)
  local sideUnits = GameApi.VP_GetSide({ name = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.FACILITY)
  local removedCount = 0

  if not sideUnits then
    return
  end

  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    if actualUnit then
      for _, dbid in ipairs(iadsConfig.c2FacilityDBIDs) do
        if actualUnit.dbid == dbid then
          GameApi.ScenEdit_DeleteUnit({ side = constants.SIDES.ENEMY, guid = actualUnit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, string.format("Removed %d C2 facilities", removedCount))
end

---Replace China's C2 facilities with fresh ones and rebuild the C2 node contexts over them
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data; China's IADS C2 map is rebuilt
function IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)
  local iadsConfig = config.c.iads

  removeC2Facilities(iadsConfig)
  addC2Facilities(iadsConfig)
  initC2FacilitiesContext(iadsConfig, PersistentState.iads(saveData, constants.SIDES.ENEMY))
end

---Build a side's IADS node contexts when its IADS is enabled
---Taiwan links SAMs and radars to its ROCC/TAAOC nodes; China picks C2 facilities as its nodes.
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data; the side's IADS slice is filled
---@param sideName string Side name (China or Taiwan)
function IntegratedAirDefenseSystem.initSide(config, saveData, sideName)
  local iadsCtx = PersistentState.iads(saveData, sideName)
  if not iadsCtx.enabled then
    return
  end

  local iadsConfig = config[GameUtils.getCachedSideConfig(sideName).field].iads
  if sideName == constants.SIDES.PLAYER then
    initIADSContexts(iadsConfig, iadsCtx)
  else
    initC2FacilitiesContext(iadsConfig, iadsCtx)
  end
end

return IntegratedAirDefenseSystem
