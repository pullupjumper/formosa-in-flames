local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

function RemoveC2Facilities()
  local units = VP_GetSide({ name = 'China' }).units

  for _, u in ipairs(units) do
    local unit = SE_GetUnit({ guid = u.guid })
    if unit == nil then goto continue end

    for _, DBID in ipairs(CONFIG.c.IADS.C2FacilityDBIDs) do
      if unit.dbid == DBID then
        ScenEdit_DeleteUnit({ side = 'China', guid = unit.guid })
      end
    end

    ::continue::
  end
end

function CreateRandomUnits(centerPoint, dbids, count, randomRadius, sideName, unitType, unitname, autodetectable)
  local units = {}

  local function TryCreateUnit(attempt, max_attempts)
    local dbid = dbids[math.random(#dbids)]
    local point = GameUtils.CircularRandomPosition(centerPoint.lat, centerPoint.lon, randomRadius)

    local unit = ScenEdit_AddUnit({
      type = unitType,
      dbid = dbid,
      side = sideName,
      Lat = point.latitude,
      Lon = point.longitude,
      autodetectable = autodetectable,
      unitname = unitname .. Utils.RandomTxt(2),
    })

    if unit then
      return unit
    elseif attempt < max_attempts then
      return TryCreateUnit(attempt + 1, max_attempts)
    else
      print("Failed to create unit with dbid " .. dbid .. " after " .. max_attempts .. " attempts.")
      return nil
    end
  end

  for i = 1, count do
    local unit = TryCreateUnit(1, 50)
    if unit then
      table.insert(units, unit)
      if count == 1 then return unit end
    end
  end

  return units
end

function ADDC2Facilities()
  for _, setting in ipairs(CONFIG.c.IADS.C2Settings) do
    CreateRandomUnits(
      setting.position,
      CONFIG.c.IADS.C2FacilityDBIDs,
      3,
      CONFIG.c.IADS.randomRadius,
      'China',
      'Facility',
      "Suspected C2 Facility#",
      true
    )
  end
end

function InitC2Facilities(saveData)
  local units = VP_GetSide({ name = 'China' }).units
  saveData.c.IADS.C2 = {}

  for _, setting in ipairs(CONFIG.c.IADS.C2Settings) do
    local facilities = {}

    for _, u in ipairs(units) do
      local actualUnit = ScenEdit_GetUnit({ guid = u.guid })
      if actualUnit == nil then goto continue end

      for _, area in ipairs(setting.areas) do
        for _, DBID in ipairs(CONFIG.c.IADS.C2FacilityDBIDs) do
          if actualUnit.dbid == DBID and actualUnit:inArea(area) then
            table.insert(facilities, actualUnit)
            break
          end
        end
      end
      ::continue::
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

  for _, unit in ipairs(units) do
    local actualUnit = SE_GetUnit({ guid = unit.guid })

    for c2Guid, item in pairs(saveData.c.IADS.C2) do
      for _, area in ipairs(item.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if (actualUnit.dbid == CONFIG.platformDBID18
                or actualUnit.dbid == CONFIG.platformDBID19
                or actualUnit.dbid == CONFIG.platformDBID20
                or actualUnit.dbid == CONFIG.platformDBID21) and
              string.find(actualUnit.name, 'DECOY') == nil then
            local data = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }

            saveData.c.IADS.C2[c2Guid].SAM[actualUnit.guid] = data
          end

          if actualUnit.dbid == CONFIG.platformDBID16 or actualUnit.dbid == CONFIG.platformDBID17 then
            local data = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }

            saveData.c.IADS.C2[c2Guid].radar[actualUnit.guid] = data
          end
        end
      end
    end
  end
end

function RemoveMagazinesByBaseGUID(baseGUID)
  local base = SE_GetUnit({ guid = baseGUID })

  if base then
    for _, magazine in ipairs(base.magazines) do
      for _, wpn in ipairs(magazine['mag_weapons']) do
        ScenEdit_AddWeaponToUnitMagazine({
          guid = baseGUID,
          wpn_dbid = wpn['wpn_dbid'],
          number = 1000,
          remove = true
        })
      end
    end
  end
end

function AddEmbarkedUnits(embarkedUnits, base)
  for _, embarkedUnit in ipairs(embarkedUnits) do
    for _, loadout in ipairs(embarkedUnit.loadouts) do
      for i = 1, loadout.num, 1 do
        local unit = nil

        if loadout.loadoutId == 0 then
          unit = ScenEdit_AddUnit({
            side     = embarkedUnit.side,
            type     = embarkedUnit.type,
            dbid     = embarkedUnit.dbid,
            unitname = embarkedUnit.name .. ' #' .. Utils.RandomTxt(2),
            base     = base,
          })
        else
          unit = ScenEdit_AddUnit({
            side      = embarkedUnit.side,
            type      = embarkedUnit.type,
            dbid      = embarkedUnit.dbid,
            unitname  = embarkedUnit.name .. ' #' .. Utils.RandomTxt(2),
            base      = base,
            loadoutid = loadout.loadoutId
          })
        end

        if unit and loadout.missionName then
          ScenEdit_AssignUnitToMission(unit.guid, loadout.missionName)
        end
      end
    end
  end
end

function AddACs(side)
  local key = (side == 'China') and 'c' or 't'

  for _, info in ipairs(CONFIG[key].air.landBased.deployedACs) do
    local base = SE_GetUnit({ guid = info.baseGUID })

    if not base then
      base = SE_GetUnit({ side = side, unitname = info.name })
    end

    if base and base.embarkedUnits.Aircraft then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Aircraft) do
        ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if info.embarkedUnits then
      AddEmbarkedUnits(info.embarkedUnits, base.guid)
    end

    if info.loadouts then
      RemoveMagazinesByBaseGUID(base.guid)

      for _, loadout in ipairs(info.loadouts) do
        ScenEdit_FillMagsForLoadout({ unit = info.name, loadoutid = loadout.loadoutId, quantity = loadout.num })
      end
    end
  end
