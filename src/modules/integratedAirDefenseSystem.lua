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

local BLUE_SAM_DBIDS = {
  [constants.PLATFORMS.CUSTOMED_TK3] = true,
  [constants.PLATFORMS.CUSTOMED_SAM] = true,
  [constants.PLATFORMS.PAC3] = true,
}

---Emission interval that keeps a held SAM asleep, in seconds
local SLEEP_EMISSION_INTERVAL_SEC = 3600

local BLUE_MRAD_DBIDS = {
  [constants.PLATFORMS.TC2] = true,
  [constants.PLATFORMS.SKY_GUARD] = true,
}

local BLUE_RADAR_DBIDS = {
  [constants.PLATFORMS.FPS117] = true,
  [constants.PLATFORMS.TPS43F] = true,
  [constants.PLATFORMS.HR3000] = true,
  [constants.PLATFORMS.GE592] = true,
}

local C2_KEYS = {
  RADAR = "radar",
  SAM = "sam",
}
---@cast C2_KEYS table<string, SBJ__C2UnitKey>

---Disable units under C2 node by setting them out of communications
---@param c2State SBJ__C2State
---@param type SBJ__C2UnitKey Unit type to disable ('radar' or 'sam')
local function disableUnitsUnderC2Node(c2State, type)
  local ctxMap = c2State[type]

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
---@param dbid number
---@return boolean Whether the DBID corresponds to a PLA SAM unit
local function isPLASAM(dbid)
  return PLA_SAM_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a radar unit
---@param dbid number
---@return boolean Whether the DBID corresponds to a radar unit
local function isPLARadar(dbid)
  return PLA_RADAR_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a MRADS unit
---@param dbid number
---@return boolean Whether the DBID corresponds to a MRADS unit
local function isMRADS(dbid)
  return BLUE_MRAD_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a Taiwan radar unit
---@param dbid number
---@return boolean Whether the DBID corresponds to a Taiwan radar unit
local function isBlueRadar(dbid)
  return BLUE_RADAR_DBIDS[dbid]
end

---Returns whether the given DBID corresponds to a Taiwan SAM unit
---@param dbid number
---@return boolean Whether the DBID corresponds to a Taiwan SAM unit
local function isBlueSAM(dbid)
  return BLUE_SAM_DBIDS[dbid]
end

---Apply the control panel's weapons control choice to each named SAM unit
---Weapons free sets WCS tight and wakes emissions on threat; otherwise WCS hold and emissions stay asleep.
---@param entries SBJ__SamDoctrineEntry[]
function IntegratedAirDefenseSystem.setSamDoctrine(entries)
  for _, entry in ipairs(entries) do
    local unit = GameApi.ScenEdit_GetUnit(entry.name, constants.SIDES.BLUE)

    if unit then
      local wcs = entry.weaponFree and constants.WCS.TIGHT or constants.WCS.HOLD
      local emissionFlag = entry.weaponFree and 1 or 0
      local useInterval = entry.weaponFree and 0 or 1
      local interval = entry.weaponFree and 0 or SLEEP_EMISSION_INTERVAL_SEC

      GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = wcs })
      GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(unit.guid, "Green",
        { WakeWhenDetectingThreat = emissionFlag, UseEmissionInterval = useInterval, EmissionInterval = interval }
      )
    end
  end
end

---Move SAM units between C2 nodes to match the submitted control panel result.
---Each entry lists the SAM units a node now commands; their existing states
---(OODA, comms status) move with them. Unknown nodes and unknown units are skipped.
---@param iadsState SBJ__IADSState
---@param entries SBJ__C2ContextEntry[]
function IntegratedAirDefenseSystem.reassignSamUnits(iadsState, entries)
  -- Gather before moving anything: a unit leaves one node as it joins another
  local samStateByGuid = {}
  for _, entry in ipairs(entries) do
    for _, c2State in pairs(iadsState[entry.type] or {}) do
      for guid, samState in pairs(c2State.sam or {}) do
        samStateByGuid[guid] = samState
      end
    end
  end

  for _, entry in ipairs(entries) do
    local c2State = (iadsState[entry.type] or {})[entry.guid]

    if c2State then
      local sam = {}
      for guid in pairs(entry.sam or {}) do
        sam[guid] = samStateByGuid[guid]
      end
      c2State.sam = sam
    end
  end
end

---Follow rebuilt units to their new GUIDs inside the C2 states
---A rebuilt unit keeps its name but not its GUID, so its state moves to the new GUID
---with node and comms status intact. A unit that did not come back loses its state.
---@param iadsState SBJ__IADSState
---@param sideName string
---@param unitNames string[] Names of the units that were deleted and added again
function IntegratedAirDefenseSystem.relinkRebuiltUnits(iadsState, sideName, unitNames)
  local rebuilt = {}
  for _, name in ipairs(unitNames) do
    rebuilt[name] = true
  end

  for _, c2Group in pairs(iadsState) do
    if type(c2Group) == "table" then
      for _, c2State in pairs(c2Group) do
        for _, key in ipairs({ C2_KEYS.SAM, C2_KEYS.RADAR }) do
          -- Collect first: adding keys while traversing the table is undefined
          local stale = {}
          for guid, unitState in pairs(c2State[key] or {}) do
            if rebuilt[unitState.name] then
              stale[guid] = unitState
            end
          end

          for guid, unitState in pairs(stale) do
            local unit = GameApi.ScenEdit_GetUnit(unitState.name, sideName)
            c2State[key][guid] = nil
            if unit then
              unitState.guid = unit.guid
              c2State[key][unit.guid] = unitState
            end
          end
        end
      end
    end
  end
