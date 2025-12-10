local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GPSJamming = require("src.modules.EW.GPSJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local gKH = require("src.core.gKH_State_Standalone")
local constants = require("src.core.constants")

local UnitStatusUI = {}

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
    for _, value in ipairs(unitsFromChina) do
      local unit = GameApi.ScenEdit_GetUnit(value.guid)

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
  local units = GameApi.VP_GetSide({ side = "Taiwan" }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not units then
    return
  end

  local HTMLTemplate = getWCSSettingTemplate()
  local msg = string.format(HTMLTemplate)
  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

  if form["pressed"] and form["pressed"] == "Done" then
    if form["pac23"] and string.gsub(form["pac23"], "%'", "") == "on" then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form["skybow3"] and string.gsub(form["skybow3"], "%'", "") == "on" then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form["tc2"] and string.gsub(form["tc2"], "%'", "") == "on" then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            "Green",
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == constants.PLATFORMS.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
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
  local key = sideConfig.field
  local wpnSystems = { ... }

  local rows = {}

  for index, wpnSystem in pairs(wpnSystems) do
    if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].resupplyUnits then
      for k, value in pairs(saveData[key].ground[wpnSystem].resupplyUnits) do
        rows[k] = {}
      end
    end
  end

  for index, wpnSystem in pairs(wpnSystems) do
    if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].firingUnits then
      for _, bty in pairs(saveData[key].ground[wpnSystem].firingUnits) do
        local name = bty.name
        local status = ""
        local missilesInAmmoVehicles = saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit]
            .wpnCurrent
        local ammoSec = saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit]
        local reloadTime = config[key].ground[wpnSystem].reloadTime / 60
        local missilesInAHA = saveData[key].ground[wpnSystem].ammunitions
            [saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit].ammunition].wpnCurrent
        local batteryReloadTime = nil
        local ammoSectionReloadTime = nil

        if bty.state == 0 then
          status = "STATIC"
        elseif bty.state == 1 then
          status = "REPOSITIONING"
        elseif bty.state == 2 then
          status = "RELOAD"
        else
          status = "HIDE"
        end

        if bty.reloadStartTime ~= nil then
          batteryReloadTime = math.floor(((GameApi.ScenEdit_CurrentTime() - bty.reloadStartTime) / 60) * 100 +
                0.5) /
              100

          if batteryReloadTime < 0 then
            batteryReloadTime = 0
          end
        end

        if bty.reloadStartTime == nil then
          batteryReloadTime = 0
        end

        if ammoSec.reloadStartTime ~= nil then
          ammoSectionReloadTime = math.floor(((GameApi.ScenEdit_CurrentTime() - ammoSec.reloadStartTime) / 60) *
            100 +
            0.5) / 100

          if ammoSectionReloadTime < 0 then
            ammoSectionReloadTime = 0
          end
        end

        if ammoSec.reloadStartTime == nil then
          ammoSectionReloadTime = 0
        end

        if sideName == "China" then
          table.insert(rows[bty.resupplyUnit], {
            name = name,
            type = wpnSystem,
            status = status,
            missilesInAmmoVehicles = missilesInAmmoVehicles,
            missilesInAHA = missilesInAHA,
            batteryReloadTime = batteryReloadTime,
            ammoSectionReloadTime = ammoSectionReloadTime,
            defaultReloadTime = reloadTime
          })
        else
          table.insert(rows[bty.resupplyUnit], {
            name = name,
            type = wpnSystem,
            status = status,
            missilesInAmmoVehicles = missilesInAmmoVehicles,
            missilesInAHA = missilesInAHA,
            batteryReloadTime = batteryReloadTime,
            ammoSectionReloadTime = ammoSectionReloadTime,
            defaultReloadTime = reloadTime
          })
        end
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
  local key = sideConfig.field

  local rows = {}

  for index, item in ipairs(config[key].air.landBased.deployedACs) do
    local base = GameApi.ScenEdit_GetUnit(item.baseGUID)

    if base and item.loadouts then
      local obj = { name = item.name, wpns = {} }

      for _, magazine in ipairs(base.magazines) do
        for _, wpn in ipairs(magazine["mag_weapons"]) do
          table.insert(obj.wpns, {
            name = wpn["wpn_name"],
            currWpn = wpn["wpn_current"],
          })
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
  local key = sideConfig.field

  local rows = {}
  local types = { ... }

  for _, type in pairs(types) do
    for index, item in pairs(saveData[key].IADS[type]) do
      if rows[type] == nil then
        rows[type] = {}
      end

      rows[type][item.guid] = { name = item.name }

      if item.SAM then
        rows[type][item.guid]["SAM"] = {}

        for _, sam in pairs(item.SAM) do
          local unit = GameApi.ScenEdit_GetUnit(sam.guid)
          local isDestroyed = unit == nil
          rows[type][item.guid]["SAM"][sam.guid] = {
            name = sam.name,
            OODADetection = tostring(sam.currOODA.detection) .. "/" .. tostring(sam.OODA.detection),
            OODATargeting = tostring(sam.currOODA.targeting) .. "/" .. tostring(sam.OODA.targeting),
            isOutOfComms = sam.isOutOfComms,
            EMCONSetting = sam.EMCONSetting,
            isDestroyed = isDestroyed
          }
        end
      end

      if item.radar then
        rows[type][item.guid]["radar"] = {}

        for _, radar in pairs(item.radar) do
          local unit = GameApi.ScenEdit_GetUnit(radar.guid)
          local isDestroyed = unit == nil
          rows[type][item.guid]["radar"][radar.guid] = {
            name = radar.name,
            OODADetection = tostring(radar.currOODA.detection) .. "/" .. tostring(radar.OODA.detection),
            OODATargeting = tostring(radar.currOODA.targeting) .. "/" .. tostring(radar.OODA.targeting),
            isOutOfComms = radar.isOutOfComms,
            EMCONSetting = radar.EMCONSetting,
            isDestroyed = isDestroyed
          }
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
  local key = sideConfig.field

  local rows = {}
  for _, data in pairs(saveData[key].SIGINT.transmissions) do
    local copy = Utils.deepCopy(data)
    copy.firstDetected = os.date("!%Y-%m-%d %H:%M:%S", data.firstDetected)
    copy.lastDetected = os.date("!%Y-%m-%d %H:%M:%S", data.lastDetected)
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
---@param saveData SBJ__SaveData Saved game data containing GPS jamming state
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted GPS jamming unit data
local function createGPSJammingDataString(saveData, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local side = sideConfig.field

  local rows = {}
  for _, data in pairs(saveData[side].GPSJamming.jammers) do
    local row = Utils.deepCopy(data)
    table.insert(rows, row)
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for deployed aircraft data with base coordinates
---@param config SBJ__Config Configuration table containing aircraft deployment data
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted deployed aircraft data with coordinates
local function createDeployedAircraftDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local side = sideConfig.field
  local rows = {}

  for _, data in pairs(config[side].air.landBased.deployedACs) do
    local row = Utils.deepCopy(data)
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
  ---@type SBJ__SaveData
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error("saveData is nil")
    return
  end

  if sideName == "Taiwan" then
    -- Prepare data for HTML template
    local jammingDataString = createGPSJammingDataString(saveData, sideName)
    local deployedAircraftDataString = createDeployedAircraftDataString(config, sideName)
    local HTMLTemplate = getSetupMenuTemplate()
    local msg = string.format(
      HTMLTemplate,
      jammingDataString,
      deployedAircraftDataString
    )

    -- Display interactive setup dialog
    local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

    -- Process submitted configuration
    if form["pressed"] and form["pressed"] == "Done" then
      if form["summaryData"] then
        -- Parse JSON configuration from form
        local jsonStr = form["summaryData"]:gsub("^'", ""):gsub("'$", "")
        ---@type table
        local result = gKH.json.parse(jsonStr)
        local jammerDescriptors = result.ewUnits
        local abDeploymentDescriptors = result.bases

        -- Apply GPS jamming unit deployments
        if jammerDescriptors then
          for _, descriptor in ipairs(jammerDescriptors) do
            GPSJamming.addGPSJammer(descriptor, sideName)
          end
        end

        -- Apply aircraft and loadout configurations
        if abDeploymentDescriptors then
          UnitGenerator.addAircraft(abDeploymentDescriptors)
          UnitGenerator.initAircraftContexts(saveData.t.air.landBased)
        end
      end
    end
  end

  gKH.State.SaveTableToKey(saveData, "SaveData")
end

return UnitStatusUI
