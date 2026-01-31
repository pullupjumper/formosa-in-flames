local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GPSJamming = require("src.modules.EW.GPSJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local MissileSystem = require("src.modules.missileSystem")
local gKH = require("src.core.gKH_State_Standalone")
local constants = require("src.core.constants")

local UnitStatusUI = {}

---Calculate elapsed reload time in minutes since reload started
---@param ctx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with reload start time
---@return number # Elapsed time in minutes (rounded to 2 decimal places)
local function calculateReloadTime(ctx)
  return math.floor(((GameApi.ScenEdit_CurrentTime() - ctx.reloadStartTime) / 60) * 100 + 0.5) / 100
end

---Convert missile system state enum to display string
---@param state missileSystemState Missile system state enum value
---@return string # Human-readable state string (STATIC/REPOSITIONING/HIDE/RELOAD/UNKNOWN)
local function getState(state)
  local stateMap = {
    [constants.MISSILE_SYSTEM_STATE.STATIC] = "STATIC",
    [constants.MISSILE_SYSTEM_STATE.REPOSITIONING] = "REPOSITIONING",
    [constants.MISSILE_SYSTEM_STATE.HIDE] = "HIDE",
    [constants.MISSILE_SYSTEM_STATE.RELOAD] = "RELOAD",
  }
  return stateMap[state] or "UNKNOWN"
end

---Transform deployed missile system configuration into operational area data structure
---@param missileSystem {key: string, unitname: string, category: string, center: CMO__Location, openingAngle: number, tacticalAreas: SBJ__UShapeAreaResult, paths: SBJ__MovementPaths} Deployed missile system configuration with tactical areas and movement paths
---@return SBJ__OperationalArea # Operational area data structure
local function transformData(missileSystem)
  local operationalArea = {
    RL = {},
    FP = {},
    AHA = {},
    HA = {},
    uShapeVertices = missileSystem.tacticalAreas.uShapeVertices,
    name = "#" .. Utils.randomTxt(2)
  }

  for index, firePoint in ipairs(missileSystem.paths.FP) do
    local course = {}
    for _, waypoint in ipairs(firePoint.waypoints) do
      table.insert(course, {
        latitude = waypoint.latitude,
        longitude = waypoint.longitude,
        desiredSpeed = 30,
        presetThrottle = "Flank"
      })
    end
    table.insert(operationalArea.FP, {
      course = course,
      area = missileSystem.tacticalAreas.firePoints[index]
    })
  end

  local reloadPoint = missileSystem.paths.RL[1]
  local course = {}
  for _, waypoint in ipairs(reloadPoint.waypoints) do
    table.insert(course, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = 30,
      presetThrottle = "Flank"
    })
  end
  table.remove(course, 1)
  table.insert(operationalArea.RL, {
    course = course,
    area = missileSystem.tacticalAreas.reloadArea
  })

  local ahaCourse = {}
  for _, waypoint in ipairs(missileSystem.paths.AHA.waypoints) do
    table.insert(ahaCourse, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = 30,
      presetThrottle = "Flank"
    })
  end
  table.insert(operationalArea.AHA, {
    course = ahaCourse,
    area = missileSystem.tacticalAreas.ammoArea
  })

  local haCourse = {}
  for _, waypoint in ipairs(missileSystem.paths.HA.waypoints) do
    table.insert(haCourse, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = 30,
      presetThrottle = "Flank"
    })
  end
  table.insert(operationalArea.HA, { course = haCourse, area = missileSystem.tacticalAreas.hideArea })
  return operationalArea
end

