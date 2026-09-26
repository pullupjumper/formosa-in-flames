local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Utils = require("src.utils.utils")
local GnssJamming = require("src.modules.ew.gnssJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local MissileSystem = require("src.modules.missileSystem.init")
local gKH = require("src.core.gKH_State_Standalone")
local PersistentState = require("src.core.persistentState")
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

---Resolve a SAM system config key to its platform DBID
---@param name string SAM system config key ('pac23', 'skybow3', 'tc2')
---@return integer # Platform DBID, or 0 when the key is unknown
local function getSAMDBID(name)
  local map = {
    ["pac23"] = constants.PLATFORMS.PAC3,
    ["skybow3"] = constants.PLATFORMS.CUSTOMED_TK3,
    ["tc2"] = constants.PLATFORMS.TC2
  }
  return map[name] or 0
end

---Transform deployed missile system configuration into operational area data structure
---@param missileSystem {key: string, unitname: string, category: string, center: CMO__Location, openingAngle: number, tacticalAreas: SBJ__TacticalAreas, paths: SBJ__MovementPaths} Deployed missile system configuration with tactical areas and movement paths
---@return SBJ__OperationalArea # Operational area data structure
local function normalizeData(missileSystem)
  local operationalArea = {
    RL = {},
    FP = {},
    AHA = {},
    HA = {},
    SHRL = {},
    uShapeVertices = missileSystem.tacticalAreas.uShapeVertices,
    shelterPoints = missileSystem.tacticalAreas.shelterPoints,
    name = "#" .. Utils.buildRandomText(3)
  }

  for index, firePoint in ipairs(missileSystem.paths.FP) do
    local course = {}
    for _, waypoint in ipairs(firePoint.waypoints) do
      table.insert(course, {
        latitude = waypoint.latitude,
        longitude = waypoint.longitude,
        desiredSpeed = constants.SPEEDS.FAST,
        presetThrottle = constants.THROTTLES.FLANK
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
      desiredSpeed = constants.SPEEDS.FAST,
      presetThrottle = constants.THROTTLES.FLANK
    })
  end
  -- table.remove(course, 1)
  table.insert(operationalArea.RL, {
    course = course,
    area = missileSystem.tacticalAreas.reloadArea
  })

  local ahaCourse = {}
  for _, waypoint in ipairs(missileSystem.paths.AHA.waypoints) do
    table.insert(ahaCourse, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = constants.SPEEDS.FAST,
      presetThrottle = constants.THROTTLES.FLANK
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
      desiredSpeed = constants.SPEEDS.FAST,
      presetThrottle = constants.THROTTLES.FLANK
    })
  end
  table.insert(operationalArea.HA, { course = haCourse, area = missileSystem.tacticalAreas.hideArea })

  local shrlCourse = {}
  for _, waypoint in ipairs(missileSystem.paths.SHRL.waypoints) do
    table.insert(shrlCourse, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = constants.SPEEDS.FAST,
      presetThrottle = constants.THROTTLES.FLANK
    })
  end
  table.insert(operationalArea.SHRL, { course = shrlCourse, area = missileSystem.tacticalAreas.reloadArea })

  return operationalArea
end

