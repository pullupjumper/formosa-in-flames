local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

---@class UnitGenerator
local UnitGenerator = {}

-- ============================================================================
-- Module-private type definitions
-- ============================================================================

---Ship formation specification - defines a single ship's configuration within a formation
---Used to specify ship positioning, armament, and embarked units in naval groups
---@class UnitGenerator_ShipFormationSpec
---@field dbid number Ship platform database ID
---@field unitname string Ship unit name
---@field distance number Distance from formation center (nautical miles)
---@field angle number Angle offset from formation heading (degrees)
---@field embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked aircraft/boats (optional)
---@field loadouts SBJ__Loadout[]|nil Ammunition stockpile configuration (optional)


---Formation configuration for internal ship creation
---Used internally by createShipFormation() to configure ship group formations
---@class UnitGenerator_FormationConfig
---@field centerPoint {lat:number, lon:number} Formation center point coordinates
---@field heading number Formation heading angle
---@field groupName string Ship group name
---@field sideName string Side name (e.g., 'China', 'Taiwan')
---@field unitTypes UnitGenerator_ShipFormationSpec[] Array of ship configurations to create

---@alias UnitGenerator_UnitType
---| '"type075"'
---| '"type071"'
---| '"type076"'
---| '"type072iii"'
---| '"type072a"'
---| '"type073a"'
---| '"ferry"'
---| '"barge"'
---| '"roro"'

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
---@param params SBJ__LinearPlacementParams Linear placement parameters
---@param unitDescriptor CMO__SetUnitDescriptor Unit descriptor
---@param embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked units
local function addUnitsByRP(params, unitDescriptor, embarkedUnits)
  local locations = GameUtils.generateLocations(params)

  for _, location in ipairs(locations) do
    unitDescriptor.latitude = location.latitude
    unitDescriptor.longitude = location.longitude
    local createdUnit = GameApi.ScenEdit_AddUnit(unitDescriptor)

    if createdUnit and unitDescriptor.cargo then
      for _, cargoItem in ipairs(unitDescriptor.cargo) do
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
---@param areaDescriptor SBJ__AmphibiousAreaDescriptor Area configuration
---@param descriptor SBJ__AmphibOpsDescriptor Item configuration
---@param shipSettings SBJ__AmphibiousLayoutConfig Amphibious layout configuration
---@param cargoList table<string, SBJ__CargoDescriptor[]> Cargo list
---@param shipType UnitGenerator_UnitType Ship type
local function createShipsByType(config, position, areaDescriptor, descriptor, shipSettings, cargoList, shipType)
  local shipConfigs = {
    type075 = {
      dbid = config.platform.TYPE_075,
      name = 'Type 075',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.Z10,       loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',           dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    type071 = {
      dbid = config.platform.TYPE_071,
      name = 'Type 071',
      cargo = cargoList.type071,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 4 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',           dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 4 } } }
      }
    },
    type076 = {
      dbid = config.platform.TYPE_076,
      name = 'Type 076',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.Z18,       loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.Z10,       loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'aircraft', name = descriptor.names[1], dbid = config.platform.GJ11,      loadouts = { { loadoutId = config.loadout.GJ11_RECON, num = 8 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',           dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
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
    bearing = areaDescriptor.heading.horizontal,
    distance = shipSettings.horizontalDistance,
    num = descriptor.from.num[shipType]
  }

  local unitDescriptor = {
    side = 'China',
    type = 'Ship',
    name = shipConfig.name,
    dbid = shipConfig.dbid,
    cargo = shipConfig.cargo,
    heading = areaDescriptor.heading.vertical,
    manualSpeed = shipSettings.shipSpeed,
  }

  addUnitsByRP(params, unitDescriptor, shipConfig.embarkedUnits)
end

-- ============================================================================
-- Formation configuration factory - Configuration-driven design
-- ============================================================================


---Get SAG formation configuration
---@param sagDescriptor SBJ__SAGDescriptor Configuration object
---@param sideName string Side name ('China' | 'Taiwan')
---@return UnitGenerator_ShipFormationSpec[] Ship formation specification list
local function getSAGShipConfiguration(sagDescriptor, sideName)
  if sideName == 'China' then
    return {
      {
        dbid = sagDescriptor.unitList.type052d.dbid,
        unitname = '052D',
        distance = 0,
        angle = 0,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitList.type054a.dbid,
        unitname = '054A',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitList.type054a.dbid,
        unitname = '054A',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitList.type052d.dbid,
        unitname = '052D',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.REAR,
        embarkedUnits = nil
      }
    }
  else -- Taiwan
    return {
      {
        dbid = sagDescriptor.unitList.kidd.dbid,
        unitname = 'Keelung',
        distance = 0,
        angle = 0,
        embarkedUnits = nil -- Embarked units handled separately during creation
      },
      {
        dbid = sagDescriptor.unitList.kangDing.dbid,
        unitname = 'KangDing',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitList.kangDing.dbid,
        unitname = 'KangDing',
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = nil
      }
    }
  end
end

---Get CSG formation configuration
---@param csgDescriptor SBJ__CSGDescriptor Configuration object
---@return UnitGenerator_ShipFormationSpec[] CSG ship formation specification list
local function getCSGShipConfiguration(csgDescriptor)
  return {
    {
      dbid = csgDescriptor.unitList.type002.dbid,
      unitname = '002',
      distance = 0,
      angle = 0,
      embarkedUnits = csgDescriptor.unitList.type002.embarkedUnits,
      loadouts = csgDescriptor.unitList.type002.loadouts
    },
    {
      dbid = csgDescriptor.unitList.type901.dbid,
      unitname = '901',
      distance = FORMATION.DISTANCES.MEDIUM,
      angle = FORMATION.ANGLES.REAR,
      embarkedUnits = csgDescriptor.unitList.type901.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitList.type055.dbid,
      unitname = '055',
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = csgDescriptor.unitList.type055.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitList.type055.dbid,
      unitname = '055',
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = csgDescriptor.unitList.type055.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitList.type054a.dbid,
      unitname = '054',
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = csgDescriptor.unitList.type054a.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitList.type054a.dbid,
      unitname = '054',
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = csgDescriptor.unitList.type054a.embarkedUnits
    }
  }
end

---Create formation ships
---@param formationConfig UnitGenerator_FormationConfig Formation configuration
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

    local unit = GameUtils.tryCreateUnit(unitDescriptor)
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

-- ============================================================================
-- Main functionality functions - Refactored version
-- ============================================================================

---Create SAG formations
---@param sagDescriptors table<string, SBJ__SAGDescriptor> Configuration object
---@param sideName string Side name
---@return boolean Whether successful
function UnitGenerator.createSAGs(sagDescriptors, sideName)
  for _, sagDescriptor in pairs(sagDescriptors) do
    local formationConfig = {
      centerPoint = sagDescriptor.from.startingPoint,
      heading = sagDescriptor.from.heading,
      groupName = sagDescriptor.groupName,
      sideName = sideName,
      shipTypes = getSAGShipConfiguration(sagDescriptor, sideName)
    }

    local success = createShipFormation(formationConfig)
    if not success then
      Logger.error(string.format("Failed to create SAG %s", sagDescriptor.groupName))
      return false
    end

    -- Handle embarked units separately (for Taiwan)
    if sideName == 'Taiwan' then
      local group = GameApi.ScenEdit_GetUnit(sagDescriptor.groupName)
      if group and group.group and group.group.unitlist then
        for i, unitGuid in ipairs(group.group.unitlist) do
          local unit = GameApi.ScenEdit_GetUnit(unitGuid)
          if unit then
            if unit.name:find('Keelung') and sagDescriptor.unitList and sagDescriptor.unitList.kidd then
              addEmbarkedUnitsAdvanced(sagDescriptor.unitList.kidd.embarkedUnits, unit.guid)
            elseif unit.name:find('KangDing') and sagDescriptor.unitList and sagDescriptor.unitList.kangDing then
              addEmbarkedUnitsAdvanced(sagDescriptor.unitList.kangDing.embarkedUnits, unit.guid)
            end
          end
        end
      end
    end

    -- Set radar status
    local group = GameApi.ScenEdit_GetUnit(sagDescriptor.groupName)
    if group then
      GameApi.ScenEdit_SetEMCON('Unit', group.guid, 'Radar=Active')
    end

    -- Set mission (for Taiwan)
    if sideName == 'Taiwan' and sagDescriptor.missionName then
      local kidd = GameApi.ScenEdit_GetUnit(sagDescriptor.groupName)
      if kidd then
        kidd.mission = sagDescriptor.missionName
      end
    end
  end

  Logger.log(string.format("Successfully created SAGs for %s", sideName))
  return true
end

---Create CSG formation
---@param csgDescriptor SBJ__CSGDescriptor Configuration object
---@return boolean Whether successful
function UnitGenerator.createCSG(csgDescriptor)
  local formationConfig = {
    centerPoint = csgDescriptor.from.startingPoint,
    heading = csgDescriptor.from.heading,
    groupName = csgDescriptor.groupName,
    sideName = 'China',
    shipTypes = getCSGShipConfiguration(csgDescriptor)
  }

  local success = createShipFormation(formationConfig)
  if not success then
    Logger.error("Failed to create CSG")
    return false
  end

  -- Set reference points
  local csg = GameApi.ScenEdit_GetUnit(csgDescriptor.groupName)
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

    csg.course = csgDescriptor.to.area
  end

  Logger.log("Successfully created CSG")
  return true
end

---Add ships deployed at ports
---@param descriptors SBJ__AirbaseDeploymentDescriptor Configuration object
---@param sideName string Side name
---@return boolean Whether successful
function UnitGenerator.addDeployedShipsAtPort(descriptors, sideName)
  -- local field = (sideName == 'China') and 'c' or 't'

  for _, descriptor in ipairs(descriptors) do
    local base = GameApi.ScenEdit_GetUnit(descriptor.baseGUID)

    if base and base.embarkedUnits.Boats then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Boats) do
        GameApi.ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if descriptor.embarkedUnits then
      addEmbarkedUnitsAdvanced(descriptor.embarkedUnits, descriptor.baseGUID)
    end
  end

  Logger.log(string.format("Successfully added deployed ships for %s", sideName))
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

    local addedUnit = GameUtils.createRandomUnits({
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

---comment
---@param airbaseDeploymentDescriptors SBJ__AirbaseDeploymentDescriptor[]
---@param sideName string
---@return boolean
function UnitGenerator.addAircraft(airbaseDeploymentDescriptors, sideName)
  for _, data in ipairs(airbaseDeploymentDescriptors) do
    local base = GameApi.ScenEdit_GetUnit(data.baseGUID)

    if not base then
      base = GameApi.ScenEdit_GetUnit(data.name)
    end

    if base and base.embarkedUnits.Aircraft then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Aircraft) do
        GameApi.ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if data.embarkedUnits then
      addEmbarkedUnitsAdvanced(data.embarkedUnits, data.baseGUID)
    end

    if data.loadouts then
      UnitGenerator.removeMagazinesByBaseGUID(data.baseGUID)

      for _, loadout in ipairs(data.loadouts) do
        GameApi.ScenEdit_FillMagsForLoadout({
          unit = data.name,
          loadoutid = loadout.loadoutId,
          quantity = loadout.num
        })
      end
    end
  end

  Logger.log(string.format("Successfully added aircraft for %s", sideName))
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
---@param amphibOpsConfig SBJ__AmphibOpsConfig
---@return boolean Whether successful
function UnitGenerator.addLandingShips(config, amphibOpsConfig)
  local descriptors = amphibOpsConfig.initialLocations
  local layoutConfig = amphibOpsConfig.shipSettings
  local cargoList = amphibOpsConfig.cargoList

  for _, descriptor in ipairs(descriptors) do
    for _, areaDescriptor in ipairs(descriptor.from.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(areaDescriptor.startingPoints.type075)[1]

      -- Calculate starting positions for various ships
      local positions = calculateShipPositions(
        firstRp075, areaDescriptor.heading.vertical, layoutConfig.verticalDistance)

      -- Create various ship types
      createShipsByType(config, positions.type075, areaDescriptor, descriptor, layoutConfig, cargoList, 'type075')
      createShipsByType(config, positions.type071, areaDescriptor, descriptor, layoutConfig, cargoList, 'type071')
      createShipsByType(config, positions.type076, areaDescriptor, descriptor, layoutConfig, cargoList, 'type076')
      createShipsByType(config, positions.barge, areaDescriptor, descriptor, layoutConfig, cargoList, 'barge')
      createShipsByType(config, positions.roro, areaDescriptor, descriptor, layoutConfig, cargoList, 'roro')
      createShipsByType(config, positions.type072a, areaDescriptor, descriptor, layoutConfig, cargoList, 'type072a')
      createShipsByType(config, positions.type072iii, areaDescriptor, descriptor, layoutConfig, cargoList, 'type072iii')
      createShipsByType(config, positions.ferry, areaDescriptor, descriptor, layoutConfig, cargoList, 'ferry')
      createShipsByType(config, positions.type073a, areaDescriptor, descriptor, layoutConfig, cargoList, 'type073a')
    end
  end

  Logger.log("Successfully added landing ships")
  return true
end

---Remove landing ships
---@param config SBJ__CONFIG Configuration object
---@return boolean Whether successful
function UnitGenerator.removeLandingShips(config)
  local unitsFromChina = GameApi.VP_GetSide({ side = 'China' }):unitsBy(config.unitType.SHIP)

  if not unitsFromChina then
    return false
  end

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