end

---Process command and control disruption when C2 node is destroyed
---@param saveData SBJ__SaveData
---@param c2 CMO__Unit
function IntegratedAirDefenseSystem.processC2Disruption(saveData, c2)
  local iadsState = PersistentState.iads(saveData, c2.side)

  if iadsState.c2 and iadsState.c2[c2.guid] then
    disableUnitsUnderC2Node(iadsState.c2[c2.guid], C2_KEYS.RADAR)
    disableUnitsUnderC2Node(iadsState.c2[c2.guid], C2_KEYS.SAM)
    iadsState.c2[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s C2 is destroyed")
  end

  if iadsState.rocc and iadsState.rocc[c2.guid] then
    disableUnitsUnderC2Node(iadsState.rocc[c2.guid], C2_KEYS.RADAR)
    disableUnitsUnderC2Node(iadsState.rocc[c2.guid], C2_KEYS.SAM)
    iadsState.rocc[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s ROCC is destroyed")
  end

  if iadsState.taaoc and iadsState.taaoc[c2.guid] then
    disableUnitsUnderC2Node(iadsState.taaoc[c2.guid], C2_KEYS.SAM)
    iadsState.taaoc[c2.guid] = nil
    Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, c2.name .. "'s TAAOC is destroyed")
  end
end

---Remove destroyed unit from IADS tracking by clearing its data from C2 state
---@param c2TypeState table<string, SBJ__C2State> C2 type state (e.g., IADSState.c2, IADSState.rocc, or IADSState.taaoc)
---@param type SBJ__C2UnitKey Unit type ('radar' or 'sam')
---@param destroyedUnit CMO__Unit
local function removeDestroyedUnitFromC2(c2TypeState, type, destroyedUnit)
  for _, ctx in pairs(c2TypeState) do
    for _, area in pairs(ctx.areas) do
      if destroyedUnit:inArea(area) and c2TypeState[ctx.guid] then
        c2TypeState[ctx.guid][type][destroyedUnit.guid] = nil
        Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, destroyedUnit.name .. "'s " .. type .. " is destroyed")
      end
    end
  end
end

