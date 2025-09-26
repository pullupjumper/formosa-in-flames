local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

---@class UnitGenerator
local UnitGenerator = {}

-- ============================================================================
-- Constants definition - Improve readability, eliminate magic numbers
-- ============================================================================

local FORMATION = {
  ANGLES = {
    LEFT = -45,
    RIGHT = 45,
    REAR = -180
  },
  DISTANCES = {
    CLOSE = 1.5,
    MEDIUM = 4.5,
    FAR = 20
  }
}

local UNIT_CREATION = {
  MAX_ATTEMPTS = 50,
  RANDOM_TEXT_LENGTH = 2
}

-- ============================================================================
-- Basic utility functions - Lowest level utility functions
-- ============================================================================

---Calculate formation position
---@param centerPoint {lat: number, lon: number} Center point coordinates {lat: number, lon: number}
---@param heading number Heading angle
---@param distance number Distance
---@param angle number Angle offset
---@return table|nil Calculated position {latitude: number, longitude: number}
local function calculateFormationPosition(centerPoint, heading, distance, angle)
  return GameApi.World_GetPointFromBearing({
    LATITUDE = centerPoint.lat,
    LONGITUDE = centerPoint.lon,
    BEARING = heading + angle,
    DISTANCE = distance,
  })
end

---Batch delete units in group
---@param groupName string Group name
---@param sideName string Side name
---@return boolean Whether cleanup was successful
local function cleanupExistingGroup(groupName, sideName)
  local group = GameApi.ScenEdit_GetUnit(groupName)
  if group and group.group and group.group.unitlist then
    for _, guid in ipairs(group.group.unitlist) do
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
    end
  end
  return true
end

---Attempt to create a single unit (with retry mechanism)
---@param unitDescriptor CMO__SetUnitDescriptor Unit descriptor
---@param maxAttempts number|nil Maximum number of attempts
---@return CMO__Unit|nil Created unit
local function tryCreateUnit(unitDescriptor, maxAttempts)
  maxAttempts = maxAttempts or UNIT_CREATION.MAX_ATTEMPTS

  for attempt = 1, maxAttempts do
    local unit = GameApi.ScenEdit_AddUnit(unitDescriptor)
    if unit then
      return unit
    end

    if attempt == maxAttempts then
      Logger.error(string.format("Failed to create unit after %d attempts", maxAttempts))
    end
  end

  return nil
end


-- ============================================================================
-- Unit management functions - Handle unit creation and embarking
-- ============================================================================


---Add embarked units (advanced version, supports mission assignment)
---@param embarkedUnits SBJ__EmbarkedUnit[] List of embarked units
---@param baseGuid string Base unit GUID
local function addEmbarkedUnitsAdvanced(embarkedUnits, baseGuid)
  for _, embarkedUnit in ipairs(embarkedUnits) do
    for _, loadout in ipairs(embarkedUnit.loadouts) do
      for i = 1, loadout.num do
        local unitDescriptor = {
          side = embarkedUnit.side,
          type = embarkedUnit.type,
          dbid = embarkedUnit.dbid,
          unitname = embarkedUnit.name .. ' #' .. Utils.randomTxt(2),
          base = baseGuid,
        }

        if loadout.loadoutId ~= 0 then
          unitDescriptor.loadoutid = loadout.loadoutId
        end

        local unit = GameApi.ScenEdit_AddUnit(unitDescriptor)

        if unit and loadout.missionName then
          GameApi.ScenEdit_AssignUnitToMission(unit.guid, loadout.missionName)
        end
      end
    end
  end
end

---Add units by reference point
---@param params SBJ__Location_Params Location parameters
---@param unit CMO__SetUnitDescriptor Unit descriptor
---@param embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked units
local function addUnitsByRP(params, unit, embarkedUnits)
  local locations = GameUtils.generateLocations(params)

  for _, location in ipairs(locations) do
    unit.latitude = location.latitude
    unit.longitude = location.longitude
    local createdUnit = GameApi.ScenEdit_AddUnit(unit)

    if createdUnit and unit.cargo then
      for _, cargoItem in ipairs(unit.cargo) do
        for i = 1, cargoItem.num do
          createdUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
        end
      end

      if embarkedUnits then
        addEmbarkedUnitsAdvanced(embarkedUnits, createdUnit.guid)
      end
    end
  end