end

function AddSAGs(side)
  if side == 'China' then
    for _, value in pairs(CONFIG.c.PHIBOP.sag) do
      local sag = SE_GetUnit({ side = 'China', unitname = value.groupName })

      if sag then
        for index, guid in ipairs(sag.group.unitlist) do
          ScenEdit_DeleteUnit({ side = "China", guid = guid })
        end
      end

      local pl = World_GetPointFromBearing({
        LATITUDE = value.from.startingPoint.lat,
        LONGITUDE = value.from.startingPoint.lon,
        BEARING = value.from.heading + 45,
        DISTANCE = 1.5,
      })

      local pr = World_GetPointFromBearing({
        LATITUDE = value.from.startingPoint.lat,
        LONGITUDE = value.from.startingPoint.lon,
        BEARING = value.from.heading - 45,
        DISTANCE = 1.5,
      })

      local pc = World_GetPointFromBearing({
        LATITUDE = value.from.startingPoint.lat,
        LONGITUDE = value.from.startingPoint.lon,
        BEARING = value.from.heading - 180,
        DISTANCE = 1.5,
      })

      ScenEdit_AddUnit({
        latitude  = value.from.startingPoint.lat,
        longitude = value.from.startingPoint.lon,
        heading   = value.from.heading,
        side      = 'China',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID48,
        group     = value.groupName,
        unitname  = '052D',
      })
      ScenEdit_AddUnit({
        latitude  = pl.latitude,
        longitude = pl.longitude,
        heading   = value.from.heading,
        side      = 'China',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID49,
        group     = value.groupName,
        unitname  = '054A',
      })
      ScenEdit_AddUnit({
        latitude  = pr.latitude,
        longitude = pr.longitude,
        heading   = value.from.heading,
        side      = 'China',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID49,
        group     = value.groupName,
        unitname  = '054A',
      })
      ScenEdit_AddUnit({
        latitude  = pc.latitude,
        longitude = pc.longitude,
        heading   = value.from.heading,
        side      = 'China',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID48,
        group     = value.groupName,
        unitname  = '052D',
      })

      local addedSAG = SE_GetUnit({ side = 'China', unitname = value.groupName })

      if addedSAG then
        ScenEdit_SetEMCON('Unit', addedSAG.guid, 'Radar=Active')
      end
    end
  else
    for _, value in pairs(CONFIG.t.surface.sag) do
      local sag = SE_GetUnit({ side = 'Taiwan', unitname = value.groupName })

      if sag then
        for index, guid in ipairs(sag.group.unitlist) do
          ScenEdit_DeleteUnit({ side = "Taiwan", guid = guid })
        end
      end

      local pl = World_GetPointFromBearing({
        LATITUDE = value.from.startingPoint.lat,
        LONGITUDE = value.from.startingPoint.lon,
        BEARING = value.from.heading + 45,
        DISTANCE = 1.5,
      })

      local pr = World_GetPointFromBearing({
        LATITUDE = value.from.startingPoint.lat,
        LONGITUDE = value.from.startingPoint.lon,
        BEARING = value.from.heading - 45,
        DISTANCE = 1.5,
      })

      local kidd = ScenEdit_AddUnit({
        latitude  = value.from.startingPoint.lat,
        longitude = value.from.startingPoint.lon,
        heading   = value.from.heading,
        side      = 'Taiwan',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID73,
        group     = value.groupName,
        unitname  = 'Keelung',
      })

      local kangDing1 = ScenEdit_AddUnit({
        latitude  = pl.latitude,
        longitude = pl.longitude,
        heading   = value.from.heading,
        side      = 'Taiwan',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID74,
        group     = value.groupName,
        unitname  = 'KangDing',
      })
      local kangDing2 = ScenEdit_AddUnit({
        latitude  = pr.latitude,
        longitude = pr.longitude,
        heading   = value.from.heading,
        side      = 'Taiwan',
        type      = 'Ship',
        dbid      = CONFIG.platformDBID74,
        group     = value.groupName,
        unitname  = 'KangDing',
      })

      if kidd then
        AddEmbarkedUnits(value.unitList.kidd.embarkedUnits, kidd.guid)
        kidd.mission = value.missionName
      end

      if kangDing1 then
        AddEmbarkedUnits(value.unitList.kangDing.embarkedUnits, kangDing1.guid)
      end

      if kangDing2 then
        AddEmbarkedUnits(value.unitList.kangDing.embarkedUnits, kangDing2.guid)
      end
    end
  end