---Activate China's nearest backup radar when a radar is destroyed to maintain coverage
---@param config SBJ__Config
---@param destroyedRadar CMO__Unit The destroyed radar whose position is used as reference point for finding nearest backup
local function activateNearestRadar(config, destroyedRadar)
  local sideUnits = GameApi.VP_GetSide({ side = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.FACILITY)
  if not sideUnits then
    return
  end

  local temp = { unit = nil, distance = config.red.iads.radarDistanceNm }
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
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@return boolean handled Whether the unit was an IADS radar or SAM
function IntegratedAirDefenseSystem.processUnitDestruction(config, saveData, unit)
  local iadsState = PersistentState.iads(saveData, unit.side)
  local dbid = unit.dbid

  if isPLASAM(dbid) then
    removeDestroyedUnitFromC2(iadsState.c2, C2_KEYS.SAM, unit)
    activateNearestRadar(config, unit)
  elseif dbid == constants.PLATFORMS.JY26 or dbid == constants.PLATFORMS.YLC8B then
    removeDestroyedUnitFromC2(iadsState.c2, C2_KEYS.RADAR, unit)
    activateNearestRadar(config, unit)
  elseif isBlueRadar(dbid) then
    removeDestroyedUnitFromC2(iadsState.rocc, C2_KEYS.RADAR, unit)
  elseif isBlueSAM(dbid) then
    removeDestroyedUnitFromC2(iadsState.rocc, C2_KEYS.SAM, unit)
  elseif isMRADS(dbid) then
    removeDestroyedUnitFromC2(iadsState.taaoc, C2_KEYS.SAM, unit)
  else
    return false
  end

  return true
end

---Add C2 facility units at random positions within configured areas
---@param iadsConfig SBJ__IADSConfig
local function addC2Facilities(iadsConfig)
  for _, setting in ipairs(iadsConfig.c2Deployments) do
    local units = GameUtils.createRandomUnits({
      centerPoint = setting.pos,
      dbids = iadsConfig.c2FacilityDBIDs,
      count = 3,
      randomRadiusNm = iadsConfig.randomRadiusNm,
      sideName = constants.SIDES.RED,
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

---Initialize C2 facilities state for China's IADS with radar and SAM associations
---@param iadsConfig SBJ__IADSConfig
---@param iadsState SBJ__IADSState
local function initC2FacilitiesContext(iadsConfig, iadsState)
  local sideUnits = GameApi.VP_GetSide({ name = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.FACILITY)
  iadsState.c2 = {}

  if not sideUnits then
    return
  end

  for _, setting in ipairs(iadsConfig.c2Deployments) do
    ---@type CMO__Unit[]
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
      local randomFacility = facilities[randomIdx]
      iadsState.c2[randomFacility.guid] = {
        name = randomFacility.name .. "/" .. setting.name,
        msg = "Radio source, " .. randomFacility.name,
        guid = randomFacility.guid,
        areas = setting.areas,
        sam = {},
        radar = {}
      }
    end
  end

  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    for c2GUID, c2State in pairs(iadsState.c2) do
      for _, area in ipairs(c2State.areas) do
        if actualUnit and actualUnit:inArea(area) then
          -- SAM systems
          if isPLASAM(actualUnit.dbid) and not string.find(actualUnit.name, "DECOY") then
            iadsState.c2[c2GUID].sam[actualUnit.guid] = {
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
            iadsState.c2[c2GUID].radar[actualUnit.guid] = {
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

---Initialize C2 state for a specific C2 facility unit
---@param c2State table<string, SBJ__C2State>
---@param c2Descriptor SBJ__C2Descriptor
---@param c2GUID string
---@param c2Type string C2 type ('c2', 'rocc', or 'taaoc') determining which sub-tables to initialize
local function initC2Context(c2State, c2Descriptor, c2GUID, c2Type)
  c2State[c2GUID] = {
    name = c2Descriptor.name,
    msg = "Radio source, C2",
    guid = c2GUID,
    areas = c2Descriptor.areas,
    sam = {},
  }

  if c2Type == "c2" or c2Type == "rocc" then
    c2State[c2GUID].radar = {}
  end
end

---Initialize command and control states for Taiwan's ROCC and TAAOC systems
---@param iadsConfig SBJ__IADSFactionConfig
---@param iadsState SBJ__IADSState
local function initIADSContexts(iadsConfig, iadsState)
  local sideUnits = GameApi.VP_GetSide({ side = constants.SIDES.BLUE }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not sideUnits then
    return
  end

  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    for _, descriptor in pairs(iadsConfig.rocc) do
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, constants.SIDES.BLUE)

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if isBlueSAM(actualUnit.dbid) then
            if not iadsState.rocc[c2.guid] then
              initC2Context(iadsState.rocc, descriptor, c2.guid, "rocc")
            end

            iadsState.rocc[c2.guid].sam[actualUnit.guid] = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = "Radar=Passive"
            }
          end

          if isBlueRadar(actualUnit.dbid) then
            if not iadsState.rocc[c2.guid] then
              initC2Context(iadsState.rocc, descriptor, c2.guid, "rocc")
            end

            iadsState.rocc[c2.guid].radar[actualUnit.guid] = {
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
      local c2 = GameApi.ScenEdit_GetUnit(descriptor.name, constants.SIDES.BLUE)

      for _, area in ipairs(descriptor.areas) do
        if actualUnit and actualUnit:inArea(area) and c2 then
          if isMRADS(actualUnit.dbid) then
            if not iadsState.taaoc[c2.guid] then
              initC2Context(iadsState.taaoc, descriptor, c2.guid, "taaoc")
            end

            iadsState.taaoc[c2.guid].sam[actualUnit.guid] = {
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
---@param iadsConfig SBJ__IADSConfig
local function removeC2Facilities(iadsConfig)
  local sideUnits = GameApi.VP_GetSide({ name = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.FACILITY)
  local removedCount = 0

  if not sideUnits then
    return
  end

  for _, sideUnit in ipairs(sideUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    if actualUnit then
      for _, dbid in ipairs(iadsConfig.c2FacilityDBIDs) do
        if actualUnit.dbid == dbid then
          GameApi.ScenEdit_DeleteUnit({ side = constants.SIDES.RED, guid = actualUnit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM, string.format("Removed %d C2 facilities", removedCount))
end

---Replace China's C2 facilities with fresh ones and rebuild the C2 node states over them
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)
  local iadsConfig = config.red.iads

  removeC2Facilities(iadsConfig)
  addC2Facilities(iadsConfig)
  initC2FacilitiesContext(iadsConfig, PersistentState.iads(saveData, constants.SIDES.RED))
end

---Build a side's IADS node states when its IADS is enabled
---Taiwan links SAMs and radars to its ROCC/TAAOC nodes; China picks C2 facilities as its nodes.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function IntegratedAirDefenseSystem.initSide(config, saveData, sideName)
  local iadsState = PersistentState.iads(saveData, sideName)
  if not iadsState.enabled then
    return
  end

  local iadsConfig = config[GameUtils.getCachedSideConfig(sideName).field].iads
  if sideName == constants.SIDES.BLUE then
    initIADSContexts(iadsConfig, iadsState)
  else
    initC2FacilitiesContext(iadsConfig, iadsState)
  end
end

return IntegratedAirDefenseSystem