end

---Calculate ship positions
---@param firstRp CMO__Location First reference point
---@param verticalHeading number Vertical heading
---@param verticalDistance number Vertical distance
---@return table<string, CMO__Location> Positions of various ship types
local function calculateShipPositions(firstRp, verticalHeading, verticalDistance)
  local positions = {}

  positions.type075 = firstRp
  positions.type071 = GameApi.World_GetPointFromBearing({
    latitude = firstRp.latitude,
    longitude = firstRp.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.type076 = GameApi.World_GetPointFromBearing({
    latitude = positions.type071.latitude,
    longitude = positions.type071.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.barge = GameApi.World_GetPointFromBearing({
    latitude = positions.type076.latitude,
    longitude = positions.type076.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.roro = GameApi.World_GetPointFromBearing({
    latitude = positions.barge.latitude,
    longitude = positions.barge.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.type072a = GameApi.World_GetPointFromBearing({
    latitude = positions.roro.latitude,
    longitude = positions.roro.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.type072iii = GameApi.World_GetPointFromBearing({
    latitude = positions.type072a.latitude,
    longitude = positions.type072a.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.ferry = GameApi.World_GetPointFromBearing({
    latitude = positions.type072iii.latitude,
    longitude = positions.type072iii.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  positions.type073a = GameApi.World_GetPointFromBearing({
    latitude = positions.ferry.latitude,
    longitude = positions.ferry.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  return positions
end

---Create ships by type
---@param config SBJ__CONFIG Configuration object
---@param position CMO__Location Position
---@param area table Area configuration
---@param item table Item configuration
---@param shipSettings SBJ__ShipSettings Ship settings
---@param cargoList table Cargo list
---@param shipType string Ship type
local function createShipsByType(config, position, area, item, shipSettings, cargoList, shipType)
  local shipConfigs = {
    type075 = {
      dbid = config.platform.TYPE_075,
      name = 'Type 075',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z10,       loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',     dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    type071 = {
      dbid = config.platform.TYPE_071,
      name = 'Type 071',
      cargo = cargoList.type071,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 4 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',     dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 4 } } }
      }
    },
    type076 = {
      dbid = config.platform.TYPE_076,
      name = 'Type 076',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z10,       loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.GJ11,      loadouts = { { loadoutId = config.loadout.GJ11_RECON, num = 8 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',     dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    barge = { dbid = config.platform.BARGE, name = 'Barge', cargo = nil, embarkedUnits = nil },
    roro = { dbid = config.platform.FERRY, name = 'RORO', cargo = cargoList.barge, embarkedUnits = nil },
    type072a = { dbid = config.platform.TYPE_072A, name = 'Type 072A', cargo = cargoList.type072a, embarkedUnits = nil },
    type072iii = { dbid = config.platform.TYPE_072III, name = 'Type 072III', cargo = cargoList.type072iii, embarkedUnits = nil },
    ferry = { dbid = config.platform.FERRY, name = 'Ferry', cargo = cargoList.ferry, embarkedUnits = nil },
    type073a = { dbid = config.platform.TYPE_073A, name = 'Type 073A', cargo = cargoList.type073a, embarkedUnits = nil }
  }

  local shipConfig = shipConfigs[shipType]
  if not shipConfig then return end

  local params = {
    initialLocation = position,
    bearing = area.heading.horizontal,
    distance = shipSettings.horizontalDistance,
    num = item.from.num[shipType]
  }

  local unitDescriptor = {
    side = 'China',
    type = 'Ship',
    name = shipConfig.name,
    dbid = shipConfig.dbid,
    cargo = shipConfig.cargo,
    heading = area.heading.vertical,
    manualSpeed = shipSettings.shipSpeed,
  }

  addUnitsByRP(params, unitDescriptor, shipConfig.embarkedUnits)
end

-- ============================================================================
-- Formation configuration factory - Configuration-driven design
-- ============================================================================


---Get SAG formation configuration
---@param config SBJ__CONFIG Configuration object
---@param side string Side name ('China' | 'Taiwan')
---@return SBJ__ShipConfig[] Ship configuration list
local function getSAGShipConfiguration(config, side)
  if side == 'China' then
    return {
      {
        dbid = config.platform.TYPE_052D,
        unitname = '052D',
        distance = 0,
        angle = 0,
        embarkedUnits = nil
      },
      {
        dbid = config.platform.TYPE_054A,
        unitname = '054A',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = nil
      },
      {
        dbid = config.platform.TYPE_054A,
        unitname = '054A',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = nil
      },
      {
        dbid = config.platform.TYPE_052D,
        unitname = '052D',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.REAR,
        embarkedUnits = nil
      }
    }
  else -- Taiwan
    return {
      {
        dbid = config.platform.KIDD,
        unitname = 'Keelung',
        distance = 0,
        angle = 0,
        embarkedUnits = nil -- Embarked units handled separately during creation
      },
      {
        dbid = config.platform.KANG_DING,
        unitname = 'KangDing',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = nil
      },
      {
        dbid = config.platform.KANG_DING,
        unitname = 'KangDing',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = nil
      }
    }
  end
end

---Get CSG formation configuration
---@param config SBJ__CONFIG Configuration object
---@return SBJ__ShipConfig[] CSG ship configuration list
local function getCSGShipConfiguration(config)
  return {
    {
      dbid = config.c.surface.lacm.csg.unitList.type002.dbid,
      unitname = '002',
      distance = 0,
      angle = 0,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type002.embarkedUnits,
      loadouts = config.c.surface.lacm.csg.unitList.type002.loadouts
    },
    {
      dbid = config.c.surface.lacm.csg.unitList.type901.dbid,
      unitname = '901',
      distance = FORMATION.DISTANCES.MEDIUM,
      angle = FORMATION.ANGLES.REAR,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type901.embarkedUnits
    },
    {
      dbid = config.c.surface.lacm.csg.unitList.type055.dbid,
      unitname = '055',
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type055.embarkedUnits
    },
    {
      dbid = config.c.surface.lacm.csg.unitList.type055.dbid,
      unitname = '055',
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type055.embarkedUnits
    },
    {
      dbid = config.c.surface.lacm.csg.unitList.type054a.dbid,
      unitname = '054',
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type054a.embarkedUnits
    },
    {
      dbid = config.c.surface.lacm.csg.unitList.type054a.dbid,
      unitname = '054',
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = config.c.surface.lacm.csg.unitList.type054a.embarkedUnits
    }
  }
end

---Create units at random positions
---@param config SBJ__RandomUnits Configuration parameters
---@return CMO__Unit|CMO__Unit[] Created units
local function createRandomUnits(config)
  local units = {}

  for i = 1, config.count do
    local dbid = config.dbids[math.random(#config.dbids)]
    local point = GameUtils.circularRandomPosition(
      config.centerPoint.lat,
      config.centerPoint.lon,
      config.randomRadius
    )

    local unitDescriptor = {
      type = config.unitType,
      dbid = dbid,
      side = config.sideName,
      Lat = point.latitude,
      Lon = point.longitude,
      autodetectable = config.autodetectable,
      unitname = config.unitname .. Utils.randomTxt(UNIT_CREATION.RANDOM_TEXT_LENGTH),
    }

    local unit = tryCreateUnit(unitDescriptor)
    if unit then
      table.insert(units, unit)
      if config.count == 1 then
        return unit
      end
    end
  end

  return units
end

---Create formation ships
---@param formationConfig SBJ__FormationConfig Formation configuration
---@return boolean Whether successful
local function createShipFormation(formationConfig)
  -- Clean up existing group
  cleanupExistingGroup(formationConfig.groupName, formationConfig.sideName)

  local createdUnits = {}

  -- Create ships at various positions
  for _, shipConfig in ipairs(formationConfig.shipTypes) do
    local position = calculateFormationPosition(
      formationConfig.centerPoint,
      formationConfig.heading,
      shipConfig.distance,
      shipConfig.angle
    )

    if not position then
      Logger.error("Failed to calculate formation position")
      return false
    end

    local unitDescriptor = {
      latitude = position.latitude,
      longitude = position.longitude,
      heading = formationConfig.heading,
      side = formationConfig.sideName,
      type = 'Ship',
      dbid = shipConfig.dbid,
      group = formationConfig.groupName,
      unitname = shipConfig.unitname,
    }

    local unit = tryCreateUnit(unitDescriptor)
    if unit then
      table.insert(createdUnits, unit)

      -- Add embarked units
      if shipConfig.embarkedUnits then
        addEmbarkedUnitsAdvanced(shipConfig.embarkedUnits, unit.guid)
      end

      -- Add ammunition configuration (for carriers, etc.)
      if shipConfig.loadouts then
        for _, loadout in ipairs(shipConfig.loadouts) do
          GameApi.ScenEdit_FillMagsForLoadout({
            unit = unit.name,
            loadoutid = loadout.loadoutId,
            quantity = loadout.num
          })
        end
      end
    else
      Logger.error(string.format("Failed to create ship: %s", shipConfig.unitname))
      return false
    end
  end

  Logger.log(string.format("Successfully created formation %s with %d ships",
    formationConfig.groupName, #createdUnits))
  return true
end

---Attempt to create jammer unit
-- -@param config SBJ__CONFIG Configuration parameters
-- -@param jammer table Jammer equipment
-- -@param attempt number|nil Attempt count
-- -@param max_attempts number|nil Maximum attempts
-- local function tryAddJammerUnit(config, jammer, attempt, max_attempts)
--   attempt = attempt or 1
--   max_attempts = max_attempts or 50

--   local point = GameUtils.circularRandomPosition(jammer.point.lat, jammer.point.lon, jammer.randomRadius)
--   local unit = GameApi.ScenEdit_AddUnit({
--     type = 'Facility',
--     unitname = jammer.name,
--     dbid = config.platform.GPS_JAMMER,
--     side = 'China',
--     Lat = point.latitude,
--     Lon = point.longitude,
--     autodetectable = false
--   })

--   if unit then
--     return unit, point
--   elseif attempt < max_attempts then
--     return tryAddJammerUnit(config, jammer, attempt + 1, max_attempts)
--   else
--     print("Failed to create jammer unit after " .. max_attempts .. " attempts: " .. jammer.name)
--     return nil, nil
--   end
-- end

-- ============================================================================
-- Main functionality functions - Refactored version
-- ============================================================================

---Remove C2 facilities
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.removeC2Facilities(config)
  local units = GameApi.VP_GetSide({ name = 'China' }).units
  local removedCount = 0

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit then
      for _, DBID in ipairs(config.c.IADS.C2FacilityDBIDs) do
        if unit.dbid == DBID then
          GameApi.ScenEdit_DeleteUnit({ side = 'China', guid = unit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(string.format("Removed %d C2 facilities", removedCount))
  return true
end

---Add C2 facilities
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.addC2Facilities(config)
  for _, setting in ipairs(config.c.IADS.C2Settings) do
    local units = createRandomUnits({
      centerPoint = setting.position,
      dbids = config.c.IADS.C2FacilityDBIDs,
      count = 3,
      randomRadius = config.c.IADS.randomRadius,
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

---Create SAG formations
---@param config SBJ__CONFIG Configuration object
---@param side string Side name
---@return boolean Whether successful
function UnitGenerator.createSAGs(config, side)
  local sagConfigs = (side == 'China') and config.c.PHIBOP.sag or config.t.surface.sag

  for _, sagConfig in pairs(sagConfigs) do
    local formationConfig = {
      centerPoint = sagConfig.from.startingPoint,
      heading = sagConfig.from.heading,
      groupName = sagConfig.groupName,
      sideName = side,
      shipTypes = getSAGShipConfiguration(config, side)
    }

    local success = createShipFormation(formationConfig)
    if not success then
      Logger.error(string.format("Failed to create SAG %s", sagConfig.groupName))
      return false
    end

    -- Handle embarked units separately (for Taiwan)
    if side == 'Taiwan' then
      local group = GameApi.ScenEdit_GetUnit(sagConfig.groupName)
      if group and group.group and group.group.unitlist then
        for i, unitGuid in ipairs(group.group.unitlist) do
          local unit = GameApi.ScenEdit_GetUnit(unitGuid)
          if unit then
            if unit.name:find('Keelung') and sagConfig.unitList and sagConfig.unitList.kidd then
              addEmbarkedUnitsAdvanced(sagConfig.unitList.kidd.embarkedUnits, unit.guid)
            elseif unit.name:find('KangDing') and sagConfig.unitList and sagConfig.unitList.kangDing then
              addEmbarkedUnitsAdvanced(sagConfig.unitList.kangDing.embarkedUnits, unit.guid)
            end
          end
        end
      end
    end

    -- Set radar status
    local group = GameApi.ScenEdit_GetUnit(sagConfig.groupName)
    if group then
      GameApi.ScenEdit_SetEMCON('Unit', group.guid, 'Radar=Active')
    end

    -- Set mission (for Taiwan)
    if side == 'Taiwan' and sagConfig.missionName then
      local kidd = GameApi.ScenEdit_GetUnit(sagConfig.groupName)
      if kidd then
        kidd.mission = sagConfig.missionName
      end
    end
  end

  Logger.log(string.format("Successfully created SAGs for %s", side))
  return true
end

---Create CSG formation
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.createCSG(config)
  local formationConfig = {
    centerPoint = config.c.surface.lacm.csg.from.startingPoint,
    heading = config.c.surface.lacm.csg.from.heading,
    groupName = config.c.surface.lacm.csg.groupName,
    sideName = 'China',
    shipTypes = getCSGShipConfiguration(config)
  }

  local success = createShipFormation(formationConfig)
  if not success then
    Logger.error("Failed to create CSG")
    return false
  end

  -- Set reference points
  local csg = GameApi.ScenEdit_GetUnit(config.c.surface.lacm.csg.groupName)
  if csg then
    local referenceAreas = {
      { "RP-40884", "RP-40885", "RP-40886", "RP-40887" },
      { "RP-40830", "RP-40831", "RP-40832", "RP-40833" },
      { "RP-40835", "RP-40836", "RP-40837", "RP-40838" }
    }

    for _, area in ipairs(referenceAreas) do
      GameApi.ScenEdit_SetReferencePoint({
        side = "China",
        area = area,
        relativeTo = csg.guid,
        bearingtype = 1
      })
    end

    csg.course = config.c.surface.lacm.csg.to.area
  end

  Logger.log("Successfully created CSG")
  return true
end

---Add ships deployed at ports
---@param config SBJ__CONFIG Configuration object
---@param side string Side name
---@return boolean Whether successful
function UnitGenerator.addDeployedShipsAtPort(config, side)
  local field = (side == 'China') and 'c' or 't'

  for _, info in ipairs(config[field].surface.deployedShips) do
    local base = GameApi.ScenEdit_GetUnit(info.baseGUID)

    if base and base.embarkedUnits.Boats then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Boats) do
        GameApi.ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if info.embarkedUnits then
      addEmbarkedUnitsAdvanced(info.embarkedUnits, info.baseGUID)
    end
  end

  Logger.log(string.format("Successfully added deployed ships for %s", side))
  return true
end

---Add submarines
---@param config SBJ__CONFIG Configuration object
---@param side string Side name
---@return boolean Whether successful
function UnitGenerator.addSubmarines(config, side)
  if side ~= 'China' then
    return true -- Currently only supports Chinese submarines
  end

  for _, unit in pairs(config.c.subSurface.slcm.submarines) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.name)

    if actualUnit then
      GameApi.ScenEdit_DeleteUnit({ side = side, guid = actualUnit.guid })
    end

    local addedUnit = createRandomUnits({
      centerPoint = unit.from.startingPoint,
      dbids = { config.platform.TYPE_093B },
      count = 1,
      randomRadius = config.c.subSurface.slcm.randomRadius,
      sideName = side,
      unitType = 'Submarine',
      unitname = unit.name,
      autodetectable = false
    })

    if addedUnit then
      addedUnit.course = unit.course

      -- Remove default weapons and add specified weapons
      GameApi.ScenEdit_AddReloadsToUnit({
        side = side,
        guid = addedUnit.guid,
        wpn_dbid = 2868,
        number = 24,
        remove = true
      })

      GameApi.ScenEdit_AddReloadsToUnit({
        side = side,
        guid = addedUnit.guid,
        wpn_dbid = config.c.subSurface.slcm.weaponDBID,
        number = 8,
      })
    else
      Logger.error(string.format("Failed to create submarine %s", unit.name))
      return false
    end
  end

  Logger.log(string.format("Successfully added submarines for %s", side))
  return true
end

---Initialize C2 facilities
---@param config SBJ__CONFIG Configuration object
---@param saveData SBJ__SaveData Save data
---@return boolean Whether successful
function UnitGenerator.initC2Facilities(config, saveData)
  local units = GameApi.VP_GetSide({ name = 'China' }).units
  saveData.c.IADS.C2 = {}

  for _, setting in ipairs(config.c.IADS.C2Settings) do
    local facilities = {}

    for _, u in ipairs(units) do
      local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)
      if actualUnit then
        for _, area in ipairs(setting.areas) do
          for _, DBID in ipairs(config.c.IADS.C2FacilityDBIDs) do
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
      saveData.c.IADS.C2[facilities[randomIdx].guid] = {
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
  for _, unit in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    for c2Guid, item in pairs(saveData.c.IADS.C2) do
      for _, area in ipairs(item.areas) do
        if actualUnit and actualUnit:inArea(area) then
          -- SAM systems
          if (actualUnit.dbid == config.platform.HQ22 or
                actualUnit.dbid == config.platform.S300 or
                actualUnit.dbid == config.platform.S400 or
                actualUnit.dbid == config.platform.HQ12) and
              not string.find(actualUnit.name, 'DECOY') then
            saveData.c.IADS.C2[c2Guid].SAM[actualUnit.guid] = {
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
            saveData.c.IADS.C2[c2Guid].radar[actualUnit.guid] = {
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

---Add aircraft
---@param config SBJ__CONFIG Configuration object
---@param side string Side name
---@return boolean Whether successful
function UnitGenerator.addAircraft(config, side)
  local key = (side == 'China') and 'c' or 't'

  for _, info in ipairs(config[key].air.landBased.deployedACs) do
    local base = GameApi.ScenEdit_GetUnit(info.baseGUID)

    if not base then
      base = GameApi.ScenEdit_GetUnit(info.name)
    end

    if base and base.embarkedUnits.Aircraft then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Aircraft) do
        GameApi.ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if info.embarkedUnits then
      addEmbarkedUnitsAdvanced(info.embarkedUnits, base.guid)
    end

    if info.loadouts then
      UnitGenerator.removeMagazinesByBaseGUID(base.guid)

      for _, loadout in ipairs(info.loadouts) do
        GameApi.ScenEdit_FillMagsForLoadout({
          unit = info.name,
          loadoutid = loadout.loadoutId,
          quantity = loadout.num
        })
      end
    end
  end

  Logger.log(string.format("Successfully added aircraft for %s", side))
  return true
end

---Remove base magazines
---@param baseGUID string Base GUID
---@return boolean Whether successful
function UnitGenerator.removeMagazinesByBaseGUID(baseGUID)
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

  if base then
    for _, magazine in ipairs(base.magazines) do
      for _, wpn in ipairs(magazine['mag_weapons']) do
        GameApi.ScenEdit_AddWeaponToUnitMagazine({
          guid = baseGUID,
          wpn_dbid = wpn['wpn_dbid'],
          number = 1000,
          remove = true
        })
      end
    end
  end

  return true
end

-- addEmbarkedUnitsAdvanced already defined above

---Add landing ships
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.addLandingShips(config)
  local initialLocations = config.c.PHIBOP.initialLocations
  local shipSettings = config.c.PHIBOP.shipSettings
  local cargoList = config.c.PHIBOP.cargoList

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.from.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]

      -- Calculate starting positions for various ships
      local positions = calculateShipPositions(firstRp075, area.heading.vertical, shipSettings.verticalDistance)

      -- Create various ship types
      createShipsByType(config, positions.type075, area, item, shipSettings, cargoList, 'type075')
      createShipsByType(config, positions.type071, area, item, shipSettings, cargoList, 'type071')
      createShipsByType(config, positions.type076, area, item, shipSettings, cargoList, 'type076')
      createShipsByType(config, positions.barge, area, item, shipSettings, cargoList, 'barge')
      createShipsByType(config, positions.roro, area, item, shipSettings, cargoList, 'roro')
      createShipsByType(config, positions.type072a, area, item, shipSettings, cargoList, 'type072a')
      createShipsByType(config, positions.type072iii, area, item, shipSettings, cargoList, 'type072iii')
      createShipsByType(config, positions.ferry, area, item, shipSettings, cargoList, 'ferry')
      createShipsByType(config, positions.type073a, area, item, shipSettings, cargoList, 'type073a')
    end
  end

  Logger.log("Successfully added landing ships")
  return true
end

---Remove landing ships
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.removeLandingShips(config)
  local unitsFromChina = GameApi.VP_GetSide({ side = 'China' }).units
  local removedCount = 0

  local landingShipDBIDs = {
    config.platform.TYPE_075,
    config.platform.TYPE_071,
    config.platform.TYPE_072III,
    config.platform.TYPE_072A,
    config.platform.TYPE_073A,
    config.platform.TYPE_072A_2,
    config.platform.TYPE_076,
    config.platform.FERRY,
    config.platform.BARGE
  }

  for _, u in ipairs(unitsFromChina) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit then
      for _, dbid in ipairs(landingShipDBIDs) do
        if unit.dbid == dbid then
          GameApi.ScenEdit_DeleteUnit({ side = 'China', guid = unit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(string.format("Removed %d landing ships", removedCount))
  return true
end

---Remove GPS jamming zones
-- -@param config SBJ__CONFIG Configuration object
-- function UnitGenerator.removeJammingZones(config)
--   local s = GameApi.VP_GetSide({ name = 'China' })
--   if s == nil then return end

--   for _, zone in ipairs(s.standardzones) do
--     for _, jammer in ipairs(config.c.GPSJamming.jammers) do
--       if zone.description == jammer.zoneName then
--         local myz = s:getstandardzone(zone.guid)

--         for _, area in ipairs(myz.area) do
--           GameApi.ScenEdit_DeleteReferencePoint({ side = "China", name = area.name })
--         end

--         GameApi.ScenEdit_RemoveZone('China', -925, { Description = myz.description })
--         GameApi.ScenEdit_DeleteUnit({ side = "China", unitname = jammer.name })
--       end
--     end
--   end
-- end

---comment
-- -@param config SBJ__CONFIG
-- function UnitGenerator.addGPSJammingZones(config)
--   for _, jammer in ipairs(config.c.GPSJamming.jammers) do
--     local unit, point = tryAddJammerUnit(config, jammer)

--     if unit and point then
--       GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

--       local area = GameUtils.newArea(point, {
--         side = 'China',
--         shape = 'circle',
--         distance = jammer.radius
--       })

--       local zone = GameApi.ScenEdit_AddZone('China', -925, {
--         description = jammer.zoneName,
--         area = area
--       })

--       if zone then
--         zone.enablers = {
--           GNSS_GLONASS = true,
--           GNSS_GPS = false,
--           GNSS_BeiDou = true,
--           GNSS_NavIC = true
--         }
--       end
--     end
--   end
-- end

return UnitGenerator