---Count military units by type within operational zones
---@param config SBJ__Config Configuration table
---@return table<string, table<string, number>> # Table with area names as keys and unit type counts as values
function UnitStatusUI.countUnitsInEachArea(config)
  local unitsFromChina = GameApi.VP_GetSide({ side = "China" }).units
  local result = {}

  for _, zone in ipairs(config.c.PHIBOP.operationalZones) do
    local item = {
      ["ZBD-05"] = 0,
      ["ZTD-05"] = 0,
      ["PLL-05"] = 0,
      ["PLZ-96"] = 0,
      ["PGZ-09"] = 0,
      ["PGZ-95"] = 0,
      ["SA-15"] = 0,
      ["AirborneCorps"] = 0,
      ["HMMWV"] = 0,
      ["ZBD-03"] = 0
    }
    for _, u in ipairs(unitsFromChina) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if unit and unit:inArea(zone.area) then
        if unit.dbid == constants.PLATFORMS.ZBD05 then
          item["ZBD-05"] = item["ZBD-05"] + 1
        end

        if unit.dbid == constants.PLATFORMS.ZTD05 then
          item["ZTD-05"] = item["ZTD-05"] + 1
        end

        if unit.dbid == constants.PLATFORMS.PLL05 then
          item["PLL-05"] = item["PLL-05"] + 1
        end

        if unit.dbid == constants.PLATFORMS.PLZ96 then
          item["PLZ-96"] = item["PLZ-96"] + 1
        end

        if unit.dbid == constants.PLATFORMS.PGZ09 then
          item["PGZ-09"] = item["PGZ-09"] + 1
        end

        if unit.dbid == constants.PLATFORMS.PGZ95 then
          item["PGZ-95"] = item["PGZ-95"] + 1
        end

        if unit.dbid == constants.PLATFORMS.SA15 then
          item["SA-15"] = item["SA-15"] + 1
        end

        if unit.dbid == constants.PLATFORMS.MC then
          item["AirborneCorps"] = item["AirborneCorps"] + 1
        end

        if unit.dbid == constants.PLATFORMS.HMMWV then
          item["HMMWV"] = item["HMMWV"] + 1
        end

        if unit.dbid == constants.PLATFORMS.ZBD03 then
          item["ZBD-03"] = item["ZBD-03"] + 1
        end
      end
    end

    result[zone.name] = item
  end

  return result
end

---Generate HTML template for WCS settings UI
---@return string # HTML string representing the WCS settings page
local function getWCSSettingTemplate()
  return [[]]
end

---Display HTML dialog for EMCON settings configuration
function UnitStatusUI.wcsSettingTable()
  local filteredUnits = GameApi.VP_GetSide({ side = "Taiwan" }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not filteredUnits then
    return
  end

  local HTMLTemplate = getWCSSettingTemplate()
  local msg = string.format(HTMLTemplate)
  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

  if form["pressed"] and form["pressed"] == "Done" then
    if form["pac23"] and string.gsub(form["pac23"], "%'", "") == "on" then
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.HOLD })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.TIGHT })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form["skybow3"] and string.gsub(form["skybow3"], "%'", "") == "on" then
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.HOLD })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.TIGHT })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form["tc2"] and string.gsub(form["tc2"], "%'", "") == "on" then
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.HOLD })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, u in ipairs(filteredUnits) do
        local unit = GameApi.ScenEdit_GetUnit(u.guid)

        if unit and unit.dbid == constants.PLATFORMS.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.TIGHT })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end
  end
end

