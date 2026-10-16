local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

local UnitGenerator = {}

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

---Calculate formation position
---@param centerPoint CMO__Location
---@param heading number
---@param distance number
---@param angle number
---@return CMO__Location|nil # Calculated position {latitude: number, longitude: number}
local function calculateFormationPosition(centerPoint, heading, distance, angle)
  return GameApi.World_GetPointFromBearing({
    latitude = centerPoint.latitude,
    longitude = centerPoint.longitude,
    bearing = heading + angle,
    distance = distance,
  })
end

---Batch delete units in group
---@param groupName string
---@param sideName string
---@return boolean # Whether cleanup was successful
local function removeExistingGroup(groupName, sideName)
  local group = GameApi.ScenEdit_GetUnit(groupName, sideName)
  if group and group.group and group.group.unitlist then
    for _, guid in ipairs(group.group.unitlist) do
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
    end
  end
  return true
end

---Add embarked units (advanced version, supports mission assignment)
---@param embarkedUnits SBJ__EmbarkedUnit[]
---@param baseGUID string
local function addEmbarkedUnitsAdvanced(embarkedUnits, baseGUID)
  for _, embarkedUnit in ipairs(embarkedUnits) do
    for _, loadout in ipairs(embarkedUnit.loadouts) do
      for i = 1, loadout.num do
        local unitDescriptor = {
          side = embarkedUnit.side,
          type = embarkedUnit.type,
          dbid = embarkedUnit.dbid,
          unitname = embarkedUnit.name .. " #" .. Utils.buildRandomText(3),
          base = baseGUID,
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
---@param params SBJ__LinearPlacementParams
---@param unitDescriptor SBJ__UnitDescriptor
---@param embarkedUnits SBJ__EmbarkedUnit[]|nil
local function addUnitsByRP(params, unitDescriptor, embarkedUnits)
  local locations = GameUtils.buildLocations(params)

  for _, location in ipairs(locations) do
    unitDescriptor.latitude = location.latitude
    unitDescriptor.longitude = location.longitude
    local createdUnit = GameApi.ScenEdit_AddUnit(unitDescriptor)

    if createdUnit and unitDescriptor.cargo then
      if createdUnit.type == constants.UNIT_TYPES.SHIP then
        GameApi.ScenEdit_SetDoctrine(
          { side = createdUnit.side, guid = createdUnit.guid },
          { weapon_control_status_land = constants.WCS.HOLD }
        )
      end

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
---@param firstRp CMO__Location
---@param verticalHeading number
---@param verticalDistance number
---@return table<string, CMO__Location> # Positions of various ship types
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

  positions.type082 = GameApi.World_GetPointFromBearing({
    latitude = positions.type073a.latitude,
    longitude = positions.type073a.longitude,
    bearing = verticalHeading,
    distance = verticalDistance
  })

  return positions
end

---Create ships by type
---@param position CMO__Location
---@param shipType SBJ__AmphibiousShipType
---@param formationCtx SBJ__ShipFormationContext
local function createShipsByType(position, shipType, formationCtx)
  local areaDescriptor, descriptor = formationCtx.areaDescriptor, formationCtx.descriptor
  local shipSettings, cargoMap = formationCtx.shipSettings, formationCtx.cargoMap
  local shipConfigs = {
    type075 = {
      dbid = constants.PLATFORMS.TYPE_075,
      name = "Type 075",
      cargo = cargoMap.type075,
      embarkedUnits = {
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.Z18,       loadouts = { { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 6 }, { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2, num = 6 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.Z10,       loadouts = { { loadoutId = constants.LOADOUTS.Z10_ATTACK, num = 13 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.SHIP,     name = "Warbird",           dbid = constants.PLATFORMS.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    type071 = {
      dbid = constants.PLATFORMS.TYPE_071,
      name = "Type 071",
      cargo = cargoMap.type071,
      embarkedUnits = {
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.Z18,       loadouts = { { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 4 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.SHIP,     name = "Warbird",           dbid = constants.PLATFORMS.TYPE_726A, loadouts = { { loadoutId = 0, num = 4 } } }
      }
    },
    type076 = {
      dbid = constants.PLATFORMS.TYPE_076,
      name = "Type 076",
      cargo = cargoMap.type075,
      embarkedUnits = {
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.Z18,       loadouts = { { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 6 }, { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2, num = 6 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.Z10,       loadouts = { { loadoutId = constants.LOADOUTS.Z10_ATTACK, num = 13 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.AIRCRAFT, name = descriptor.names[1], dbid = constants.PLATFORMS.GJ11,      loadouts = { { loadoutId = constants.LOADOUTS.GJ11_RECON, num = 8 } } },
        { side = constants.SIDES.RED, type = constants.UNIT_TYPES.SHIP,     name = "Warbird",           dbid = constants.PLATFORMS.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    barge = { dbid = constants.PLATFORMS.BARGE, name = "Barge", cargo = nil, embarkedUnits = nil },
    roro = { dbid = constants.PLATFORMS.FERRY, name = "RORO", cargo = cargoMap.barge, embarkedUnits = nil },
    type072a = {
      dbid = constants.PLATFORMS.TYPE_072A,
      name = "Type 072A",
      cargo = cargoMap.type072a,
      embarkedUnits = {
        {
          side = constants.SIDES.RED,
          type = constants.UNIT_TYPES.SHIP,
          name = "Assault Boat",
          dbid = constants.PLATFORMS.ASSAULT_BOAT,
          loadouts = { { loadoutId = 0, num = 2 } }
        }
      }
    },
    type072iii = {
      dbid = constants.PLATFORMS.TYPE_072III,
      name = "Type 072III",
      cargo = cargoMap.type072iii,
      embarkedUnits = {
        {
          side = constants.SIDES.RED,
          type = constants.UNIT_TYPES.SHIP,
          name = "Assault Boat",
          dbid = constants.PLATFORMS.ASSAULT_BOAT,
          loadouts = { { loadoutId = 0, num = 2 } }
        }
      }
    },
    ferry = { dbid = constants.PLATFORMS.FERRY, name = "Ferry", cargo = cargoMap.ferry, embarkedUnits = nil },
    type073a = { dbid = constants.PLATFORMS.TYPE_073A, name = "Type 073A", cargo = cargoMap.type073a, embarkedUnits = nil },
    type082 = {
      dbid = constants.PLATFORMS.TYPE_082,
      name = "Type 082",
      cargo = nil,
      embarkedUnits = nil
    },
  }

  local shipConfig = shipConfigs[shipType]
  if not shipConfig then return end

  ---@type SBJ__LinearPlacementParams
  local params = {
    initialLocation = position,
    bearing = areaDescriptor.heading.horizontal,
    distance = shipSettings.horizontalDistance,
    num = areaDescriptor.shipCounts[shipType]
  }

  local unitDescriptor = {
    side = constants.SIDES.RED,
    type = constants.UNIT_TYPES.SHIP,
    name = shipConfig.name,
    dbid = shipConfig.dbid,
    cargo = shipConfig.cargo,
    heading = areaDescriptor.heading.vertical,
    manualSpeed = shipSettings.shipSpeed,
  }

  addUnitsByRP(params, unitDescriptor, shipConfig.embarkedUnits)
end

---Get SAG formation configuration
---@param sagDescriptor SBJ__SAGDescriptor
---@param sideName string
---@return SBJ__ShipFormationDescriptor[] # Ship formation specification list
local function getSAGShipConfiguration(sagDescriptor, sideName)
  if sideName == constants.SIDES.RED then
    return {
      {
        dbid = sagDescriptor.unitMap.type052d.dbid,
        unitname = "052D",
        distance = 0,
        angle = 0,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitMap.type054a.dbid,
        unitname = "054A",
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitMap.type054a.dbid,
        unitname = "054A",
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = nil
      },
      {
        dbid = sagDescriptor.unitMap.type052d.dbid,
        unitname = "052D",
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.REAR,
        embarkedUnits = nil
      }
    }
  else -- Taiwan
    return {
      {
        dbid = sagDescriptor.unitMap.kidd.dbid,
        unitname = "Keelung",
        distance = 0,
        angle = 0,
        embarkedUnits = sagDescriptor.unitMap.kidd.embarkedUnits
      },
      {
        dbid = sagDescriptor.unitMap.kangDing.dbid,
        unitname = "KangDing",
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.LEFT,
        embarkedUnits = sagDescriptor.unitMap.kangDing.embarkedUnits
      },
      {
        dbid = sagDescriptor.unitMap.kangDing.dbid,
        unitname = "KangDing",
        distance = FORMATION.DISTANCES.CLOSE,
        angle = FORMATION.ANGLES.RIGHT,
        embarkedUnits = sagDescriptor.unitMap.kangDing.embarkedUnits
      }
    }
  end
end

---Get CSG formation configuration
---@param csgDescriptor SBJ__CSGDescriptor
---@return SBJ__ShipFormationDescriptor[] # CSG ship formation specification list
local function getCSGShipConfiguration(csgDescriptor)
  return {
    {
      dbid = csgDescriptor.unitMap.type002.dbid,
      unitname = "002",
      distance = 0,
      angle = 0,
      embarkedUnits = csgDescriptor.unitMap.type002.embarkedUnits,
      loadouts = csgDescriptor.unitMap.type002.loadouts
    },
    {
      dbid = csgDescriptor.unitMap.type901.dbid,
      unitname = "901",
      distance = FORMATION.DISTANCES.MEDIUM,
      angle = FORMATION.ANGLES.REAR,
      embarkedUnits = csgDescriptor.unitMap.type901.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitMap.type055.dbid,
      unitname = "055",
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = csgDescriptor.unitMap.type055.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitMap.type055.dbid,
      unitname = "055",
      distance = FORMATION.DISTANCES.FAR,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = csgDescriptor.unitMap.type055.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitMap.type054a.dbid,
      unitname = "054",
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.LEFT,
      embarkedUnits = csgDescriptor.unitMap.type054a.embarkedUnits
    },
    {
      dbid = csgDescriptor.unitMap.type054a.dbid,
      unitname = "054",
      distance = FORMATION.DISTANCES.CLOSE,
      angle = FORMATION.ANGLES.RIGHT,
      embarkedUnits = csgDescriptor.unitMap.type054a.embarkedUnits
    }
  }
end

---Create formation ships
---@param formationConfig SBJ__SAGFormationConfig
---@return boolean # Whether successful
local function createShipFormation(formationConfig)
  -- Clean up existing group
  removeExistingGroup(formationConfig.groupName, formationConfig.sideName)

  local createdUnits = {}
  local leader = nil

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
      type = constants.UNIT_TYPES.SHIP,
      dbid = shipConfig.dbid,
      group = formationConfig.groupName,
      unitname = shipConfig.unitname,
    }

    local unit = GameUtils.tryCreateUnit(unitDescriptor)
    if unit then
      table.insert(createdUnits, unit)

      if shipConfig.angle == 0 then
        leader = unit
      end

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

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Successfully created formation %s with %d ships",
    formationConfig.groupName, #createdUnits))

  if leader then
    leader.group.lead = leader.guid
    Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Set %s as group leader", leader.guid))
  end

  return true
end

---Create SAG formations
---@param sideName string
---@param sagDescriptorMap table<string, SBJ__SAGDescriptor>
---@return boolean # Whether successful
function UnitGenerator.createSAGs(sideName, sagDescriptorMap)
  for _, sagDescriptor in pairs(sagDescriptorMap) do
    local formationConfig = {
      centerPoint = sagDescriptor.from.pos,
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

    local actualSAG = GameApi.ScenEdit_GetUnit(sagDescriptor.groupName, sideName)
    if actualSAG then
      GameApi.ScenEdit_SetEMCON("Unit", actualSAG.guid, "Radar=Active")
      GameApi.ScenEdit_SetDoctrine(
        { side = actualSAG.side, unitname = actualSAG.name },
        { weapon_control_status_land = constants.WCS.HOLD }
      )

      if sagDescriptor.missionName then
        actualSAG.mission = sagDescriptor.missionName
      end
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Successfully created SAGs for %s", sideName))
  return true
end

---Create CSG formation
---@param csgDescriptor SBJ__CSGDescriptor
---@return boolean # Whether successful
function UnitGenerator.createCSG(csgDescriptor)
  local formationConfig = {
    centerPoint = csgDescriptor.from.pos,
    heading = csgDescriptor.from.heading,
    groupName = csgDescriptor.groupName,
    sideName = constants.SIDES.RED,
    shipTypes = getCSGShipConfiguration(csgDescriptor)
  }

  local success = createShipFormation(formationConfig)
  if not success then
    Logger.error("Failed to create CSG")
    return false
  end

  local csg = GameApi.ScenEdit_GetUnit(csgDescriptor.groupName)
  if csg then
    local referenceAreas = {
      { "RP-40884",  "RP-40885",  "RP-40886",  "RP-40887" },
      { "RP-40830",  "RP-40831",  "RP-40832",  "RP-40833" },
      { "RP-40835",  "RP-40836",  "RP-40837",  "RP-40838" },
      { "RP-198948", "RP-198949", "RP-198950", "RP-198951" },
      { "RP-198952", "RP-198953" }
    }

    for _, area in ipairs(referenceAreas) do
      GameApi.ScenEdit_SetReferencePoint({
        side = constants.SIDES.RED,
        area = area,
        relativeTo = csg.guid,
        bearingtype = 1
      })
    end

    csg.course = csgDescriptor.to.area
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, "Successfully created CSG")
  return true
end

---Add ships deployed at ports
---@param sideName string
---@param descriptors SBJ__AirbaseDeploymentDescriptor
---@return boolean # Whether successful
function UnitGenerator.addDeployedShipsAtPort(sideName, descriptors)
  for _, descriptor in ipairs(descriptors) do
    local base = GameApi.ScenEdit_GetUnit(descriptor.baseGUID)

    if base and base.embarkedUnits.Boats then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Boats) do
        GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = embarkedUnit })
      end
    end

    if descriptor.embarkedUnits then
      addEmbarkedUnitsAdvanced(descriptor.embarkedUnits, descriptor.baseGUID)
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Successfully added deployed ships for %s", sideName))
  return true
end

---Add submarines
---@param config SBJ__Config
---@param sideName string
---@return boolean # Whether successful
function UnitGenerator.addSubmarines(config, sideName)
  if sideName ~= constants.SIDES.RED then
    return true -- Currently only supports Chinese submarines
  end

  for _, unit in pairs(config.red.subSurface.slcm.submarines) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.name, sideName)

    if actualUnit then
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = actualUnit.guid })
    end

    local addedUnit = GameUtils.createRandomUnits({
      centerPoint = unit.from.pos,
      dbids = { constants.PLATFORMS.TYPE_093B },
      count = 1,
      randomRadiusNm = config.red.subSurface.slcm.randomRadiusNm,
      sideName = sideName,
      unitType = constants.UNIT_TYPES.SUBMARINE,
      unitname = unit.name,
      autodetectable = false,
      useRandomSuffix = false
    })

    if addedUnit then
      addedUnit.course = unit.course

      -- Remove default weapons and add specified weapons
      GameApi.ScenEdit_AddReloadsToUnit({
        side = sideName,
        guid = addedUnit.guid,
        wpn_dbid = 2868,
        number = 24,
        remove = true
      })

      GameApi.ScenEdit_AddReloadsToUnit({
        side = sideName,
        guid = addedUnit.guid,
        wpn_dbid = config.red.subSurface.slcm.weaponDBID,
        number = 8,
      })
    else
      Logger.error(string.format("Failed to create submarine %s", unit.name))
      return false
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Successfully added submarines for %s", sideName))
  return true
end

---Remove base magazines
---@param baseGUID string
---@return boolean # Whether successful
local function removeMagazinesByBaseGUID(baseGUID)
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

  if base then
    for _, magazine in ipairs(base.magazines) do
      for _, wpn in ipairs(magazine.mag_weapons) do
        GameApi.ScenEdit_AddWeaponToUnitMagazine({
          side = base.side,
          guid = baseGUID,
          wpn_dbid = wpn.wpn_dbid,
          number = 1000,
          remove = true
        })
      end
    end
  end

  return true
end

---Add aircraft to airbases with specified loadouts and embarked units
---@param airbaseDeploymentDescriptors SBJ__AirbaseDeploymentDescriptor[]
---@return boolean # Whether aircraft addition was successful
function UnitGenerator.addAircraft(airbaseDeploymentDescriptors)
  for _, descriptor in ipairs(airbaseDeploymentDescriptors) do
    local base = GameApi.ScenEdit_GetUnit(descriptor.baseGUID)

    if not base then
      base = GameApi.ScenEdit_GetUnit(descriptor.name)
    end

    if base and base.embarkedUnits.Aircraft then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Aircraft) do
        GameApi.ScenEdit_DeleteUnit({ side = base.side, guid = embarkedUnit })
      end
    end

    if descriptor.embarkedUnits then
      addEmbarkedUnitsAdvanced(descriptor.embarkedUnits, descriptor.baseGUID)
    end

    if descriptor.loadouts then
      removeMagazinesByBaseGUID(descriptor.baseGUID)

      for _, loadout in ipairs(descriptor.loadouts) do
        GameApi.ScenEdit_FillMagsForLoadout({
          unit = descriptor.name,
          loadoutid = loadout.loadoutId,
          quantity = loadout.num
        })
      end
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Successfully added aircraft"))
  return true
end

---Add landing ships
---@param amphibOpsConfig SBJ__AmphibOpsConfig
---@return boolean # Whether successful
function UnitGenerator.addLandingShips(amphibOpsConfig)
  local descriptors = amphibOpsConfig.operations
  local layoutConfig = amphibOpsConfig.formationSettings
  local cargoMap = amphibOpsConfig.cargo

  for _, descriptor in ipairs(descriptors) do
    for _, areaDescriptor in ipairs(descriptor.from.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints({
        side = constants.SIDES.RED, area = areaDescriptor.startingPoints.type075
      })[1]

      local positions = calculateShipPositions(firstRp075, areaDescriptor.heading.vertical, layoutConfig
        .verticalDistance)

      ---@type SBJ__ShipFormationContext
      local formationCtx = {
        areaDescriptor = areaDescriptor,
        descriptor = descriptor,
        shipSettings = layoutConfig,
        cargoMap = cargoMap
      }
      createShipsByType(positions.type075, "type075", formationCtx)
      createShipsByType(positions.type071, "type071", formationCtx)
      createShipsByType(positions.type076, "type076", formationCtx)
      createShipsByType(positions.barge, "barge", formationCtx)
      createShipsByType(positions.roro, "roro", formationCtx)
      createShipsByType(positions.type072a, "type072a", formationCtx)
      createShipsByType(positions.type072iii, "type072iii", formationCtx)
      createShipsByType(positions.ferry, "ferry", formationCtx)
      createShipsByType(positions.type073a, "type073a", formationCtx)
      createShipsByType(positions.type082, "type082", formationCtx)
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, "Successfully added landing ships")
  return true
end

---Remove landing ships
---@return boolean # Whether successful
function UnitGenerator.removeLandingShips()
  local filteredUnits = GameApi.VP_GetSide({ side = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.SHIP)

  if not filteredUnits then
    return false
  end

  local removedCount = 0

  local landingShipDBIDs = {
    constants.PLATFORMS.TYPE_075,
    constants.PLATFORMS.TYPE_071,
    constants.PLATFORMS.TYPE_072III,
    constants.PLATFORMS.TYPE_072A,
    constants.PLATFORMS.TYPE_073A,
    constants.PLATFORMS.TYPE_072A_2,
    constants.PLATFORMS.TYPE_076,
    constants.PLATFORMS.FERRY,
    constants.PLATFORMS.BARGE,
    constants.PLATFORMS.TYPE_082
  }

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit then
      for _, dbid in ipairs(landingShipDBIDs) do
        if unit.dbid == dbid then
          GameApi.ScenEdit_DeleteUnit({ side = constants.SIDES.RED, guid = unit.guid })
          removedCount = removedCount + 1
          break
        end
      end
    end
  end

  Logger.log(constants.TAGS.UNIT_GENERATOR, string.format("Removed %d landing ships", removedCount))
  return true
end

return UnitGenerator
