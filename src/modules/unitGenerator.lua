local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

---@class UnitGenerator
local UnitGenerator = {}

-- ============================================================================
-- 常數定義 - 提高可讀性，消除魔術數字
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
-- 基礎工具函數 - 最底層的工具函數
-- ============================================================================

---計算編隊位置
---@param centerPoint {lat: number, lon: number} 中心點座標 {lat: number, lon: number}
---@param heading number 航向角度
---@param distance number 距離
---@param angle number 角度偏移
---@return table|nil 計算後的位置 {latitude: number, longitude: number}
local function calculateFormationPosition(centerPoint, heading, distance, angle)
  return GameApi.World_GetPointFromBearing({
    LATITUDE = centerPoint.lat,
    LONGITUDE = centerPoint.lon,
    BEARING = heading + angle,
    DISTANCE = distance,
  })
end

---批量刪除群組中的單位
---@param groupName string 群組名稱
---@param sideName string 陣營名稱
---@return boolean 是否成功清理
local function cleanupExistingGroup(groupName, sideName)
  local group = GameApi.ScenEdit_GetUnit(groupName)
  if group and group.group and group.group.unitlist then
    for _, guid in ipairs(group.group.unitlist) do
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
    end
  end
  return true
end

---嘗試創建單個單位（帶重試機制）
---@param unitDescriptor CMO__SetUnitDescriptor 單位描述符
---@param maxAttempts number|nil 最大嘗試次數
---@return CMO__Unit|nil 創建的單位
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
-- 單位管理函數 - 處理單位創建和搭載
-- ============================================================================


---添加搭載單位（高級版本，支持任務分配）
---@param embarkedUnits SBJ__EmbarkedUnit[] 搭載單位列表
---@param baseGuid string 基地單位 GUID
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

---按參考點添加單位
---@param params SBJ__Location_Params 位置參數
---@param unit CMO__SetUnitDescriptor 單位描述符
---@param embarkedUnits SBJ__EmbarkedUnit[]|nil 搭載單位
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

---計算船隻位置
---@param firstRp CMO__Location 第一個參考點
---@param verticalHeading number 垂直航向
---@param verticalDistance number 垂直距離
---@return table<string, CMO__Location> 各類型船隻的位置
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