---Create JSON string for artillery battery status data
---@param config SBJ__Config Configuration table
---@param saveData SBJ__SaveData Saved game data
---@param sideName string Side name ('China' or 'Taiwan')
---@param ... string Weapon system type list
---@return string # JSON formatted artillery battery status data
local function createBatteryDataString(config, saveData, sideName, ...)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local missileSystems = { ... }
  local rows = {}

  for _, missileSystem in pairs(missileSystems) do
    local resupplyUnitCtxs = saveData[field].ground[missileSystem] and
        saveData[field].ground[missileSystem].resupplyUnits

    if resupplyUnitCtxs then
      for key, ctx in pairs(resupplyUnitCtxs) do
        rows[key] = {}
      end
    end
  end

  for _, missileSystem in pairs(missileSystems) do
    ---@type SBJ__MissileSystemContext
    local missileSystemCtx = saveData[field].ground[missileSystem]
    local firingUnitCtxs = missileSystemCtx and missileSystemCtx.firingUnits

    if missileSystemCtx and firingUnitCtxs then
      for _, firingUnitCtx in pairs(firingUnitCtxs) do
        local name = firingUnitCtx.name
        local status = getState(firingUnitCtx.state)
        local resupplyUnitCtx = missileSystemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
        local missilesInAmmoVehicles = resupplyUnitCtx.wpnCurrent
        local resupplyUnitStatus = getState(resupplyUnitCtx.state)
        local reloadTime = config[field].ground[missileSystem].reloadTime / 60
        local missilesInAHA = missileSystemCtx.ammunitions[resupplyUnitCtx.ammunition].wpnCurrent
        local firingUnitReloadTime = nil
        local resupplyUnitReloadTime = nil

        if firingUnitCtx.reloadStartTime ~= nil then
          firingUnitReloadTime = calculateReloadTime(firingUnitCtx)

          if firingUnitReloadTime < 0 then
            firingUnitReloadTime = 0
          end
        end

        if firingUnitCtx.reloadStartTime == nil then
          firingUnitReloadTime = 0
        end

        if resupplyUnitCtx.reloadStartTime ~= nil then
          resupplyUnitReloadTime = calculateReloadTime(resupplyUnitCtx)

          if resupplyUnitReloadTime < 0 then
            resupplyUnitReloadTime = 0
          end
        end

        if resupplyUnitCtx.reloadStartTime == nil then
          resupplyUnitReloadTime = 0
        end

        table.insert(rows[firingUnitCtx.resupplyUnit], {
          name = name,
          missileSystem = missileSystem,
          firingUnitState = status,
          resupplyUnitState = resupplyUnitStatus,
          missilesInAmmoVehicles = missilesInAmmoVehicles,
          missilesInAHA = missilesInAHA,
          firingUnitReloadTime = firingUnitReloadTime,
          resupplyUnitReloadTime = resupplyUnitReloadTime,
          defaultReloadTime = reloadTime
        })
      end
    end
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for base ammunition inventory data
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted ammunition inventory data
local function createMagazineDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local descriptors = config[field].air.landBased.deployedACs

  for _, descriptor in ipairs(descriptors) do
    local base = GameApi.ScenEdit_GetUnit(descriptor.baseGUID)

    if base and descriptor.loadouts then
      local obj = { name = descriptor.name, wpns = {} }

      for _, magazine in ipairs(base.magazines) do
        for _, wpn in ipairs(magazine.mag_weapons) do
          table.insert(obj.wpns, { name = wpn.wpn_name, currWpn = wpn.wpn_current })
        end
      end

      table.insert(rows, obj)
    end
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for C2 system status data
---@param saveData SBJ__SaveData Saved game data
---@param sideName string Side name ('China' or 'Taiwan')
---@param ... string System type list
---@return string # JSON formatted C2 status data
local function createC2NodeDataString(saveData, sideName, ...)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local types = { ... }

  for _, type in pairs(types) do
    local C2Ctxs = saveData[field].IADS[type]

    if C2Ctxs then
      for _, C2Ctx in pairs(C2Ctxs) do
        if rows[type] == nil then
          rows[type] = {}
        end

        rows[type][C2Ctx.guid] = { name = C2Ctx.name }

        if C2Ctx.SAM then
          rows[type][C2Ctx.guid]["SAM"] = {}

          for _, SAMCtx in pairs(C2Ctx.SAM) do
            local unit = GameApi.ScenEdit_GetUnit(SAMCtx.guid)
            local isDestroyed = unit == nil
            rows[type][C2Ctx.guid]["SAM"][SAMCtx.guid] = {
              name = SAMCtx.name,
              OODADetection = tostring(SAMCtx.currOODA.detection) .. "/" .. tostring(SAMCtx.OODA.detection),
              OODATargeting = tostring(SAMCtx.currOODA.targeting) .. "/" .. tostring(SAMCtx.OODA.targeting),
              isOutOfComms = SAMCtx.isOutOfComms,
              EMCONSetting = SAMCtx.EMCONSetting,
              isDestroyed = isDestroyed
            }
          end
        end

        if C2Ctx.radar then
          rows[type][C2Ctx.guid]["radar"] = {}

          for _, radarCtx in pairs(C2Ctx.radar) do
            local unit = GameApi.ScenEdit_GetUnit(radarCtx.guid)
            local isDestroyed = unit == nil
            rows[type][C2Ctx.guid]["radar"][radarCtx.guid] = {
              name = radarCtx.name,
              OODADetection = tostring(radarCtx.currOODA.detection) .. "/" .. tostring(radarCtx.OODA.detection),
              OODATargeting = tostring(radarCtx.currOODA.targeting) .. "/" .. tostring(radarCtx.OODA.targeting),
              isOutOfComms = radarCtx.isOutOfComms,
              EMCONSetting = radarCtx.EMCONSetting,
              isDestroyed = isDestroyed
            }
          end
        end
      end
    end
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for SIGINT transmission data
---@param saveData SBJ__SaveData Saved game data
---@param sideName string Side name ('China' or "US")
---@return string # JSON formatted signal data
local function createSignalDataString(saveData, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local transmissions = saveData[field].SIGINT.transmissions

  for _, transmission in pairs(transmissions) do
    local copy = Utils.deepCopy(transmission)
    table.insert(rows, copy)
  end

  return gKH.json.stringify(rows)
end

---Get HTML template for comprehensive status dashboard with tabbed interface
---@return string # Complete HTML template with placeholders for data injection
local function getHTMLTemplate()
  return [[]]
end

---Get HTML template for interactive deployment setup menu
---@return string # Setup menu template
local function getSetupMenuTemplate()
  return [[]]
end

---Create JSON string for GPS jamming unit data
---@param config SBJ__Config Saved game data containing GPS jamming state
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted GPS jamming unit data
local function createGPSJammerDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local descriptors = config[field].GPSJamming.jammers
  local rows = {}

  for _, descriptor in pairs(descriptors) do
    local row = Utils.deepCopy(descriptor)
    table.insert(rows, row)
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for missile system data
---@param config SBJ__Config Saved game data containing missile system state
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted missile system data
local function createMissileSystemDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local systems = { "srbm", "mlrs", "glcm", "ascm" }

  for _, system in ipairs(systems) do
    rows[system] = config[field].ground[system]
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for deployed aircraft data with base coordinates
---@param config SBJ__Config Configuration table containing aircraft deployment data
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted deployed aircraft data with coordinates
local function createDeployedAircraftDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local descriptors = config[field].air.landBased.deployedACs

  for _, descriptor in pairs(descriptors) do
    local row = Utils.deepCopy(descriptor)
    local base = GameApi.ScenEdit_GetUnit(row.baseGUID)

    if base then
      row.latitude = base.latitude
      row.longitude = base.longitude
      table.insert(rows, row)
    end
  end

  return gKH.json.stringify(rows)
end

---Create comprehensive status UI with multi-tab military dashboard
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
function UnitStatusUI.createUI(config, sideName)
  ---@type SBJ__SaveData|nil
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error("saveData is nil")
    return
  end

  if sideName == "China" then
    local signalDataString = createSignalDataString(saveData, sideName)
    local batteryDataString = createBatteryDataString(config, saveData, sideName, "srbm", "mlrs", "glcm", "ascm", "mrbm")
    local magazineDataString = createMagazineDataString(config, sideName)
    local c2NodeDataString = createC2NodeDataString(saveData, sideName, "C2")
    local landingUnitsData = UnitStatusUI.countUnitsInEachArea(config)
    local landingUnitsString = gKH.json.stringify(landingUnitsData)


    local HTMLTemplate = getHTMLTemplate()
    local msg = string.format(
      HTMLTemplate,
      batteryDataString,
      signalDataString,
      c2NodeDataString,
      magazineDataString,
      landingUnitsString
    )
    local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
  else
    local signalDataString = createSignalDataString(saveData, "US")
    local batteryDataString = createBatteryDataString(config, saveData, sideName, "srbm", "mlrs", "glcm", "ascm")
    local magazineDataString = createMagazineDataString(config, sideName)
    local c2NodeDataString = createC2NodeDataString(saveData, sideName, "ROCC", "TAAOC")

    local HTMLTemplate = getHTMLTemplate()
    local msg = string.format(
      HTMLTemplate,
      batteryDataString,
      signalDataString,
      c2NodeDataString,
      magazineDataString,
      "{}"
    )
    local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
  end
end

---Create interactive setup menu for Taiwan deployment planning
---@param config SBJ__Config Configuration table
---@param sideName string Side name (currently only 'Taiwan' is supported)
function UnitStatusUI.createSetupMenu(config, sideName)
  ---@type SBJ__SaveData|nil
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error("saveData is nil")
    return
  end

  if sideName ~= "Taiwan" then
    Logger.error("Unsupported side name")
    return
  end

  -- Prepare data for HTML template
  local gpsJammerDataString = createGPSJammerDataString(config, sideName)
  local deployedAircraftDataString = createDeployedAircraftDataString(config, sideName)
  local missileSystemDataString = createMissileSystemDataString(config, sideName)
  local HTMLTemplate = getSetupMenuTemplate()
  local msg = string.format(HTMLTemplate, gpsJammerDataString, deployedAircraftDataString, missileSystemDataString)

  -- Display interactive setup dialog
  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

  -- Process submitted configuration
  if form["pressed"] and form["pressed"] == "Done" and form["summaryData"] then
    -- Parse JSON configuration from form
    local jsonStr = form["summaryData"]:gsub("^'", ""):gsub("'$", "")
    local result = gKH.json.parse(jsonStr)
    ---@cast result SBJ__SetupResult
    local jammerDescriptors = result.jammers
    local airbaseDeploymentDescriptors = result.airbases
    local missileSystems = result.missileSystems

    -- Apply GPS jamming unit deployments
    if jammerDescriptors and #jammerDescriptors > 0 then
      GPSJamming.removeJammers(jammerDescriptors, sideName)
      for _, descriptor in ipairs(jammerDescriptors) do
        GPSJamming.addGPSJammer(descriptor, sideName)
      end
    end

    -- Apply aircraft and loadout configurations
    if airbaseDeploymentDescriptors and #airbaseDeploymentDescriptors > 0 then
      UnitGenerator.addAircraft(airbaseDeploymentDescriptors)
      UnitGenerator.initAircraftContexts(saveData.t.air.landBased)
    end

    -- Apply TEL launcher deployments
    if missileSystems and #missileSystems > 0 then
      local sideConfig = GameUtils.getCachedSideConfig(sideName)
      local field = sideConfig.field
      local operationalAreas = {}
      ---@cast operationalAreas SBJ__OperationalArea[]
      local groundCig = {
        srbm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
        ascm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
        glcm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
        mlrs = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }
      ---@cast groundCig SBJ__GroundForceConfig
      -- Update missile system configurations in config
      for _, missileSystem in ipairs(missileSystems) do
        ---@type SBJ__MissileSystemConfig
        local systemCfg = config[field].ground[missileSystem.category]

        if systemCfg and systemCfg.firingUnits[missileSystem.unitname] then
          local firingUnitdescriptor = Utils.deepCopy(systemCfg.firingUnits[missileSystem.unitname])
          local resupplyUnitDescriptor = Utils.deepCopy(systemCfg.resupplyUnits[firingUnitdescriptor.resupplyUnit])
          local ammoDescriptor = Utils.deepCopy(systemCfg.ammunitions[resupplyUnitDescriptor.ammunition])
          local operationalArea = transformData(missileSystem)
          firingUnitdescriptor.operationalArea = operationalArea
          resupplyUnitDescriptor.operationalArea = operationalArea
          table.insert(operationalAreas, operationalArea)
          groundCig[missileSystem.category].firingUnits[firingUnitdescriptor.name] = firingUnitdescriptor
          groundCig[missileSystem.category].resupplyUnits[resupplyUnitDescriptor.name] = resupplyUnitDescriptor
          groundCig[missileSystem.category].ammunitions[ammoDescriptor.name] = ammoDescriptor
        end
      end

      MissileSystem.initEventTriggers(operationalAreas, {
        constants.POSITION_TYPES.RELOAD_POINT,
        constants.POSITION_TYPES.FIRING_POINT,
        constants.POSITION_TYPES.HIDE_AREA,
        constants.POSITION_TYPES.AMMO_HOLDING_AREA
      }, sideName)
      MissileSystem.addMissileSystems(groundCig, sideName)
      MissileSystem.initMissileSystemContexts(groundCig, saveData.t.ground)
    end
  end

  gKH.State.SaveTableToKey(saveData, "SaveData")
end

return UnitStatusUI