end

function AddCSG()
  local csg = SE_GetUnit({ side = 'China', unitname = CONFIG.c.surface.lacm.csg.groupName })

  if csg then
    for index, guid in ipairs(csg.group.unitlist) do
      ScenEdit_DeleteUnit({ side = "China", guid = guid })
    end
  end

  local pl054 = World_GetPointFromBearing({
    LATITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    LONGITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    BEARING = CONFIG.c.surface.lacm.csg.from.heading - 45,
    DISTANCE = 4.5,
  })
  local pr054 = World_GetPointFromBearing({
    LATITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    LONGITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    BEARING = CONFIG.c.surface.lacm.csg.from.heading + 45,
    DISTANCE = 4.5,
  })
  local p901 = World_GetPointFromBearing({
    LATITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    LONGITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    BEARING = CONFIG.c.surface.lacm.csg.from.heading - 180,
    DISTANCE = 4.5,
  })
  local pl055 = World_GetPointFromBearing({
    LATITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    LONGITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    BEARING = CONFIG.c.surface.lacm.csg.from.heading - 45,
    DISTANCE = 20,
  })
  local pr055 = World_GetPointFromBearing({
    LATITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    LONGITUDE = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    BEARING = CONFIG.c.surface.lacm.csg.from.heading + 45,
    DISTANCE = 20,
  })

  local _002 = ScenEdit_AddUnit({
    latitude  = CONFIG.c.surface.lacm.csg.from.startingPoint.lat,
    longitude = CONFIG.c.surface.lacm.csg.from.startingPoint.lon,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type002.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '002',
  })

  if _002 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type002.embarkedUnits, _002.guid)

    if CONFIG.c.surface.lacm.csg.unitList.type002.loadouts then
      for _, loadout in ipairs(CONFIG.c.surface.lacm.csg.unitList.type002.loadouts) do
        ScenEdit_FillMagsForLoadout({ unit = _002.name, loadoutid = loadout.loadoutId, quantity = loadout.num })
      end
    end
  end

  local _901 = ScenEdit_AddUnit({
    latitude  = p901.latitude,
    longitude = p901.longitude,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type901.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '901',
  })

  if _901 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type901.embarkedUnits, _901.guid)
  end

  local _l055 = ScenEdit_AddUnit({
    latitude  = pl055.latitude,
    longitude = pl055.longitude,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type055.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '055',
  })

  if _l055 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type055.embarkedUnits, _l055.guid)
  end

  local _r055 = ScenEdit_AddUnit({
    latitude  = pr055.latitude,
    longitude = pr055.longitude,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type055.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '055',
  })

  if _r055 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type055.embarkedUnits, _r055.guid)
  end

  local _l054 = ScenEdit_AddUnit({
    latitude  = pl054.latitude,
    longitude = pl054.longitude,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type054a.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '054',
  })
  if _l054 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type054a.embarkedUnits, _l054.guid)
  end

  local _r054 = ScenEdit_AddUnit({
    latitude  = pr054.latitude,
    longitude = pr054.longitude,
    heading   = CONFIG.c.surface.lacm.csg.from.heading,
    side      = 'China',
    type      = 'Ship',
    dbid      = CONFIG.c.surface.lacm.csg.unitList.type054a.dbid,
    group     = CONFIG.c.surface.lacm.csg.groupName,
    unitname  = '054',
  })
  if _r054 then
    AddEmbarkedUnits(CONFIG.c.surface.lacm.csg.unitList.type054a.embarkedUnits, _r054.guid)
  end

  local _csg = SE_GetUnit({ side = "China", unitname = CONFIG.c.surface.lacm.csg.groupName })

  if _csg then
    ScenEdit_SetReferencePoint({
      side = "China",
      area = { "RP-40884", "RP-40885", "RP-40886", "RP-40887" },
      relativeTo = _csg.guid,
      bearingtype = 1
    })
    ScenEdit_SetReferencePoint({
      side = "China",
      area = { "RP-40830", "RP-40831", "RP-40832", "RP-40833" },
      relativeTo = _csg.guid,
      bearingtype = 1
    })
    ScenEdit_SetReferencePoint({
      side = "China",
      area = { "RP-40835", "RP-40836", "RP-40837", "RP-40838" },
      relativeTo = _csg.guid,
      bearingtype = 1
    })

    _csg.course = CONFIG.c.surface.lacm.csg.to.area
  end