---按類型創建船隻
---@param config SBJ__CONFIG 配置對象
---@param position CMO__Location 位置
---@param area table 區域配置
---@param item table 項目配置
---@param shipSettings SBJ__ShipSettings 船隻設置
---@param cargoList table 貨物列表
---@param shipType string 船隻類型
local function createShipsByType(config, position, area, item, shipSettings, cargoList, shipType)
  local shipConfigs = {
    type075 = {
      dbid = config.platform.TYPE_075,
      name = 'Type 075',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z_18,      loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z_10,      loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',     dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 3 } } }
      }
    },
    type071 = {
      dbid = config.platform.TYPE_071,
      name = 'Type 071',
      cargo = cargoList.type071,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z_18,      loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 4 } } },
        { side = 'China', type = 'ship',     name = 'Warbird',     dbid = config.platform.TYPE_726A, loadouts = { { loadoutId = 0, num = 4 } } }
      }
    },
    type076 = {
      dbid = config.platform.TYPE_076,
      name = 'Type 076',
      cargo = cargoList.type075,
      embarkedUnits = {
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z_18,      loadouts = { { loadoutId = config.loadout.Z18_TRANSPORT_1, num = 6 }, { loadoutId = config.loadout.Z18_TRANSPORT_2, num = 6 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.Z_10,      loadouts = { { loadoutId = config.loadout.Z10_ATTACK, num = 13 } } },
        { side = 'China', type = 'aircraft', name = item.names[1], dbid = config.platform.GJ_11,     loadouts = { { loadoutId = config.loadout.GJ11_ATTACK, num = 8 } } },
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
-- 編隊配置工廠 - 配置驅動的設計
-- ============================================================================


---獲取 SAG 編隊配置
---@param config SBJ__CONFIG 配置對象
---@param side string 陣營名稱 ('China' | 'Taiwan')
---@return SBJ__ShipConfig[] 船隻配置列表
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
        embarkedUnits = nil -- 搭載單位在創建時單獨處理
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

---獲取 CSG 編隊配置
---@param config SBJ__CONFIG 配置對象
---@return SBJ__ShipConfig[] CSG 船隻配置列表
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

---創建隨機位置的單位
---@param config SBJ__RandomUnits 配置參數
---@return CMO__Unit|CMO__Unit[] 創建的單位
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

---創建編隊船隻
---@param formationConfig SBJ__FormationConfig 編隊配置
---@return boolean 是否成功
local function createShipFormation(formationConfig)
  -- 清理現有群組
  cleanupExistingGroup(formationConfig.groupName, formationConfig.sideName)

  local createdUnits = {}

  -- 創建各個位置的船隻
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

      -- 添加搭載單位
      if shipConfig.embarkedUnits then
        addEmbarkedUnitsAdvanced(shipConfig.embarkedUnits, unit.guid)
      end

      -- 添加彈藥配置（針對航母等）
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

---嘗試創建噴射單位
---@param config SBJ__CONFIG 配置參數
---@param jammer table 噴射設備
---@param attempt number|nil 嘗試次數
---@param max_attempts number|nil 最大嘗試次數
local function tryAddJammerUnit(config, jammer, attempt, max_attempts)
  attempt = attempt or 1
  max_attempts = max_attempts or 50

  local point = GameUtils.circularRandomPosition(jammer.point.lat, jammer.point.lon, jammer.randomRadius)
  local unit = GameApi.ScenEdit_AddUnit({
    type = 'Facility',
    unitname = jammer.name,
    dbid = config.platform.GPS_JAMMER,
    side = 'China',
    Lat = point.latitude,
    Lon = point.longitude,
    autodetectable = false
  })

  if unit then
    return unit, point
  elseif attempt < max_attempts then
    return tryAddJammerUnit(config, jammer, attempt + 1, max_attempts)
  else
    print("Failed to create jammer unit after " .. max_attempts .. " attempts: " .. jammer.name)
    return nil, nil
  end
end

-- ============================================================================
-- 主要功能函數 - 重構後的版本
-- ============================================================================

---移除 C2 設施
---@param config SBJ__CONFIG 配置對象
---@return boolean 是否成功
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

---添加 C2 設施
---@param config SBJ__CONFIG 配置對象
---@return boolean 是否成功
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

---創建 SAG 編隊
---@param config SBJ__CONFIG 配置對象
---@param side string 陣營名稱
---@return boolean 是否成功
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

    -- 單獨處理搭載單位（針對台灣）
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

    -- 設置雷達狀態
    local group = GameApi.ScenEdit_GetUnit(sagConfig.groupName)
    if group then
      GameApi.ScenEdit_SetEMCON('Unit', group.guid, 'Radar=Active')
    end

    -- 設置任務（針對台灣）
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

---創建 CSG 編隊
---@param config SBJ__CONFIG 配置對象
---@return boolean 是否成功
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

  -- 設置參考點
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

---添加部署在港口的船隻
---@param config SBJ__CONFIG 配置對象
---@param side string 陣營名稱
---@return boolean 是否成功
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

---添加潛艇
---@param config SBJ__CONFIG 配置對象
---@param side string 陣營名稱
---@return boolean 是否成功
function UnitGenerator.addSubmarines(config, side)
  if side ~= 'China' then
    return true -- 目前只支持中國潛艇
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

      -- 移除默認武器並添加指定武器
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

---初始化 C2 設施
---@param config SBJ__CONFIG 配置對象
---@param saveData SBJ__SaveData 保存數據
---@return boolean 是否成功
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

  -- 初始化 SAM 和雷達系統
  for _, unit in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    for c2Guid, item in pairs(saveData.c.IADS.C2) do
      for _, area in ipairs(item.areas) do
        if actualUnit and actualUnit:inArea(area) then
          -- SAM 系統
          if (actualUnit.dbid == config.platform.HQ_22 or
                actualUnit.dbid == config.platform.S_300 or
                actualUnit.dbid == config.platform.S_400 or
                actualUnit.dbid == config.platform.HQ_12) and
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

          -- 雷達系統
          if actualUnit.dbid == config.platform.JY_26 or actualUnit.dbid == config.platform.YLC_8B then
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

---添加飛機
---@param config SBJ__CONFIG 配置對象
---@param side string 陣營名稱
---@return boolean 是否成功
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

---移除基地的彈藥庫
---@param baseGUID string 基地 GUID
---@return boolean 是否成功
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

-- addEmbarkedUnitsAdvanced 已在上面定義

---添加登陸艦
---@param config SBJ__CONFIG 配置對象
---@return boolean 是否成功
function UnitGenerator.addLandingShips(config)
  local initialLocations = config.c.PHIBOP.initialLocations
  local shipSettings = config.c.PHIBOP.shipSettings
  local cargoList = config.c.PHIBOP.cargoList

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.from.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]

      -- 計算各種船隻的起始位置
      local positions = calculateShipPositions(firstRp075, area.heading.vertical, shipSettings.verticalDistance)

      -- 創建各類型船隻
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

---移除登陸艦
---@param config SBJ__CONFIG 配置對象
---@return boolean 是否成功
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

---移除 GPS干擾區域
---@param config SBJ__CONFIG 配置對象
function UnitGenerator.removeJammingZones(config)
  local s = GameApi.VP_GetSide({ name = 'China' })
  if s == nil then return end

  for _, zone in ipairs(s.standardzones) do
    for _, jammer in ipairs(config.c.GPSJamming.jammers) do
      if zone.description == jammer.zoneName then
        local myz = s:getstandardzone(zone.guid)

        for _, area in ipairs(myz.area) do
          GameApi.ScenEdit_DeleteReferencePoint({ side = "China", name = area.name })
        end

        GameApi.ScenEdit_RemoveZone('China', -925, { Description = myz.description })
        GameApi.ScenEdit_DeleteUnit({ side = "China", unitname = jammer.name })
      end
    end
  end
end

---comment
---@param config SBJ__CONFIG
function UnitGenerator.addGPSJammingZones(config)
  for _, jammer in ipairs(config.c.GPSJamming.jammers) do
    local unit, point = tryAddJammerUnit(config, jammer)

    if unit and point then
      GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

      local area = GameUtils.newArea(point, {
        side = 'China',
        shape = 'circle',
        distance = jammer.radius
      })

      local zone = GameApi.ScenEdit_AddZone('China', -925, {
        description = jammer.zoneName,
        area = area
      })

      if zone then
        zone.enablers = {
          GNSS_GLONASS = true,
          GNSS_GPS = false,
          GNSS_BeiDou = true,
          GNSS_NavIC = true
        }
      end
    end
  end
end

return UnitGenerator