---Count military units by type within operational zones
---@param config SBJ__Config Configuration table
---@return table<string, table<string, number>> # Table with area names as keys and unit type counts as values
function UnitStatusUI.countUnitsInEachArea(config)
  local unitsFromChina = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY }).units
  local result = {}

  for _, zone in ipairs(config.c.amphibOps.operationalZones) do
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

      if unit and unit:inArea(zone.casArea) then
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
function UnitStatusUI.buildWcsSettingTable()
  local filteredUnits = GameApi.VP_GetSide({ side = constants.SIDES.PLAYER }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not filteredUnits then
    return
  end

  local htmlTemplate = getWCSSettingTemplate()
  local msg = string.format(htmlTemplate)
  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

  if form["pressed"] and form["pressed"] == "Done" then
    local jsonStr = form["emconData"]:gsub("^'", ""):gsub("'$", "")
    local result = gKH.json.parse(jsonStr)
    ---@cast result SBJ__EmconResult

    if result.doctrine and #result.doctrine > 0 then
      for _, item in ipairs(result.doctrine) do
        local dbid = getSAMDBID(item.id)

        if item.weaponsFree then
          for _, u in ipairs(filteredUnits) do
            local unit = GameApi.ScenEdit_GetUnit(u.guid)

            if unit and unit.dbid == dbid then
              GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.TIGHT })
              GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(unit.guid, "Green",
                { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
              )
            end
          end
        elseif not item.weaponsFree then
          for _, u in ipairs(filteredUnits) do
            local unit = GameApi.ScenEdit_GetUnit(u.guid)

            if unit and unit.dbid == dbid then
              GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = constants.WCS.HOLD })
              GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(unit.guid, "Green",
                { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
              )
            end
          end
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
  local groundCtx = PersistentState.groundForces(saveData, sideName)
  local missileSystems = { ... }
  ---@cast missileSystems SBJ__MissileSystemContext[]
  local rows = {}

  for _, missileSystem in pairs(missileSystems) do
    local resupplyUnitCtxs = groundCtx[missileSystem] and groundCtx[missileSystem].resupplyUnits

    if resupplyUnitCtxs then
      for key, _ in pairs(resupplyUnitCtxs) do
        rows[key] = {}
      end
    end
  end

  for _, missileSystem in pairs(missileSystems) do
    local missileSystemCtx = groundCtx[missileSystem]
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
  local iads = PersistentState.iads(saveData, sideName)
  local rows = {}
  local types = { ... }

  for _, type in pairs(types) do
    local C2Ctxs = iads[type]

    if C2Ctxs then
      for _, C2Ctx in pairs(C2Ctxs) do
        if rows[type] == nil then
          rows[type] = {}
        end

        rows[type][C2Ctx.guid] = { name = C2Ctx.name }

        if C2Ctx.sam then
          rows[type][C2Ctx.guid]["SAM"] = {}

          for _, SAMCtx in pairs(C2Ctx.sam) do
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
  local rows = {}
  local transmissions = PersistentState.sigint(saveData, sideName).transmissions

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
local function createGnssJammerDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local descriptors = config[field].gnssJamming.jammers
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

  for key, system in pairs(config[field].ground) do
    ---@cast system SBJ__MissileSystemConfig
    local copy = Utils.deepCopy(system)
    copy.resupplyUnits = nil
    copy.ammunitions = nil

    for _, descriptor in pairs(copy.firingUnits) do
      local uShapeVertices = {}

      for _, attr in ipairs({ "HA", "FP", "RL", "AHA", "SHRL" }) do
        ---@type SBJ__Position[]
        local positions = descriptor.operationalArea[attr]

        if positions then
          for _, position in ipairs(positions) do
            if position.area then
              local vertices = {}
              local points = GameApi.ScenEdit_GetReferencePoints({ side = sideName, area = position.area })

              if points then
                for _, point in ipairs(points) do
                  table.insert(vertices, { latitude = tonumber(point.latitude), longitude = tonumber(point.longitude) })
                end
              end

              if #vertices > 0 then
                position.area = vertices
              end
            end
          end
        end
      end

      local points = GameApi.ScenEdit_GetReferencePoints({
        side = sideName, area = descriptor.operationalArea.mask.area
      })

      if points then
        for _, point in ipairs(points) do
          table.insert(uShapeVertices, { latitude = tonumber(point.latitude), longitude = tonumber(point.longitude) })
        end
      end

      if #uShapeVertices > 0 then
        descriptor.operationalArea.uShapeVertices = uShapeVertices
      end
    end

    rows[key] = copy
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

---Collect each amphibious operation's staging point and boat zone as a waypoint route
---@param config SBJ__Config Configuration table
---@return string # JSON formatted amphibious task force location data with coordinates
local function createAmphibiousTaskForceLocationDataString(config)
  local data = {}

  for _, op in ipairs(config.c.amphibOps.operations) do
    local item = { name = op.name, waypoints = {} }

    local point = GameApi.ScenEdit_GetReferencePoint({
      side = constants.SIDES.ENEMY,
      name = op.from.areas[1].startingPoints.type075[1],
    })

    if point then
      table.insert(item.waypoints, { latitude = point.latitude, longitude = point.longitude })
    end

    for _, opZone in ipairs(config.c.amphibOps.operationalZones) do
      if op.name == opZone.name then
        local destination = GameApi.ScenEdit_GetReferencePoint({
          side = constants.SIDES.ENEMY,
          name = opZone.boat.zone[1],
        })

        if destination then
          table.insert(item.waypoints, { latitude = destination.latitude, longitude = destination.longitude })
        end
      end
    end

    table.insert(data, item)
  end

  return gKH.json.stringify(data)
end

---Create comprehensive status UI with multi-tab military dashboard
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
function UnitStatusUI.createUI(config, sideName)
  PersistentState.read(function(saveData)
    if sideName == constants.SIDES.ENEMY then
      local signalDataString = createSignalDataString(saveData, sideName)
      local batteryDataString = createBatteryDataString(
        config, saveData, sideName,
        constants.MISSILE_SYSTEM_TYPES.SRBM,
        constants.MISSILE_SYSTEM_TYPES.MLRS,
        constants.MISSILE_SYSTEM_TYPES.GLCM,
        constants.MISSILE_SYSTEM_TYPES.ASCM,
        constants.MISSILE_SYSTEM_TYPES.MRBM,
        constants.MISSILE_SYSTEM_TYPES.SAM
      )
      local magazineDataString = createMagazineDataString(config, sideName)
      local c2NodeDataString = createC2NodeDataString(saveData, sideName, "c2")
      local landingUnitsData = UnitStatusUI.countUnitsInEachArea(config)
      local landingUnitsString = gKH.json.stringify(landingUnitsData)


      local htmlTemplate = getHTMLTemplate()
      local msg = string.format(
        htmlTemplate,
        signalDataString,
        batteryDataString,
        c2NodeDataString,
        magazineDataString,
        landingUnitsString
      )
      local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
    else
      local signalDataString = createSignalDataString(saveData, "US")
      local batteryDataString = createBatteryDataString(
        config, saveData, sideName,
        constants.MISSILE_SYSTEM_TYPES.SRBM,
        constants.MISSILE_SYSTEM_TYPES.MLRS,
        constants.MISSILE_SYSTEM_TYPES.GLCM,
        constants.MISSILE_SYSTEM_TYPES.ASCM,
        constants.MISSILE_SYSTEM_TYPES.SAM
      )
      local magazineDataString = createMagazineDataString(config, sideName)
      local c2NodeDataString = createC2NodeDataString(saveData, sideName, "rocc", "taaoc")

      local htmlTemplate = getHTMLTemplate()
      local msg = string.format(
        htmlTemplate,
        signalDataString,
        batteryDataString,
        c2NodeDataString,
        magazineDataString,
        "{}"
      )
      local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
    end
  end)
end

---Create interactive setup menu for Taiwan deployment planning
---@param config SBJ__Config Configuration table
---@param sideName string Side name (currently only 'Taiwan' is supported)
function UnitStatusUI.createSetupMenu(config, sideName)
  PersistentState.update(function(saveData)
    -- Prepare data for HTML template
    local gpsJammerDataString = createGnssJammerDataString(config, sideName)
    local deployedAircraftDataString = createDeployedAircraftDataString(config, sideName)
    local missileSystemDataString = createMissileSystemDataString(config, sideName)
    local amphibiousLocationsDataString = createAmphibiousTaskForceLocationDataString(config)

    local htmlTemplate = getSetupMenuTemplate()
    local msg = string.format(
      htmlTemplate,
      gpsJammerDataString,
      deployedAircraftDataString,
      missileSystemDataString,
      sideName,
      amphibiousLocationsDataString
    )

    -- Display interactive setup dialog
    local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

    -- Process submitted configuration
    if form["pressed"] and form["pressed"] == "Done" and form["summaryData"] then
      -- Parse JSON configuration from form
      local jsonStr = form["summaryData"]:gsub("^'", ""):gsub("'$", "")

      if jsonStr == nil then
        return
      end

      local result = gKH.json.parse(jsonStr)
      ---@cast result SBJ__SetupResult
      local jammerDescriptors = result.jammers
      local airbaseDeploymentDescriptors = result.airbases
      local missileSystems = result.missileSystems

      -- Apply GPS jamming unit deployments
      if jammerDescriptors and #jammerDescriptors > 0 then
        GnssJamming.removeJammers(jammerDescriptors, sideName)
        for _, descriptor in ipairs(jammerDescriptors) do
          GnssJamming.addGnssJammer(descriptor, sideName)
        end
      end

      -- Apply aircraft and loadout configurations
      if airbaseDeploymentDescriptors and #airbaseDeploymentDescriptors > 0 then
        UnitGenerator.addAircraft(airbaseDeploymentDescriptors)

        if sideName == constants.SIDES.PLAYER then
          CommsJamming.initTargetAircraftContexts(saveData.t.air.landBased, config.c.commsJamming.aircraftDefaults)
        end
      end

      -- Apply TEL launcher deployments
      if missileSystems and #missileSystems > 0 then
        local layouts = {}
        ---@cast layouts SBJ__MissileSystemLayout[]
        for _, missileSystem in ipairs(missileSystems) do
          table.insert(layouts, {
            category = missileSystem.category,
            unitname = missileSystem.unitname,
            operationalArea = normalizeData(missileSystem)
          })
        end

        local field = GameUtils.getCachedSideConfig(sideName).field
        MissileSystem.redeploy(config[field].ground, PersistentState.groundForces(saveData, sideName), layouts, sideName)
      end
    end
  end)
end

return UnitStatusUI