end

function AddDeployedShipsAtPort(side)
  local key = (side == 'China') and 'c' or 't'

  for _, info in ipairs(CONFIG[key].surface.deployedShips) do
    local base = SE_GetUnit({ guid = info.baseGUID })

    if base and base.embarkedUnits.Boats then
      for _, embarkedUnit in ipairs(base.embarkedUnits.Boats) do
        ScenEdit_DeleteUnit({ side = embarkedUnit.side, guid = embarkedUnit })
      end
    end

    if info.embarkedUnits then
      AddEmbarkedUnits(info.embarkedUnits, info.baseGUID)
    end
  end
end

function AddSubmarines(side)
  local key = (side == 'China') and 'c' or 't'

  if side == 'China' then
    for _, unit in pairs(CONFIG.c.subSurface.slcm.submarines) do
      local actualUnit = SE_GetUnit({ side = side, unitname = unit.name })

      if actualUnit then
        ScenEdit_DeleteUnit({ side = side, guid = actualUnit.guid })
      end

      local addedUnit = CreateRandomUnits(
        unit.from.startingPoint,
        { CONFIG.platformDBID77 },
        1,
        CONFIG.c.subSurface.slcm.randomRadius,
        side,
        'Submarine',
        unit.name,
        false
      )

      if addedUnit then
        addedUnit.course = unit.course
        -- SE_SetUnit({ guid = addedUnit.guid, desiredDepth = -300 })

        ScenEdit_AddReloadsToUnit({
          side = side,
          guid = addedUnit.guid,
          wpn_dbid = 2868,
          number = 24,
          remove = true
        })

        ScenEdit_AddReloadsToUnit({
          side = side,
          guid = addedUnit.guid,
          wpn_dbid = CONFIG.c.subSurface.slcm.weaponDBID,
          number = 8,
        })
      end
    end
  end
end

---@class EmbarkedUnit
---@field num number
---@field setUnitDescriptor CMO__SetUnitDescriptor

---@param shipId string
---@param mutipledUnitSetting table<number, EmbarkedUnit>
function AddUnitsToShip(shipId, mutipledUnitSetting)
  for k, unitSetting in ipairs(mutipledUnitSetting) do
    -- local name = unitSetting.setUnitDescriptor.name

    for j = 1, unitSetting.num, 1 do
      unitSetting.setUnitDescriptor.base = shipId
      -- unitSetting.setUnitDescriptor.name = name .. ' #' .. j
      ScenEdit_AddUnit(unitSetting.setUnitDescriptor)
    end
  end
end

---@param params SBJ__Location_Params
---@param unit CMO__Unit
---@param embarkedUnits table<number, EmbarkedUnit>|nil
function AddUnitsByRP(params, unit, embarkedUnits)
  local locations = GameUtils.GenerateLocations(params)
  local unitTemp = nil

  for k, v in ipairs(locations) do
    unit.latitude = v.latitude
    unit.longitude = v.longitude
    unitTemp = ScenEdit_AddUnit(unit)

    if unitTemp and unit.cargo then
      for key, cargoItem in ipairs(unit.cargo) do
        for i = 1, cargoItem.num, 1 do
          unitTemp:createUnitCargo(cargoItem.type, cargoItem.dbid)
        end
      end

      if embarkedUnits then
        AddUnitsToShip(unitTemp.guid, embarkedUnits)
      end
    end
  end
end

---@param params SBJ__Location_Params
---@return table<number, CMO__Location>
function GetPointFromBearing(params)
  local initialLocation = params.initialLocation
  local bearing = params.bearing
  local distance = params.distance

  return GameUtils.GenerateLocations({
    initialLocation = initialLocation,
    num = 2,
    bearing = bearing,
    distance = distance
  })[2]
end

function AddLandingShips()
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local cargoList = CONFIG.c.PHIBOP.cargoList

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.from.areas) do
      local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = GetPointFromBearing({
        initialLocation = firstRp075,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp076 = GetPointFromBearing({
        initialLocation = firstRp071,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpBarge = GetPointFromBearing({
        initialLocation = firstRp076,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpRORO = GetPointFromBearing({
        initialLocation = firstRpBarge,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072a = GetPointFromBearing({
        initialLocation = firstRpRORO,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072iii = GetPointFromBearing({
        initialLocation = firstRp072a,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      local firstRpFerry = GetPointFromBearing({
        initialLocation = firstRp072iii,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      local firstRp073a = GetPointFromBearing({
        initialLocation = firstRpFerry,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      AddUnitsByRP(
        {
          initialLocation = firstRp075,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type075
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 075',
          dbid = CONFIG.platformDBID6,
          cargo = cargoList.type075,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          {
            num = 6,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID2,
              loadoutid = CONFIG.loadoutDBID3
            }
          },
          {
            num = 6,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID2,
              loadoutid = CONFIG.loadoutDBID4
            }
          },
          {
            num = 13,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID5,
              loadoutid = CONFIG.loadoutDBID2
            }
          },
          { num = 3, setUnitDescriptor = { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp071,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type071
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 071',
          dbid = CONFIG.platformDBID7,
          cargo = cargoList.type071,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          {
            num = 4,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID2,
              loadoutid = CONFIG.loadoutDBID3
            }
          },
          { num = 4, setUnitDescriptor = { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp076,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type076
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 076',
          dbid = CONFIG.platformDBID54,
          cargo = cargoList.type075,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          {
            num = 6,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID2,
              loadoutid = CONFIG.loadoutDBID3
            }
          },
          {
            num = 6,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID2,
              loadoutid = CONFIG.loadoutDBID4
            }
          },
          {
            num = 13,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID5,
              loadoutid = CONFIG.loadoutDBID2
            }
          },
          {
            num = 8,
            setUnitDescriptor = {
              side = 'China',
              type = 'aircraft',
              name = item.names[1],
              dbid = CONFIG.platformDBID55,
              loadoutid = CONFIG.loadoutDBID6
            }
          },
          { num = 3, setUnitDescriptor = { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpBarge,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.barge
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Barge',
          dbid = CONFIG.platformDBID72,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpRORO,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.roro
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'RORO',
          dbid = CONFIG.platformDBID56,
          cargo = cargoList.barge,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp072a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type072a
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 072A',
          dbid = CONFIG.platformDBID9,
          cargo = cargoList.type072a,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp072iii,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type072iii
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 072III',
          dbid = CONFIG.platformDBID8,
          cargo = cargoList.type072iii,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpFerry,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.ferry
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Ferry',
          dbid = CONFIG.platformDBID56,
          cargo = cargoList.ferry,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp073a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type073a
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 073A',
          dbid = CONFIG.platformDBID10,
          cargo = cargoList.type073a,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )
    end
  end
end

function RemoveLandingShips()
  local unitsFromChina = VP_GetSide({ Side = 'China' }).units
  for index, u in ipairs(unitsFromChina) do
    local unit = SE_GetUnit({ guid = u.guid })
    if unit == nil then goto continue end

    if unit.dbid == CONFIG.platformDBID6 or
        unit.dbid == CONFIG.platformDBID7 or
        unit.dbid == CONFIG.platformDBID8 or
        unit.dbid == CONFIG.platformDBID9 or
        unit.dbid == CONFIG.platformDBID10 or
        unit.dbid == CONFIG.platformDBID32 or
        unit.dbid == CONFIG.platformDBID54 or
        unit.dbid == CONFIG.platformDBID56 or
        unit.dbid == CONFIG.platformDBID72 then
      ScenEdit_DeleteUnit({ side = 'China', guid = unit.guid })
    end

    ::continue::
  end
end
