local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GPSJamming = require("src.modules.EW.GPSJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local gKH = require('src.core.gKH_State_Standalone')

---Unit status user interface module
---Provides HTML table display functionality for various military unit statuses
---This module creates interactive web-based dashboards for monitoring:
--- - Landing unit counts by operational zone
--- - Command and control system status (IADS)
--- - Artillery battery status and reload times
--- - Base ammunition inventory
--- - EMCON settings configuration
--- - Comprehensive multi-tab status display
local UnitStatusUI = {}

---Count units of different types in each area
---Iterates through operational zones and counts specific military unit types
---Supports: ZBD-05, ZTD-05, PLL-05, PLZ-96, PGZ-09, PGZ-95, SA-15, AirborneCorps, HMMWV, ZBD-03
---@param config SBJ__CONFIG Configuration table
---@return table<string, table<string, number>> # Returns table with area names as keys and unit type counts as values
function UnitStatusUI.countUnitsInEachArea(config)
  local unitsFromChina = GameApi.VP_GetSide({ side = 'China' }).units
  local result = {}

  for _, zone in ipairs(config.c.PHIBOP.operationalZones) do
    local item = {
      ['ZBD-05'] = 0,
      ['ZTD-05'] = 0,
      ['PLL-05'] = 0,
      ['PLZ-96'] = 0,
      ['PGZ-09'] = 0,
      ['PGZ-95'] = 0,
      ['SA-15'] = 0,
      ['AirborneCorps'] = 0,
      ['HMMWV'] = 0,
      ['ZBD-03'] = 0
    }
    for _, value in ipairs(unitsFromChina) do
      local unit = GameApi.ScenEdit_GetUnit(value.guid)

      if unit and unit:inArea(zone.area) then
        if unit.dbid == config.platform.ZBD05 then
          item['ZBD-05'] = item['ZBD-05'] + 1
        end

        if unit.dbid == config.platform.ZTD05 then
          item['ZTD-05'] = item['ZTD-05'] + 1
        end

        if unit.dbid == config.platform.PLL05 then
          item['PLL-05'] = item['PLL-05'] + 1
        end

        if unit.dbid == config.platform.PLZ96 then
          item['PLZ-96'] = item['PLZ-96'] + 1
        end

        if unit.dbid == config.platform.PGZ09 then
          item['PGZ-09'] = item['PGZ-09'] + 1
        end

        if unit.dbid == config.platform.PGZ95 then
          item['PGZ-95'] = item['PGZ-95'] + 1
        end

        if unit.dbid == config.platform.SA15 then
          item['SA-15'] = item['SA-15'] + 1
        end

        if unit.dbid == config.platform.MC then
          item['AirborneCorps'] = item['AirborneCorps'] + 1
        end

        if unit.dbid == config.platform.HMMWV then
          item['HMMWV'] = item['HMMWV'] + 1
        end

        if unit.dbid == config.platform.ZBD03 then
          item['ZBD-03'] = item['ZBD-03'] + 1
        end
      end
    end

    result[zone.name] = item
  end

  return result
end

---Generates the HTML template for the WCS (Weapon Control System) settings UI
---This template provides a web-based interface for configuring WCS settings,
---specifically for setting units to 'hold' status.
---@return string # Returns an HTML string representing the WCS settings page
local function getWCSSettingTemplate()
  return [[
    <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Set WCS to hold</title>
    <style>
        body {
            background-color: #1a1a1a;
            color: #ffffff;
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }

        .container {
            background-color: #2d2d2d;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
        }

        h1 {
            text-align: center;
            color: #ffffff;
            margin-bottom: 2rem;
        }

        .checkbox-group {
            margin: 1rem 0;
            display: flex;
            align-items: center;
        }

        input[type="checkbox"] {
            appearance: none;
            width: 20px;
            height: 20px;
            background-color: #404040;
            border: 2px solid #666;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }

        input[type="checkbox"]:checked {
            background-color: #00cc00;
            position: relative;
        }

        input[type="checkbox"]:checked::after {
            content: 'âœ"';
            position: absolute;
            color: #fff;
            left: 4px;
            top: 0;
        }

        label {
            font-size: 1.1rem;
            cursor: pointer;
        }

        label:hover {
            color: #cccccc;
        }
    </style>
</head>

<body>
    <div class="container">
        <h2>EMCON Settings</h2>
        <div class="checkbox-group">
            <input type="checkbox" id="pac23" name="pac23">
            <label for="pac23">Pac-2/3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="skybow3" name="skybow3">
            <label for="skybow3">Sky Bow-3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="tc2" name="tc2">
            <label for="tc2">TC-2</label>
        </div>
    </div>
</body>

</html>
    ]]
end

---Display HTML dialog for weapon control status settings table, allows EMCON status configuration
---Creates an interactive checkbox interface for configuring EMCON settings
---Supports Pac-2/3, Sky Bow-3, and TC-2 weapon systems
---Updates weapon control status and emission settings based on user selection
---@param config SBJ__CONFIG Configuration table
function UnitStatusUI.wcsSettingTable(config)
  local units = GameApi.VP_GetSide({ side = 'Taiwan' }):unitsBy(config.unitType.FACILITY)

  if not units then
    return
  end

  local HTMLTemplate = getWCSSettingTemplate()
  local msg = string.format(HTMLTemplate)
  local form = GameApi.UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })

  if form['pressed'] and form['pressed'] == 'Done' then
    if form['pac23'] and string.gsub(form['pac23'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.PAC3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form['skybow3'] and string.gsub(form['skybow3'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.CUSTOMED_TK3 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form['tc2'] and string.gsub(form['tc2'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(value.guid)

        if unit and unit.dbid == config.platform.TC2 then
          GameApi.ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          GameApi.ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end
  end
end

---Create JSON string for artillery battery status data
---Processes battery and ammunition section information for display
---Calculates reload times and remaining ammunition counts
---Handles different weapon system types (SRBM, MLRS, GLCM, ASCM, MRBM)
---@param config SBJ__CONFIG Configuration table
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
        local status = ''
        local missilesInAmmoVehicles = saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit]
            .wpnCurrent
        local ammoSec = saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit]
        local reloadTime = config[key].ground[wpnSystem].reloadTime / 60
        local missilesInAHA = saveData[key].ground[wpnSystem].ammunitions
            [saveData[key].ground[wpnSystem].resupplyUnits[bty.resupplyUnit].ammunition].wpnCurrent
        local batteryReloadTime = nil
        local ammoSectionReloadTime = nil

        if bty.state == 0 then
          status = 'STATIC'
        elseif bty.state == 1 then
          status = 'REPOSITIONING'
        elseif bty.state == 2 then
          status = 'RELOAD'
        else
          status = 'HIDE'
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

        if sideName == 'China' then
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
---Extracts weapon information from base magazines
---Processes deployed aircraft configurations and loadouts
---@param config SBJ__CONFIG Configuration table
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
        for _, wpn in ipairs(magazine['mag_weapons']) do
          table.insert(obj.wpns, {
            name = wpn['wpn_name'],
            currWpn = wpn['wpn_current'],
          })
        end
      end

      table.insert(rows, obj)
    end
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for C2 system status data
---Processes IADS (Integrated Air Defense System) node information
---Includes SAM and radar unit status, OODA loops, and communication status
---Handles different C2 node types (C2, ROCC, TAAOC)
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
        rows[type][item.guid]['SAM'] = {}

        for _, sam in pairs(item.SAM) do
          local unit = GameApi.ScenEdit_GetUnit(sam.guid)
          local isDestroyed = unit == nil
          rows[type][item.guid]['SAM'][sam.guid] = {
            name = sam.name,
            OODADetection = tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
            OODATargeting = tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
            isOutOfComms = sam.isOutOfComms,
            EMCONSetting = sam.EMCONSetting,
            isDestroyed = isDestroyed
          }
        end
      end

      if item.radar then
        rows[type][item.guid]['radar'] = {}

        for _, radar in pairs(item.radar) do
          local unit = GameApi.ScenEdit_GetUnit(radar.guid)
          local isDestroyed = unit == nil
          rows[type][item.guid]['radar'][radar.guid] = {
            name = radar.name,
            OODADetection = tostring(radar.currOODA.detection) .. '/' .. tostring(radar.OODA.detection),
            OODATargeting = tostring(radar.currOODA.targeting) .. '/' .. tostring(radar.OODA.targeting),
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
---Processes signal intelligence data with timestamp formatting
---Converts detected transmission information to display format
---@param saveData SBJ__SaveData Saved game data
---@param sideName string Side name ('China' or 'US')
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

---Get HTML template for comprehensive status dashboard
---Returns a complete HTML document with CSS styling and JavaScript functionality
---Features:
--- - Dark theme with military green color scheme
--- - Tabbed interface for different data types
--- - Dynamic table population with JavaScript
--- - Progress bars for reload status
--- - Responsive design with custom scrollbars
--- - Support for signal data, mobile launchers, C2 nodes, base weapons, landing units
---@return string # Complete HTML template with placeholders for data injection
local function getHTMLTemplate()
  return [[
    <!DOCTYPE html>
<html class="dark" lang="en">

<head>
  <meta charset="utf-8" />
  <title>Data Transfer</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-weight: 400;
      background-color: #1a2212;
      color: #41ec9d;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .container {
      width: 100%%;
      max-width: 1280px;
      margin: 0 auto;
    }

    /* Header styles */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 24px;
      border-bottom: 1px solid rgba(65, 236, 157, 0.2);
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .header-icon {
      width: 24px;
      height: 24px;
      color: #41ec9d;
    }

    .header-title {
      font-size: 18px;
      font-weight: 700;
      color: #41ec9d;
    }

    .header-right {
      display: flex;
      align-items: center;
      gap: 24px;
    }

    .nav {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .nav-link {
      font-size: 14px;
      font-weight: 500;
      color: #448053;
      text-decoration: none;
      transition: color 0.2s;
    }

    .nav-link:hover {
      color: #41ec9d;
    }

    .notification-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 40px;
      height: 40px;
      border-radius: 50%%;
      background-color: rgba(65, 236, 157, 0.2);
      border: none;
      color: #41ec9d;
      cursor: pointer;
      transition: background-color 0.2s;
    }

    .notification-btn:hover {
      background-color: rgba(65, 236, 157, 0.4);
    }

    .avatar {
      width: 32px;
      height: 32px;
      border-radius: 50%%;
      background-image: url("https://lh3.googleusercontent.com/aida-public/AB6AXuDWUb4QBe9cmHFCsJO-j7Or7hBbkRj8ONbEVCkamO_NuSqqVV0LaAf4xdjrSnargXGvRMHd-awtJMyeqshQV4brg8AgyUqnWkNimcu6OdXBzAJOMx3r73kRLjVKJ1I3jVjGhsgyJk-nINYy4Ylwlzpbl80DrUqKcM37y64oB6CK6yME-ij57-9bdXbUoRDqiaQkSBAkDVHvmIa63SFJXQvLYy4QBZXsz26jpVDdDg-EKHcW78iQwxAVsL6T5WEJJ6uR73NXjtWhV4A");
      background-size: cover;
      background-position: center;
      background-repeat: no-repeat;
    }

    /* Main content */
    .main {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 32px 16px;
    }

    .content-wrapper {
      width: 100%%;
      max-width: 1280px;
    }

    .title-section {
      margin-bottom: 24px;
      padding: 0 8px;
    }

    .title-wrapper {
      display: flex;
      align-items: flex-end;
      gap: 8px;
    }

    .main-title {
      font-size: 48px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: #41ec9d;
    }

    .subtitle {
      font-size: 14px;
      opacity: 0.8;
      color: #448053;
      margin-top: 4px;
    }

    /* Tab navigation */
    .tab-nav {
      display: flex;
      border-bottom: 1px solid rgba(65, 236, 157, 0.2);
    }

    .tab-btn {
      padding: 8px 16px;
      font-size: 14px;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border: none;
      background: none;
      color: #448053;
      cursor: pointer;
      transition: all 0.2s;
    }

    .tab-btn:hover {
      background-color: rgba(65, 236, 157, 0.05);
    }

    .tab-btn.active {
      background-color: rgba(65, 236, 157, 0.1);
      color: #41ec9d;
    }

    /* Tab content */
    .tab-content {
      display: none;
      overflow-x: auto;
      border: 1px solid rgba(65, 236, 157, 0.2);
      border-top: none;
      border-radius: 0 0 4px 4px;
      background-color: rgba(26, 34, 18, 0.5);
    }

    .tab-content.active {
      display: block;
    }

    .empty-content {
      padding: 64px 32px;
      text-align: center;
      color: #448053;
    }

    /* Table styles */
    .table {
      width: 100%%;
      border-collapse: collapse;
      text-align: left;
    }

    .table thead {
      background-color: rgba(65, 236, 157, 0.1);
    }

    .table th {
      padding: 12px 16px;
      font-size: 14px;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #41ec9d;
    }

    .table td {
      padding: 12px 16px;
      white-space: nowrap;
      color: #41ec9d;
      border-bottom: 1px solid rgba(65, 236, 157, 0.1);
    }

    .table tbody tr:hover {
      background-color: rgba(65, 236, 157, 0.05);
    }

    .table .text-right {
      text-align: right;
    }

    .table .text-left {
      text-align: left;
    }

    /* Status styles */
    .status-ready {
      color: #41ec9d;
      font-weight: bold;
    }

    .status-reloading {
      color: #f3d44e;
      font-weight: bold;
    }

    .status-standby {
      color: #f38a4e;
      font-weight: bold;
    }

    .status-offline {
      color: #c4c4c4;
      font-weight: bold;
    }

    .status-hide {
      color: #c4c4c4;
      font-weight: bold;
    }

    /* Progress bar styles */
    .progress-bar-container {
      border: 1px solid #41ec9d;
      height: 14px;
      width: 100%%;
      display: flex;
      background-color: rgba(65, 236, 157, 0.1);
    }

    .progress-bar-fill {
      background-color: #41ec9d;
      height: 100%%;
      transition: width 0.3s ease;
    }

    .progress-text {
      font-size: 12px;
      text-align: right;
      padding-top: 4px;
    }

    /* Blinking cursor animation */
    @keyframes blink-animation {
      to {
        visibility: hidden;
      }
    }

    .blinking-cursor {
      animation: blink-animation 1s steps(2, start) infinite;
      width: 8px;
      height: 1.2rem;
      display: inline-block;
      background-color: currentColor;
      margin-left: 4px;
    }

    /* Custom scrollbar styles */
    .tab-content::-webkit-scrollbar {
      height: 8px;
      width: 8px;
    }

    .tab-content::-webkit-scrollbar-track {
      background: rgba(65, 236, 157, 0.1);
      border-radius: 4px;
    }

    .tab-content::-webkit-scrollbar-thumb {
      background: #41ec9d;
      border-radius: 4px;
      transition: background 0.2s;
    }

    .tab-content::-webkit-scrollbar-thumb:hover {
      background: #35c485;
    }

    .tab-content::-webkit-scrollbar-corner {
      background: rgba(65, 236, 157, 0.1);
    }

    /* Firefox scrollbar styles */
    .tab-content {
      scrollbar-width: thin;
      scrollbar-color: #41ec9d rgba(65, 236, 157, 0.1);
    }

    /* Hidden column utility */
    .hidden-column {
      display: none !important;
    }

    /* Responsive */
    @media (max-width: 768px) {
      .main-title {
        font-size: 32px;
      }

      .header {
        padding: 12px 16px;
      }

      .nav {
        display: none;
      }
    }
  </style>
</head>

<body>
  <div>
    <main class="main">
      <div class="content-wrapper">
        <div id="app">
          <div class="tab-nav">
            <button class="tab-btn active" data-tab="signal-data">Signal Data</button>
            <button class="tab-btn" data-tab="mobile-launchers">Mobile Missile Launchers</button>
            <button class="tab-btn" data-tab="c2-nodes">C2 Nodes</button>
            <button class="tab-btn" data-tab="base-weapons">Base Weapons</button>
            <button class="tab-btn" data-tab="landing-units">Landing Units</button>
          </div>

          <div id="signal-data" class="tab-content active">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Autodetectable</th>
                  <th class="hidden-column">Latitude</th>
                  <th class="hidden-column">Longitude</th>
                  <th>First Detected</th>
                  <th>Last Detected</th>
                  <th class="text-right">Detection Count</th>
                  <th class="text-right">Confidence</th>
                  <th class="text-right">Current Detection Level</th>
                </tr>
              </thead>
              <tbody id="signal-tbody">
                <!-- Data will be populated by JavaScript -->
              </tbody>
            </table>
          </div>

          <div id="mobile-launchers" class="tab-content">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th class="text-left" style="width: 200px;">Battery Reload</th>
                  <th class="text-left" style="width: 200px;">Ammo Section Reload</th>
                  <th>Missiles (Ammo Vehicles)</th>
                  <th>Missiles (AHA)</th>
                </tr>
              </thead>
              <tbody id="launcher-tbody">
                <!-- Data will be populated by JavaScript -->
              </tbody>
            </table>
          </div>

          <div id="c2-nodes" class="tab-content">
            <table class="table">
              <thead>
                <tr>
                  <th>C2 Node</th>
                  <th>Name</th>
                  <th>OODA Detection</th>
                  <th>OODA Targeting</th>
                  <th>Out of Comms</th>
                  <th>EMCON Setting</th>
                  <th>Destroyed</th>
                </tr>
              </thead>
              <tbody id="c2-tbody">
                <!-- Data will be populated by JavaScript -->
              </tbody>
            </table>
          </div>

          <div id="base-weapons" class="tab-content">
            <table class="table">
              <thead>
                <tr>
                  <th>Base Name</th>
                  <th>Weapon Name</th>
                  <th>Current Weapons</th>
                </tr>
              </thead>
              <tbody id="base-weapons-tbody">
                <!-- Data will be populated by JavaScript -->
              </tbody>
            </table>
          </div>

          <div id="landing-units" class="tab-content">
            <table class="table">
              <thead>
                <tr>
                  <th>Area</th>
                  <th>Unit Type</th>
                  <th>Count</th>
                </tr>
              </thead>
              <tbody id="landing-units-tbody">
                <!-- Data will be populated by JavaScript -->
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
  </div>

  <script>
    // Application data
    const appData = {
      activeTab: 'signal-data'
    };

    // Units data
    const unitsString = `%s`;

    const units = JSON.parse(unitsString);

    // Signals data
    const signalsString = `%s`;

    const signals = JSON.parse(signalsString);

    // C2 nodes data
    const dataString = `%s`;

    const c2Data = JSON.parse(dataString);

    // Base weapons data
    const baseWeaponsString = `%s`;

    const baseWeaponsData = JSON.parse(baseWeaponsString);

    // Landing units data
    const landingUnitsString = `%s`;

    const landingUnitsData = JSON.parse(landingUnitsString);

    // Tab switching functionality
    function initTabs() {
      const tabButtons = document.querySelectorAll('.tab-btn');
      const tabContents = document.querySelectorAll('.tab-content');

      // Hide tabs if corresponding data is empty
      tabButtons.forEach(button => {
        const targetTab = button.getAttribute('data-tab');
        let shouldHide = false;

        switch (targetTab) {
          case 'signal-data':
            shouldHide = !signals || !Array.isArray(signals) || signals.length === 0;
            break;
          case 'mobile-launchers':
            shouldHide = !units || typeof units !== 'object' || Object.keys(units).length === 0;
            break;
          case 'c2-nodes':
            shouldHide = !c2Data || typeof c2Data !== 'object' || Object.keys(c2Data).length === 0;
            break;
          case 'base-weapons':
            shouldHide = !baseWeaponsData || !Array.isArray(baseWeaponsData) || baseWeaponsData.length === 0;
            break;
          case 'landing-units':
            shouldHide = !landingUnitsData || typeof landingUnitsData !== 'object' || Object.keys(landingUnitsData).length === 0;
            break;
        }

        if (shouldHide) {
          button.style.display = 'none';
          // Also hide the corresponding content
          const content = document.getElementById(targetTab);
          if (content) {
            content.style.display = 'none';
          }
        }
      });

      // Find first visible tab and make it active
      const visibleButtons = Array.from(tabButtons).filter(btn => btn.style.display !== 'none');
      if (visibleButtons.length > 0) {
        // Remove active from all tabs first
        tabButtons.forEach(btn => btn.classList.remove('active'));
        tabContents.forEach(content => content.classList.remove('active'));

        // Set first visible tab as active
        const firstVisibleTab = visibleButtons[0].getAttribute('data-tab');
        visibleButtons[0].classList.add('active');
        const firstVisibleContent = document.getElementById(firstVisibleTab);
        if (firstVisibleContent) {
          firstVisibleContent.classList.add('active');
        }
        appData.activeTab = firstVisibleTab;
      }

      tabButtons.forEach(button => {
        button.addEventListener('click', () => {
          const targetTab = button.getAttribute('data-tab');

          // Update active tab
          appData.activeTab = targetTab;

          // Update button states
          tabButtons.forEach(btn => btn.classList.remove('active'));
          button.classList.add('active');

          // Update content visibility
          tabContents.forEach(content => {
            content.classList.remove('active');
            if (content.id === targetTab) {
              content.classList.add('active');
            }
          });
        });
      });
    }

    // Render launcher table
    function renderLauncherTable() {
      const tbody = document.getElementById('launcher-tbody');
      tbody.innerHTML = '';

      // Check if units is empty object
      if (!units || typeof units !== 'object' || Object.keys(units).length === 0) {
        return;
      }

      // units is already grouped by area from createBatteryDataString
      Object.keys(units).forEach(area => {
        const areaUnits = units[area];
        areaUnits.forEach((unit, index) => {
          const row = document.createElement('tr');

          const batteryProgress = unit.batteryReloadTime !== null && unit.batteryReloadTime >= 0
            ? Math.round((unit.batteryReloadTime / unit.defaultReloadTime) * 100)
            : 0;

          const ammoProgress = unit.ammoSectionReloadTime !== null && unit.ammoSectionReloadTime >= 0
            ? Math.round((unit.ammoSectionReloadTime / unit.defaultReloadTime) * 100)
            : 0;

          row.innerHTML = `
            <td>${unit.name}</td>
            <td>${unit.type.toUpperCase()}</td>
            <td class="status-${unit.status.toLowerCase()}">${unit.status}</td>
            <td>
              ${unit.batteryReloadTime !== null && unit.batteryReloadTime >= 0 ? `
                <div class="progress-bar-container">
                  <div class="progress-bar-fill" style="width: ${batteryProgress}%%"></div>
                </div>
                <div class="progress-text">${batteryProgress}%%</div>
              ` : ''}
            </td>
            <td>
              ${unit.ammoSectionReloadTime !== null && unit.ammoSectionReloadTime >= 0 ? `
                <div class="progress-bar-container">
                  <div class="progress-bar-fill" style="width: ${ammoProgress}%%"></div>
                </div>
                <div class="progress-text">${ammoProgress}%%</div>
              ` : ''}
            </td>
            ${index === 0 ? `
              <td rowspan="${areaUnits.length}">${unit.missilesInAmmoVehicles}</td>
              <td rowspan="${areaUnits.length}">${unit.missilesInAHA}</td>
            ` : ''}
          `;

          tbody.appendChild(row);
        });
      });
    }

    // Render signal data table
    function renderSignalTable() {
      const tbody = document.getElementById('signal-tbody');
      if (!tbody) {
        console.error('signal-tbody element not found');
        return;
      }
      tbody.innerHTML = '';

      if (!signals || !Array.isArray(signals) || signals.length === 0) {
        return;
      }

      signals.forEach(signal => {
        const row = document.createElement('tr');

        // Format coordinates with null checks
        const latitude = signal.latitude || 0;
        const longitude = signal.longitude || 0;
        const latDir = latitude >= 0 ? 'N' : 'S';
        const lonDir = longitude >= 0 ? 'E' : 'W';
        const formattedLat = `${Math.abs(latitude).toFixed(4)}° ${latDir}`;
        const formattedLon = `${Math.abs(longitude).toFixed(4)}° ${lonDir}`;

        row.innerHTML = `
          <td>${signal.name || 'N/A'}</td>
          <td>${signal.type ? signal.type.toUpperCase() : 'N/A'}</td>
          <td>${signal.autodetectable ? 'TRUE' : 'FALSE'}</td>
          <td class="hidden-column">${formattedLat}</td>
          <td class="hidden-column">${formattedLon}</td>
          <td>${signal.firstDetected || 'N/A'}</td>
          <td>${signal.lastDetected || 'N/A'}</td>
          <td class="text-right">${signal.detectionCount || 0}</td>
          <td class="text-right">${signal.confidence * 100 || 0}%%</td>
          <td class="text-right">${signal.currentDetectionLevel || 0}</td>
        `;

        tbody.appendChild(row);
      });
    }

    // Render C2 nodes table
    function renderC2Table() {
      const tbody = document.getElementById('c2-tbody');
      if (!tbody) {
        console.error('c2-tbody element not found');
        return;
      }
      tbody.innerHTML = '';

      // Check if c2Data is empty object
      if (!c2Data || typeof c2Data !== 'object' || Object.keys(c2Data).length === 0) {
        return;
      }

      Object.keys(c2Data).forEach(c2NodeType => {
        const nodeGroup = c2Data[c2NodeType];
        if (!nodeGroup || typeof nodeGroup !== 'object') {
          console.error(`Node group ${c2NodeType} is not an object:`, nodeGroup);
          return;
        }

        Object.keys(nodeGroup).forEach(nodeName => {
          const node = nodeGroup[nodeName];
          if (!node || typeof node !== 'object') {
            console.error(`Node ${nodeName} is not an object:`, node);
            return;
          }

          // Count total units for this node (SAM + radar)
          let totalUnits = 0;
          if (node.SAM) totalUnits += Object.keys(node.SAM).length;
          if (node.radar) totalUnits += Object.keys(node.radar).length;

          let isFirstRow = true;

          // Process SAM units
          if (node.SAM) {
            Object.keys(node.SAM).forEach(unitName => {
              const unit = node.SAM[unitName];
              const row = document.createElement('tr');

              row.innerHTML = `
                ${isFirstRow ? `<td rowspan="${totalUnits}">${node.name}</td>` : ''}
                <td>${unit.name} (SAM)</td>
                <td>${unit.OODADetection}</td>
                <td>${unit.OODATargeting}</td>
                <td class="${unit.isOutOfComms ? 'status-offline' : 'status-ready'}">${unit.isOutOfComms ? 'YES' : 'NO'}</td>
                <td class="${unit.EMCONSetting === 'ON' ? 'status-ready' : 'status-standby'}">${unit.EMCONSetting}</td>
                <td class="${unit.isDestroyed ? 'status-offline' : 'status-ready'}">${unit.isDestroyed ? 'YES' : 'NO'}</td>
              `;

              tbody.appendChild(row);
              isFirstRow = false;
            });
          }

          // Process radar units
          if (node.radar) {
            Object.keys(node.radar).forEach(unitName => {
              const unit = node.radar[unitName];
              const row = document.createElement('tr');

              row.innerHTML = `
                ${isFirstRow ? `<td rowspan="${totalUnits}">${nodeName}</td>` : ''}
                <td>${unit.name} (Radar)</td>
                <td>${unit.OODADetection}</td>
                <td>${unit.OODATargeting}</td>
                <td class="${unit.isOutOfComms ? 'status-offline' : 'status-ready'}">${unit.isOutOfComms ? 'YES' : 'NO'}</td>
                <td class="${unit.EMCONSetting === 'ON' ? 'status-ready' : 'status-standby'}">${unit.EMCONSetting}</td>
                <td class="${unit.isDestroyed ? 'status-offline' : 'status-ready'}">${unit.isDestroyed ? 'YES' : 'NO'}</td>
              `;

              tbody.appendChild(row);
              isFirstRow = false;
            });
          }
        });
      });
    }

    // Render base weapons table
    function renderBaseWeaponsTable() {
      const tbody = document.getElementById('base-weapons-tbody');
      if (!tbody) {
        console.error('base-weapons-tbody element not found');
        return;
      }
      tbody.innerHTML = '';

      // Check if baseWeaponsData is empty array
      if (!baseWeaponsData || !Array.isArray(baseWeaponsData) || baseWeaponsData.length === 0) {
        return;
      }

      baseWeaponsData.forEach((base, baseIndex) => {
        if (!base.wpns || !Array.isArray(base.wpns)) {
          console.error(`Base ${baseIndex} has no wpns array:`, base);
          return;
        }

        const weaponCount = base.wpns.length;
        let isFirstRow = true;

        base.wpns.forEach(weapon => {
          const row = document.createElement('tr');

          row.innerHTML = `
            ${isFirstRow ? `<td rowspan="${weaponCount}">${base.name}</td>` : ''}
            <td>${weapon.name}</td>
            <td>${weapon.currWpn}</td>
          `;

          tbody.appendChild(row);
          isFirstRow = false;
        });
      });
    }

    // Render landing units table
    function renderLandingUnitsTable() {
      const tbody = document.getElementById('landing-units-tbody');
      if (!tbody) {
        console.error('landing-units-tbody element not found');
        return;
      }
      tbody.innerHTML = '';

      // Check if landingUnitsData is empty object
      if (!landingUnitsData || typeof landingUnitsData !== 'object' || Object.keys(landingUnitsData).length === 0) {
        return;
      }

      Object.keys(landingUnitsData).forEach(area => {
        const units = landingUnitsData[area];
        if (!units || typeof units !== 'object') {
          console.error(`Area ${area} has no units object:`, units);
          return;
        }

        const unitTypes = Object.keys(units);
        const unitCount = unitTypes.length;
        let isFirstRow = true;

        unitTypes.forEach(unitType => {
          const count = units[unitType];
          const row = document.createElement('tr');

          row.innerHTML = `
            ${isFirstRow ? `<td rowspan="${unitCount}">${area}</td>` : ''}
            <td>${unitType}</td>
            <td>${count}</td>
          `;

          tbody.appendChild(row);
          isFirstRow = false;
        });
      });
    }

    // Initialize application
    function init() {
      initTabs();
      renderLauncherTable();
      renderSignalTable();
      renderC2Table();
      renderBaseWeaponsTable();
      renderLandingUnitsTable();
    }

    // Start application when DOM is loaded
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
    } else {
      init();
    }
  </script>
</body>

</html>
    ]]
end

---Get HTML template for setup menu
---@return string # Setup menu template
local function getSetupMenuTemplate()
  return [[
    <!DOCTYPE html>
<html class="dark" lang="en">

<head>
  <meta charset="utf-8" />
  <title>Taiwan Deployment Planning Tool</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-weight: 400;
      background-color: #1e1e1e;
      color: #e0e0e0;
      min-height: 100vh;
    }

    .container {
      max-width: 1800px;
      margin: 0 auto;
      padding: 24px;
    }

    /* Header with tabs */
    .header {
      background-color: #2d2d2d;
      border: 1px solid #3d3d3d;
      border-radius: 6px 6px 0 0;
      margin-bottom: -1px;
    }

    .header-title {
      padding: 20px 24px;
      border-bottom: 1px solid #3d3d3d;
    }

    .title-text {
      font-size: 18px;
      font-weight: 600;
      color: #ffffff;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    /* Tab Navigation - Palantir Style */
    .tab-nav {
      display: flex;
      gap: 4px;
      padding: 16px 20px 0 20px;
      background-color: #2d2d2d;
    }

    .tab-btn {
      padding: 10px 16px;
      font-size: 13px;
      font-weight: 500;
      border: none;
      background: none;
      color: #a0a0a0;
      cursor: pointer;
      transition: all 0.2s;
      border-bottom: 2px solid transparent;
    }

    .tab-btn:hover {
      color: #ffffff;
      background-color: #353535;
    }

    .tab-btn.active {
      color: #00b894;
      border-bottom-color: #00b894;
    }

    /* Page Container */
    .page-container {
      background-color: #2d2d2d;
      border: 1px solid #3d3d3d;
      border-radius: 0 0 6px 6px;
      min-height: calc(100vh - 200px);
    }

    .page-content {
      display: none;
    }

    .page-content.active {
      display: block;
    }

    /* Layout for pages with map */
    .map-layout {
      display: flex;
      gap: 24px;
      padding: 24px;
    }

    .map-section {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .sidebar-section {
      width: 400px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    /* Card styles */
    .card {
      background-color: #252525;
      border: 1px solid #3d3d3d;
      border-radius: 6px;
      overflow: hidden;
    }

    .card-header {
      padding: 16px 20px;
      border-bottom: 1px solid #3d3d3d;
    }

    .card-title {
      font-size: 14px;
      font-weight: 600;
      color: #ffffff;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .card-body {
      padding: 20px;
    }

    /* Map */
    .map-container {
      height: 600px;
      border-radius: 4px;
      overflow: hidden;
    }

    /* Coordinates display */
    .coordinates-display {
      padding: 16px;
      background-color: #1e1e1e;
      border-radius: 4px;
    }

    .coordinates-label {
      font-size: 12px;
      color: #a0a0a0;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 8px;
    }

    .coordinates-text {
      font-size: 16px;
      font-weight: 500;
      color: #00b894;
      font-family: 'Courier New', monospace;
    }

    /* Budget Display */
    .budget-display {
      padding: 20px;
      background: linear-gradient(135deg, #1e1e1e 0%%, #252525 100%%);
      border-radius: 4px;
      text-align: center;
    }

    .budget-label {
      font-size: 12px;
      color: #a0a0a0;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      margin-bottom: 12px;
    }

    .budget-value {
      font-size: 48px;
      font-weight: 700;
      color: #00b894;
      font-family: 'Courier New', monospace;
      margin-bottom: 8px;
      transition: color 0.3s ease;
    }

    .budget-value.warning {
      color: #ffa502;
    }

    .budget-value.danger {
      color: #ff6b6b;
    }

    .budget-details {
      font-size: 13px;
      color: #a0a0a0;
      margin-bottom: 16px;
    }

    .budget-progress {
      width: 100%%;
      height: 8px;
      background-color: #1e1e1e;
      border-radius: 4px;
      overflow: hidden;
    }

    .budget-progress-bar {
      height: 100%%;
      background: linear-gradient(90deg, #00b894 0%%, #00d2a0 100%%);
      transition: width 0.3s ease, background 0.3s ease;
      border-radius: 4px;
    }

    .budget-progress-bar.warning {
      background: linear-gradient(90deg, #ffa502 0%%, #ffb733 100%%);
    }

    .budget-progress-bar.danger {
      background: linear-gradient(90deg, #ff6b6b 0%%, #ff8787 100%%);
    }

    /* Base Editor */
    .base-editor {
      max-height: 500px;
      overflow-y: auto;
    }

    .base-editor.empty {
      padding: 32px 16px;
      text-align: center;
      color: #6c757d;
      font-size: 13px;
    }

    .base-editor-header {
      font-size: 15px;
      font-weight: 600;
      color: #00b894;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 2px solid #3d3d3d;
    }

    .base-editor-section {
      margin-bottom: 20px;
    }

    .base-editor-section:last-child {
      margin-bottom: 0;
    }

    .section-title {
      font-size: 13px;
      font-weight: 600;
      color: #ffffff;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 12px;
      padding-bottom: 6px;
      border-bottom: 1px solid #3d3d3d;
    }

    /* Loadout Controls */
    .loadout-controls {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin: 8px 0;
      padding: 12px;
      background-color: rgba(0, 0, 0, 0.3);
      border-radius: 4px;
      border: 1px solid #3d3d3d;
    }

    .loadout-info {
      flex: 1;
    }

    .loadout-name {
      font-weight: 600;
      color: #ffffff;
      margin-bottom: 4px;
      font-size: 13px;
    }

    .loadout-cost {
      font-size: 10px;
      color: #a0a0a0;
    }

    .loadout-actions {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .loadout-btn {
      width: 28px;
      height: 28px;
      border: 1px solid #3d3d3d;
      background-color: #2d2d2d;
      color: #00b894;
      border-radius: 4px;
      cursor: pointer;
      font-size: 16px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
      user-select: none;
    }

    .loadout-btn:hover:not(:disabled) {
      background-color: #00b894;
      color: #ffffff;
      border-color: #00b894;
      transform: scale(1.1);
    }

    .loadout-btn:disabled {
      opacity: 0.3;
      cursor: not-allowed;
      color: #6c757d;
    }

    .loadout-quantity {
      min-width: 30px;
      text-align: center;
      font-weight: 600;
      font-size: 14px;
      color: #00b894;
      font-family: 'Courier New', monospace;
    }

    /* EW Units */
    .ew-units-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
      max-height: 400px;
      overflow-y: auto;
    }

    .ew-unit-btn {
      padding: 14px 16px;
      background-color: #1e1e1e;
      border: 1px solid #3d3d3d;
      border-radius: 4px;
      color: #e0e0e0;
      cursor: pointer;
      transition: all 0.2s ease;
      text-align: left;
    }

    .ew-unit-btn:hover {
      background-color: #2d2d2d;
      border-color: #00b894;
    }

    .ew-unit-btn.selected {
      background-color: rgba(0, 184, 148, 0.15);
      border-color: #00b894;
      box-shadow: 0 0 0 1px #00b894;
    }

    .ew-unit-btn.deployed {
      background-color: rgba(108, 117, 125, 0.2);
      border-color: #6c757d;
      color: #a0a0a0;
      position: relative;
    }

    .ew-unit-btn.deployed:hover {
      background-color: rgba(220, 53, 69, 0.15);
      border-color: #dc3545;
      color: #dc3545;
    }

    .ew-unit-btn.deployed::after {
      content: "Click to cancel deployment";
      position: absolute;
      top: -30px;
      left: 50%%;
      transform: translateX(-50%%);
      background-color: rgba(0, 0, 0, 0.9);
      color: white;
      padding: 6px 12px;
      border-radius: 4px;
      font-size: 11px;
      white-space: nowrap;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.2s ease;
      z-index: 1000;
    }

    .ew-unit-btn.deployed:hover::after {
      opacity: 1;
    }

    .unit-name {
      font-weight: 600;
      font-size: 13px;
      margin-bottom: 4px;
      color: #ffffff;
    }

    .ew-unit-btn.deployed .unit-name {
      color: #a0a0a0;
    }

    .ew-unit-btn.deployed:hover .unit-name {
      color: #dc3545;
    }

    .unit-zone {
      font-size: 11px;
      color: #a0a0a0;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    /* Deployment Status */
    .deployment-status {
      padding: 14px 16px;
      background-color: #1e1e1e;
      border-radius: 4px;
      font-size: 13px;
      color: #a0a0a0;
      line-height: 1.6;
    }

    /* Summary Page */
    .summary-layout {
      padding: 24px;
      max-width: 1200px;
      margin: 0 auto;
    }

    .summary-section {
      margin-bottom: 24px;
      padding: 20px;
      background-color: #252525;
      border-radius: 6px;
      border: 1px solid #3d3d3d;
    }

    .summary-title {
      font-size: 16px;
      font-weight: 600;
      color: #00b894;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 2px solid #3d3d3d;
    }

    .summary-item {
      display: flex;
      justify-content: space-between;
      padding: 10px 0;
      border-bottom: 1px solid #3d3d3d;
      font-size: 14px;
    }

    .summary-item:last-child {
      border-bottom: none;
    }

    .summary-label {
      color: #a0a0a0;
    }

    .summary-value {
      color: #00b894;
      font-weight: 600;
      font-family: 'Courier New', monospace;
    }

    .base-breakdown {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 16px;
      margin-top: 16px;
    }

    .base-card {
      padding: 16px;
      background-color: rgba(0, 0, 0, 0.3);
      border-radius: 4px;
      border: 1px solid #3d3d3d;
    }

    .base-card-title {
      font-weight: 600;
      color: #00b894;
      margin-bottom: 12px;
      font-size: 14px;
    }

    .base-card-item {
      display: flex;
      justify-content: space-between;
      padding: 6px 0;
      font-size: 13px;
    }

    .export-btn {
      width: 100%%;
      padding: 14px 20px;
      background-color: #00b894;
      color: #ffffff;
      border: none;
      border-radius: 4px;
      font-size: 14px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      cursor: pointer;
      transition: all 0.2s ease;
      margin-top: 16px;
    }

    .export-btn:hover {
      background-color: #00d2a0;
      transform: translateY(-1px);
      box-shadow: 0 4px 8px rgba(0, 184, 148, 0.3);
    }

    /* Popup */
    .base-popup {
      min-width: 280px;
    }

    .popup-section {
      margin-bottom: 12px;
    }

    .popup-section:last-child {
      margin-bottom: 0;
    }

    .popup-section-title {
      font-weight: 600;
      color: #ffffff;
      margin-bottom: 8px;
      padding-bottom: 4px;
      border-bottom: 1px solid #3d3d3d;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .popup-item {
      padding: 6px 0;
      font-size: 12px;
      color: #a0a0a0;
      display: flex;
      justify-content: space-between;
    }

    .popup-item-name {
      color: #e0e0e0;
    }

    .popup-item-count {
      color: #00b894;
      font-weight: 600;
      font-family: 'Courier New', monospace;
    }

    .edit-loadouts-btn {
      width: 100%%;
      padding: 10px 16px;
      background-color: #00b894;
      color: #ffffff;
      border: none;
      border-radius: 4px;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      cursor: pointer;
      transition: all 0.2s ease;
      margin-top: 12px;
    }

    .edit-loadouts-btn:hover {
      background-color: #00d2a0;
    }

    /* Leaflet overrides */
    .leaflet-control-container .leaflet-control-attribution {
      background-color: rgba(45, 45, 45, 0.9);
      color: #a0a0a0;
      border: 1px solid #3d3d3d;
      font-size: 11px;
    }

    .leaflet-control-container .leaflet-control-attribution a {
      color: #00b894;
    }

    .leaflet-control-zoom a {
      background-color: #2d2d2d;
      color: #e0e0e0;
      border: 1px solid #3d3d3d;
    }

    .leaflet-control-zoom a:hover {
      background-color: #3d3d3d;
    }

    .leaflet-popup-content-wrapper {
      background-color: #2d2d2d;
      color: #e0e0e0;
      border: 1px solid #3d3d3d;
      border-radius: 4px;
    }

    .leaflet-popup-tip {
      background-color: #2d2d2d;
      border-color: #3d3d3d;
    }

    .leaflet-popup-close-button {
      color: #a0a0a0 !important;
    }

    .leaflet-popup-close-button:hover {
      color: #ffffff !important;
    }

    /* Scrollbar */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }

    ::-webkit-scrollbar-track {
      background: #2d2d2d;
    }

    ::-webkit-scrollbar-thumb {
      background: #4d4d4d;
      border-radius: 4px;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: #5d5d5d;
    }

    /* Responsive */
    @media (max-width: 1024px) {
      .map-layout {
        flex-direction: column;
      }

      .sidebar-section {
        width: 100%%;
      }

      .map-container {
        height: 400px;
      }
    }
  </style>
</head>

<body>
  <div class="container">
    <!-- Header with Tabs -->
    <div class="header">
      <div class="header-title">
        <div class="title-text">Taiwan Deployment Planning Tool</div>
      </div>
      <div class="tab-nav">
        <button class="tab-btn active" data-tab="aircraft">Aircraft & Loadouts</button>
        <button class="tab-btn" data-tab="jammers">GPS Jammers</button>
        <button class="tab-btn" data-tab="summary">Summary</button>
      </div>
    </div>

    <!-- Page Container -->
    <div class="page-container">
      <!-- Aircraft & Loadouts Page -->
      <div id="aircraftPage" class="page-content active">
        <div class="map-layout">
          <!-- Map Section -->
          <div class="map-section">
            <div class="card">
              <div class="card-header">
                <div class="card-title">Taiwan Map</div>
              </div>
              <div class="card-body">
                <div id="aircraftMap" class="map-container"></div>
              </div>
            </div>

            <div class="card">
              <div class="card-body">
                <div class="coordinates-display">
                  <div class="coordinates-label">Selected Coordinates</div>
                  <div id="aircraftCoordinates" class="coordinates-text">Click map to get coordinates</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="sidebar-section">
            <div class="card">
              <div class="card-header">
                <div class="card-title">Loadout Budget</div>
              </div>
              <div class="card-body">
                <div class="budget-display">
                  <div class="budget-label">Remaining Budget</div>
                  <div id="budgetValue" class="budget-value">1000</div>
                  <div id="budgetDetails" class="budget-details">Used: 0 / Total: 1000</div>
                  <div class="budget-progress">
                    <div id="budgetProgressBar" class="budget-progress-bar" style="width: 100%%"></div>
                  </div>
                </div>
              </div>
            </div>

            <div class="card">
              <div class="card-header">
                <div class="card-title">Base Editor</div>
              </div>
              <div class="card-body">
                <div id="baseEditor" class="base-editor empty">
                  Click on an airbase marker to edit loadouts
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- GPS Jammers Page -->
      <div id="jammersPage" class="page-content">
        <div class="map-layout">
          <!-- Map Section -->
          <div class="map-section">
            <div class="card">
              <div class="card-header">
                <div class="card-title">Taiwan Map</div>
              </div>
              <div class="card-body">
                <div id="jammersMap" class="map-container"></div>
              </div>
            </div>

            <div class="card">
              <div class="card-body">
                <div class="coordinates-display">
                  <div class="coordinates-label">Selected Coordinates</div>
                  <div id="jammersCoordinates" class="coordinates-text">Click map to get coordinates</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="sidebar-section">
            <div class="card">
              <div class="card-header">
                <div class="card-title">EW Units Deployment</div>
              </div>
              <div class="card-body">
                <div class="ew-units-list" id="ewUnitsList">
                  <!-- EW unit buttons will be generated here -->
                </div>
              </div>
            </div>

            <div class="card">
              <div class="card-body">
                <div class="deployment-status" id="deploymentStatus">
                  Select an EW unit then click on the map to deploy
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Summary Page -->
      <div id="summaryPage" class="page-content">
        <div class="summary-layout">
          <input type="hidden" id="summaryData" name="summaryData">
          <div id="summaryContent">
            <!-- Summary content will be generated here -->
          </div>
        </div>
      </div>
    </div>
  </div>

  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    // Data
    const ewUnitString = `%s`;
    const ewUnitsData = JSON.parse(ewUnitString);

    const baseString = `%s`;
    const basesData = JSON.parse(baseString);

    // State
    const LOADOUT_COST = 100;
    const INITIAL_SCORE = 1000;
    let currentScore = INITIAL_SCORE;
    let usedScore = 0;
    let selectedEWUnit = null;
    let deployedUnits = new Map();
    let ewMarkers = [];
    let aircraftMap, jammersMap;
    let currentEditingBase = null;

    const taiwanBoundary = [
      [25.295, 121.565], [25.085, 121.566], [24.967, 121.187], [24.814, 120.967],
      [24.574, 120.815], [24.147, 120.674], [23.957, 120.434], [23.695, 120.451],
      [23.479, 120.449], [23.308, 120.311], [22.627, 120.301], [22.336, 120.548],
      [22.789, 121.154], [23.121, 121.364], [23.326, 121.365], [23.583, 121.513],
      [23.993, 121.601], [24.178, 121.602], [24.265, 121.735], [24.756, 121.758],
      [25.295, 121.565]
    ];

    // Tab Management
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const targetTab = btn.dataset.tab;
        switchTab(targetTab);
      });
    });

    function switchTab(tabName) {
      document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.tab === tabName) {
          btn.classList.add('active');
        }
      });

      document.querySelectorAll('.page-content').forEach(page => {
        page.classList.remove('active');
      });

      if (tabName === 'aircraft') {
        document.getElementById('aircraftPage').classList.add('active');
        setTimeout(() => {
          if (aircraftMap) aircraftMap.invalidateSize();
        }, 100);
      } else if (tabName === 'jammers') {
        document.getElementById('jammersPage').classList.add('active');
        setTimeout(() => {
          if (jammersMap) jammersMap.invalidateSize();
        }, 100);
      } else if (tabName === 'summary') {
        document.getElementById('summaryPage').classList.add('active');
        updateSummary();
      }
    }

    // Taiwan boundary check
    function isPointInTaiwan(lat, lng) {
      let inside = false;
      const x = lng, y = lat;
      for (let i = 0, j = taiwanBoundary.length - 1; i < taiwanBoundary.length; j = i++) {
        const xi = taiwanBoundary[i][1], yi = taiwanBoundary[i][0];
        const xj = taiwanBoundary[j][1], yj = taiwanBoundary[j][0];
        if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
          inside = !inside;
        }
      }
      return inside;
    }

    // Initialize maps
    function initAircraftMap() {
      aircraftMap = L.map('aircraftMap').setView([23.8, 121.0], 8);
      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors, © CartoDB',
        maxZoom: 18
      }).addTo(aircraftMap);

      aircraftMap.on('click', function (e) {
        document.getElementById('aircraftCoordinates').innerHTML =
          `Latitude: ${e.latlng.lat.toFixed(6)}°, Longitude: ${e.latlng.lng.toFixed(6)}°`;
      });

      generateAirbaseMarkers();
    }

    function initJammersMap() {
      jammersMap = L.map('jammersMap').setView([23.8, 121.0], 8);
      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors, © CartoDB',
        maxZoom: 18
      }).addTo(jammersMap);

      jammersMap.on('click', function (e) {
        const lat = e.latlng.lat;
        const lng = e.latlng.lng;

        if (selectedEWUnit !== null) {
          deployEWUnit(lat, lng);
        } else {
          document.getElementById('jammersCoordinates').innerHTML =
            `Latitude: ${lat.toFixed(6)}°, Longitude: ${lng.toFixed(6)}°`;
        }
      });

      generateJammersAirbaseMarkers();
    }

    // Icons
    const abIcon = L.icon({
      iconUrl: 'https://i.meee.com.tw/5afNBSQ.png',
      iconSize: [20, 20],
      iconAnchor: [10, 10],
      popupAnchor: [0, -10]
    });

    const fallbackABIcon = L.divIcon({
      className: 'ab-marker',
      html: '<div style="background-color: #ff6b6b; width: 20px; height: 20px; border-radius: 3px; border: 2px solid white; display: flex; align-items: center; justify-content: center; font-weight: bold; color: white; font-size: 9px;">AB</div>',
      iconSize: [25, 15],
      iconAnchor: [12, 12]
    });

    const ewIcon = L.icon({
      iconUrl: 'https://i.meee.com.tw/XENYCji.png',
      iconSize: [40, 30],
      iconAnchor: [20, 15],
      popupAnchor: [0, -15]
    });

    const fallbackEWIcon = L.divIcon({
      className: 'ew-marker',
      html: '<div style="background-color: #00b894; width: 20px; height: 20px; border-radius: 50%%; border: 2px solid white; display: flex; align-items: center; justify-content: center; font-weight: bold; color: white; font-size: 9px;">CIC</div>',
      iconSize: [25, 15],
      iconAnchor: [12, 12]
    });

    // Budget management
    function updateBudgetDisplay() {
      const budgetValueEl = document.getElementById('budgetValue');
      const budgetDetailsEl = document.getElementById('budgetDetails');
      const budgetProgressBar = document.getElementById('budgetProgressBar');

      budgetValueEl.textContent = currentScore;
      budgetDetailsEl.textContent = `Used: ${usedScore} / Total: ${INITIAL_SCORE}`;

      const percentage = (currentScore / INITIAL_SCORE) * 100;
      budgetProgressBar.style.width = `${percentage}%%`;

      budgetValueEl.classList.remove('warning', 'danger');
      budgetProgressBar.classList.remove('warning', 'danger');

      if (currentScore < 200) {
        budgetValueEl.classList.add('danger');
        budgetProgressBar.classList.add('danger');
      } else if (currentScore < 400) {
        budgetValueEl.classList.add('warning');
        budgetProgressBar.classList.add('warning');
      }
    }

    function canAffordLoadout() {
      return currentScore >= LOADOUT_COST;
    }

    function addLoadout(baseIndex, loadoutIndex) {
      if (!canAffordLoadout()) {
        alert('Insufficient budget! Cannot add more loadouts.');
        return false;
      }
      basesData[baseIndex].loadouts[loadoutIndex].num += 1;
      currentScore -= LOADOUT_COST;
      usedScore += LOADOUT_COST;
      updateBudgetDisplay();
      return true;
    }

    function removeLoadout(baseIndex, loadoutIndex) {
      if (basesData[baseIndex].loadouts[loadoutIndex].num <= 0) return false;
      basesData[baseIndex].loadouts[loadoutIndex].num -= 1;
      currentScore += LOADOUT_COST;
      usedScore -= LOADOUT_COST;
      updateBudgetDisplay();
      return true;
    }

    // Base Editor
    window.showBaseEditor = function (baseIndex) {
      currentEditingBase = baseIndex;
      const base = basesData[baseIndex];
      const editor = document.getElementById('baseEditor');
      editor.classList.remove('empty');

      let editorHTML = `<div class="base-editor-header">${base.name}</div>`;

      if (base.embarkedUnits && base.embarkedUnits.length > 0) {
        editorHTML += `<div class="base-editor-section"><div class="section-title">Deployed Aircraft</div>`;
        base.embarkedUnits.forEach((unit, unitIndex) => {
          const totalAircraft = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
          editorHTML += `
            <div class="loadout-controls">
              <div class="loadout-info">
                <div class="loadout-name">${unit.platformName}</div>
                <div class="loadout-cost">${unit.name}</div>
              </div>
              <div class="loadout-actions">
                <button class="loadout-btn" id="aircraft-${baseIndex}-${unitIndex}-dec" onclick="handleAircraftDecrease(${baseIndex}, ${unitIndex})">−</button>
                <div class="loadout-quantity" id="aircraft-${baseIndex}-${unitIndex}-qty">${totalAircraft}</div>
                <button class="loadout-btn" id="aircraft-${baseIndex}-${unitIndex}-inc" onclick="handleAircraftIncrease(${baseIndex}, ${unitIndex})">+</button>
              </div>
            </div>`;
        });
        editorHTML += `</div>`;
      }

      if (base.loadouts && base.loadouts.length > 0) {
        editorHTML += `<div class="base-editor-section"><div class="section-title">Base Ammunition Storage</div>`;
        base.loadouts.forEach((loadout, loadoutIndex) => {
          const loadoutName = loadout.name || `Loadout ${loadout.loadoutId}`;
          editorHTML += `
            <div class="loadout-controls">
              <div class="loadout-info">
                <div class="loadout-name">${loadoutName}</div>
                <div class="loadout-cost">Cost: ${LOADOUT_COST}</div>
              </div>
              <div class="loadout-actions">
                <button class="loadout-btn" id="loadout-${baseIndex}-${loadoutIndex}-dec" onclick="handleLoadoutDecrease(${baseIndex}, ${loadoutIndex})">−</button>
                <div class="loadout-quantity" id="loadout-${baseIndex}-${loadoutIndex}-qty">${loadout.num}</div>
                <button class="loadout-btn" id="loadout-${baseIndex}-${loadoutIndex}-inc" onclick="handleLoadoutIncrease(${baseIndex}, ${loadoutIndex})">+</button>
              </div>
            </div>`;
        });
        editorHTML += `</div>`;
      }

      editor.innerHTML = editorHTML;

      if (base.embarkedUnits) {
        base.embarkedUnits.forEach((unit, unitIndex) => updateAircraftButtons(baseIndex, unitIndex));
      }
      updateLoadoutButtons(baseIndex);
    }

    function generateAirbaseMarkers() {
      basesData.forEach((base, baseIndex) => {
        const baseMarker = L.marker([base.latitude, base.longitude], {
          icon: fallbackABIcon
        }).addTo(aircraftMap);

        const img = new Image();
        img.onload = () => baseMarker.setIcon(abIcon);
        img.src = 'assets/Installation_friendly.png';

        // 點擊 marker 直接開啟編輯器
        baseMarker.on('click', function () {
          showBaseEditor(baseIndex);
        });

        function createPopupContent() {
          let popupContent = `
            <div class="base-popup" style="color: #e0e0e0;">
              <strong style="font-size: 14px; color: #00b894;">${base.name}</strong><br><br>
              <strong style="color: #ffffff;">Coordinates:</strong><br>
              <span style="color: #00b894;">Lat: ${base.latitude.toFixed(6)}°</span><br>
              <span style="color: #00b894;">Lng: ${base.longitude.toFixed(6)}°</span><br>`;

          if (base.embarkedUnits && base.embarkedUnits.length > 0) {
            popupContent += `<div class="popup-section" style="margin-top: 12px;">
              <div class="popup-section-title">Deployed Aircraft</div>`;
            base.embarkedUnits.forEach((unit) => {
              const totalAircraft = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
              popupContent += `
                <div class="popup-item">
                  <span class="popup-item-name">${unit.platformName} x ${totalAircraft}</span>
                </div>`;
            });
            popupContent += `</div>`;
          }

          if (base.loadouts && base.loadouts.length > 0) {
            popupContent += `<div class="popup-section" style="margin-top: 12px;">
              <div class="popup-section-title">Ammunition Storage</div>`;
            base.loadouts.forEach((loadout) => {
              const loadoutName = loadout.name || `Loadout ${loadout.loadoutId}`;
              popupContent += `
                <div class="popup-item">
                  <span class="popup-item-name">${loadoutName} x ${loadout.num}</span>
                </div>`;
            });
            popupContent += `</div>`;
          }

          popupContent += `</div>`;
          return popupContent;
        }

        baseMarker.bindPopup(createPopupContent(), {
          maxWidth: 320,
          className: 'custom-popup'
        });
      });
    }

    // Generate read-only airbase markers for GPS Jammers map
    function generateJammersAirbaseMarkers() {
      basesData.forEach((base) => {
        const baseMarker = L.marker([base.latitude, base.longitude], {
          icon: fallbackABIcon
        }).addTo(jammersMap);

        const img = new Image();
        img.onload = () => baseMarker.setIcon(abIcon);
        img.src = 'assets/Installation_friendly.png';

        let popupContent = `
          <div class="base-popup" style="color: #e0e0e0;">
            <strong style="font-size: 14px; color: #00b894;">${base.name}</strong><br><br>
            <strong style="color: #ffffff;">Coordinates:</strong><br>
            <span style="color: #00b894;">Lat: ${base.latitude.toFixed(6)}°</span><br>
            <span style="color: #00b894;">Lng: ${base.longitude.toFixed(6)}°</span><br>`;

        if (base.embarkedUnits && base.embarkedUnits.length > 0) {
          popupContent += `<div class="popup-section" style="margin-top: 12px;">
            <div class="popup-section-title">Deployed Aircraft</div>`;
          base.embarkedUnits.forEach((unit) => {
            const totalAircraft = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
            popupContent += `
              <div class="popup-item">
                <span class="popup-item-name">${unit.platformName} x ${totalAircraft}</span>
              </div>`;
          });
          popupContent += `</div>`;
        }

        if (base.loadouts && base.loadouts.length > 0) {
          popupContent += `<div class="popup-section" style="margin-top: 12px;">
            <div class="popup-section-title">Ammunition Storage</div>`;
          base.loadouts.forEach((loadout) => {
            const loadoutName = loadout.name || `Loadout ${loadout.loadoutId}`;
            popupContent += `
              <div class="popup-item">
                <span class="popup-item-name">${loadoutName} x ${loadout.num}</span>
              </div>`;
          });
          popupContent += `</div>`;
        }

        popupContent += `</div>`;

        baseMarker.bindPopup(popupContent, {
          maxWidth: 320,
          className: 'custom-popup'
        });
      });
    }

    // Loadout handlers
    window.handleAircraftIncrease = function (baseIndex, unitIndex) {
      if (!canAffordLoadout()) {
        alert('Insufficient budget! Cannot add more aircraft.');
        return;
      }
      const unit = basesData[baseIndex].embarkedUnits[unitIndex];
      if (unit.loadouts && unit.loadouts.length > 0) {
        unit.loadouts[0].num += 1;
      }
      currentScore -= LOADOUT_COST;
      usedScore += LOADOUT_COST;
      updateBudgetDisplay();

      const qtyElement = document.getElementById(`aircraft-${baseIndex}-${unitIndex}-qty`);
      if (qtyElement) {
        qtyElement.textContent = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
      }
      updateAircraftButtons(baseIndex, unitIndex);
    }

    window.handleAircraftDecrease = function (baseIndex, unitIndex) {
      const unit = basesData[baseIndex].embarkedUnits[unitIndex];
      if (!unit.loadouts || unit.loadouts.length === 0 || unit.loadouts[0].num <= 0) return;

      unit.loadouts[0].num -= 1;
      currentScore += LOADOUT_COST;
      usedScore -= LOADOUT_COST;
      updateBudgetDisplay();

      const qtyElement = document.getElementById(`aircraft-${baseIndex}-${unitIndex}-qty`);
      if (qtyElement) {
        qtyElement.textContent = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
      }
      updateAircraftButtons(baseIndex, unitIndex);
    }

    function updateAircraftButtons(baseIndex, unitIndex) {
      const unit = basesData[baseIndex].embarkedUnits[unitIndex];
      const incButton = document.getElementById(`aircraft-${baseIndex}-${unitIndex}-inc`);
      const decButton = document.getElementById(`aircraft-${baseIndex}-${unitIndex}-dec`);

      if (incButton) incButton.disabled = !canAffordLoadout();
      if (decButton) {
        const totalAircraft = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
        decButton.disabled = totalAircraft <= 0;
      }
    }

    window.handleLoadoutIncrease = function (baseIndex, loadoutIndex) {
      if (addLoadout(baseIndex, loadoutIndex)) {
        const qtyElement = document.getElementById(`loadout-${baseIndex}-${loadoutIndex}-qty`);
        if (qtyElement) {
          qtyElement.textContent = basesData[baseIndex].loadouts[loadoutIndex].num;
        }
        updateLoadoutButtons(baseIndex);
      }
    }

    window.handleLoadoutDecrease = function (baseIndex, loadoutIndex) {
      if (removeLoadout(baseIndex, loadoutIndex)) {
        const qtyElement = document.getElementById(`loadout-${baseIndex}-${loadoutIndex}-qty`);
        if (qtyElement) {
          qtyElement.textContent = basesData[baseIndex].loadouts[loadoutIndex].num;
        }
        updateLoadoutButtons(baseIndex);
      }
    }

    function updateLoadoutButtons(baseIndex) {
      const base = basesData[baseIndex];
      if (!base.loadouts) return;

      base.loadouts.forEach((loadout, loadoutIndex) => {
        const incButton = document.getElementById(`loadout-${baseIndex}-${loadoutIndex}-inc`);
        const decButton = document.getElementById(`loadout-${baseIndex}-${loadoutIndex}-dec`);
        if (incButton) incButton.disabled = !canAffordLoadout();
        if (decButton) decButton.disabled = loadout.num <= 0;
      });
    }

    // EW Units
    function generateEWUnitButtons() {
      const unitsList = document.getElementById('ewUnitsList');
      ewUnitsData.forEach((unit, index) => {
        const button = document.createElement('div');
        button.className = 'ew-unit-btn';
        button.dataset.unitIndex = index;
        button.innerHTML = `
          <div class="unit-name">${unit.name}</div>
          <div class="unit-zone">${unit.zoneName}</div>`;
        button.addEventListener('click', () => selectEWUnit(index));
        unitsList.appendChild(button);
      });
    }

    function selectEWUnit(index) {
      if (deployedUnits.has(index)) {
        undeployEWUnit(index);
        return;
      }
      document.querySelectorAll('.ew-unit-btn').forEach(btn => btn.classList.remove('selected'));
      selectedEWUnit = index;
      document.querySelector(`[data-unit-index="${index}"]`).classList.add('selected');
      updateDeploymentStatus(`Selected: ${ewUnitsData[index].name}<br>Click map to deploy`);
    }

    function undeployEWUnit(index) {
      if (!deployedUnits.has(index)) return;

      const unit = ewUnitsData[index];
      const deployment = deployedUnits.get(index);

      jammersMap.removeLayer(deployment.marker);
      jammersMap.removeLayer(deployment.circle);
      deployedUnits.delete(index);

      const markerIndex = ewMarkers.indexOf(deployment.marker);
      if (markerIndex > -1) ewMarkers.splice(markerIndex, 1);

      if (index === 0) {
        unit.point.lat = 24.906367;
        unit.point.lon = 121.284363;
      } else if (index === 1) {
        unit.point.lat = 24.492148;
        unit.point.lon = 120.955020;
      }

      document.querySelector(`[data-unit-index="${index}"]`).classList.remove('deployed');
      updateDeploymentStatus(`${unit.name} deployment cancelled`);
    }

    function updateDeploymentStatus(message) {
      document.getElementById('deploymentStatus').innerHTML = message;
    }

    function deployEWUnit(lat, lng) {
      if (selectedEWUnit === null) {
        updateDeploymentStatus('Please select an EW unit first');
        return;
      }

      if (!isPointInTaiwan(lat, lng)) {
        updateDeploymentStatus('⚠️ EW units can only be deployed on Taiwan mainland');
        return;
      }

      const unit = ewUnitsData[selectedEWUnit];
      unit.point.lat = parseFloat(lat.toFixed(6));
      unit.point.lon = parseFloat(lng.toFixed(6));

      const ewMarker = L.marker([lat, lng], { icon: fallbackEWIcon }).addTo(jammersMap);
      const img = new Image();
      img.onload = () => ewMarker.setIcon(ewIcon);
      img.src = 'assets/CIC.png';

      const radiusInMeters = unit.radius * 1852;
      const jammingCircle = L.circle([lat, lng], {
        radius: radiusInMeters,
        color: '#ff6b6b',
        fillColor: '#ff6b6b',
        fillOpacity: 0.1,
        weight: 2,
        opacity: 0.7
      }).addTo(jammersMap);

      ewMarker.bindPopup(`
        <div style="color: #e0e0e0;">
          <strong style="color: #00b894;">${unit.name}</strong><br>
          <em style="color: #a0a0a0;">${unit.zoneName}</em><br><br>
          <span style="color: #00b894;">Lat: ${lat.toFixed(6)}°</span><br>
          <span style="color: #00b894;">Lng: ${lng.toFixed(6)}°</span><br><br>
          <strong style="color: #ff6b6b;">Jamming Radius: ${unit.radius} NM</strong><br>
          <span style="color: #a0a0a0;">Random Radius: ${unit.randomRadius}km</span>
        </div>
      `).openPopup();

      deployedUnits.set(selectedEWUnit, { marker: ewMarker, circle: jammingCircle });
      ewMarkers.push(ewMarker);

      const button = document.querySelector(`[data-unit-index="${selectedEWUnit}"]`);
      button.classList.remove('selected');
      button.classList.add('deployed');

      updateDeploymentStatus(`${unit.name} deployed at<br>Lat: ${lat.toFixed(6)}°, Lng: ${lng.toFixed(6)}°<br><span style="color: #ff6b6b;">Jamming Range: ${unit.radius} NM</span>`);
      selectedEWUnit = null;
    }

    // Summary
    function updateSummary() {
      const summaryContent = document.getElementById('summaryContent');

      let totalAircraft = 0;
      let totalLoadouts = 0;
      const baseStats = [];

      basesData.forEach(base => {
        let baseAircraft = 0;
        let baseLoadouts = 0;
        const aircraftDetails = [];
        const loadoutDetails = [];

        if (base.embarkedUnits) {
          base.embarkedUnits.forEach(unit => {
            if (unit.loadouts) {
              const aircraftCount = unit.loadouts.reduce((sum, lo) => sum + lo.num, 0);
              if (aircraftCount > 0) {
                aircraftDetails.push({ name: unit.platformName, count: aircraftCount });
                baseAircraft += aircraftCount;
                totalAircraft += aircraftCount;
              }
            }
          });
        }

        if (base.loadouts) {
          base.loadouts.forEach(loadout => {
            if (loadout.num > 0) {
              loadoutDetails.push({ name: loadout.name || `Loadout ${loadout.loadoutId}`, count: loadout.num });
              baseLoadouts += loadout.num;
              totalLoadouts += loadout.num;
            }
          });
        }

        if (baseAircraft > 0 || baseLoadouts > 0) {
          baseStats.push({
            name: base.name,
            aircraft: baseAircraft,
            loadouts: baseLoadouts,
            aircraftDetails: aircraftDetails,
            loadoutDetails: loadoutDetails
          });
        }
      });

      let summaryHTML = `
        <div class="summary-section">
          <div class="summary-title">Budget Overview</div>
          <div class="summary-item">
            <span class="summary-label">Total Budget</span>
            <span class="summary-value">${INITIAL_SCORE}</span>
          </div>
          <div class="summary-item">
            <span class="summary-label">Used Budget</span>
            <span class="summary-value">${usedScore}</span>
          </div>
          <div class="summary-item">
            <span class="summary-label">Remaining Budget</span>
            <span class="summary-value">${currentScore}</span>
          </div>
          <div class="summary-item">
            <span class="summary-label">Usage Percentage</span>
            <span class="summary-value">${((usedScore / INITIAL_SCORE) * 100).toFixed(1)}%%</span>
          </div>
        </div>

        <div class="summary-section">
          <div class="summary-title">Aircraft & Loadouts Summary</div>
          <div class="summary-item">
            <span class="summary-label">Total Aircraft Deployed</span>
            <span class="summary-value">${totalAircraft}</span>
          </div>
          <div class="summary-item">
            <span class="summary-label">Total Ammunition Stored</span>
            <span class="summary-value">${totalLoadouts}</span>
          </div>
        </div>`;

      if (baseStats.length > 0) {
        summaryHTML += `
          <div class="summary-section">
            <div class="summary-title">Base Breakdown</div>
            <div class="base-breakdown">`;
        baseStats.forEach(stat => {
          summaryHTML += `
            <div class="base-card">
              <div class="base-card-title">${stat.name}</div>`;

          if (stat.aircraftDetails.length > 0) {
            summaryHTML += `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #3d3d3d;">
              <div style="font-size: 11px; color: #a0a0a0; text-transform: uppercase; margin-bottom: 6px;">Aircraft</div>`;
            stat.aircraftDetails.forEach(detail => {
              summaryHTML += `
              <div class="base-card-item">
                <span class="summary-label">${detail.name} x ${detail.count}</span>
              </div>`;
            });
            summaryHTML += `</div>`;
          }

          if (stat.loadoutDetails.length > 0) {
            summaryHTML += `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #3d3d3d;">
              <div style="font-size: 11px; color: #a0a0a0; text-transform: uppercase; margin-bottom: 6px;">Ammunition</div>`;
            stat.loadoutDetails.forEach(detail => {
              summaryHTML += `
              <div class="base-card-item">
                <span class="summary-label">${detail.name} x ${detail.count}</span>
              </div>`;
            });
            summaryHTML += `</div>`;
          }

          summaryHTML += `</div>`;
        });
        summaryHTML += `</div></div>`;
      }

      const deployedJammers = Array.from(deployedUnits.keys());
      summaryHTML += `
        <div class="summary-section">
          <div class="summary-title">GPS Jammers</div>
          <div class="summary-item">
            <span class="summary-label">Deployed Units</span>
            <span class="summary-value">${deployedJammers.length} / ${ewUnitsData.length}</span>
          </div>`;

      if (deployedJammers.length > 0) {
        deployedJammers.forEach(index => {
          const unit = ewUnitsData[index];
          summaryHTML += `
            <div style="margin-top: 12px; padding: 12px; background-color: rgba(0,0,0,0.3); border-radius: 4px; border: 1px solid #3d3d3d;">
              <div style="color: #ffffff; font-weight: 600; margin-bottom: 6px; font-size: 13px;">${unit.name}</div>
              <div style="color: #a0a0a0; font-size: 12px;">Location: ${unit.point.lat}, ${unit.point.lon}</div>
              <div style="color: #ff6b6b; font-size: 12px;">Range: ${unit.radius} NM</div>
            </div>`;
        });
      }
      summaryHTML += `</div>`;

      summaryHTML += `<button class="export-btn" onclick="exportConfiguration()">Submit</button>`;
      summaryContent.innerHTML = summaryHTML;
    }

    function exportConfiguration() {
      const config = {
        budget: { initial: INITIAL_SCORE, used: usedScore, remaining: currentScore },
        bases: basesData,
        ewUnits: ewUnitsData,
        deployedJammers: Array.from(deployedUnits.keys())
      };

      const jsonString = JSON.stringify(config, null, 2);
      const input = document.getElementById('summaryData')
      input.value = jsonString

      // navigator.clipboard.writeText(jsonString).then(() => {
      //   alert('Configuration copied to clipboard!');
      // }).catch(err => {
      //   const blob = new Blob([jsonString], { type: 'application/json' });
      //   const url = URL.createObjectURL(blob);
      //   const a = document.createElement('a');
      //   a.href = url;
      //   a.download = 'taiwan-deployment-config.json';
      //   a.click();
      //   URL.revokeObjectURL(url);
      // });
    }

    // Initialize
    window.addEventListener('DOMContentLoaded', () => {
      initAircraftMap();
      initJammersMap();
      generateEWUnitButtons();
      updateDeploymentStatus('Select an EW unit then click on the map to deploy');
    });
  </script>
</body>

</html>
  ]]
end

---Create JSON string for GPS jamming unit data
---Extracts GPS jamming unit information from saved game state
---Processes jammer configurations including position and operational parameters
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

---Create JSON string for deployed aircraft data
---Extracts deployed aircraft information from configuration
---Enriches aircraft data with base geographical coordinates
---Filters out aircraft from bases that no longer exist
---@param config SBJ__CONFIG Configuration table containing aircraft deployment data
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

---Create comprehensive status UI with tabbed interface
---Main entry point for displaying multi-tab military status dashboard
---Aggregates data from multiple sources and creates unified HTML interface
---Supports both China and Taiwan/US sides with appropriate data filtering
---Features:
--- - Signal intelligence data (SIGINT transmissions)
--- - Mobile missile launcher status with reload progress
--- - Command and control node status (IADS)
--- - Base weapon inventory
--- - Landing unit counts (China only)
---@param config SBJ__CONFIG Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
function UnitStatusUI.createUI(config, sideName)
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error('saveData is nil')
    return
  end

  if sideName == 'China' then
    local signalDataString = createSignalDataString(saveData, sideName)
    local batteryDataString = createBatteryDataString(config, saveData, sideName, 'srbm', 'mlrs', 'glcm', 'ascm', 'mrbm')
    local magazineDataString = createMagazineDataString(config, sideName)
    local c2NodeDataString = createC2NodeDataString(saveData, sideName, 'C2')
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
    local form = GameApi.UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
  else
    local signalDataString = createSignalDataString(saveData, 'US')
    local batteryDataString = createBatteryDataString(config, saveData, sideName, 'srbm', 'mlrs', 'glcm', 'ascm')
    local magazineDataString = createMagazineDataString(config, sideName)
    local c2NodeDataString = createC2NodeDataString(saveData, sideName, 'ROCC', 'TAAOC')

    local HTMLTemplate = getHTMLTemplate()
    local msg = string.format(
      HTMLTemplate,
      batteryDataString,
      signalDataString,
      c2NodeDataString,
      magazineDataString,
      '{}'
    )
    local form = GameApi.UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
  end
end

---Create interactive setup menu for scenario initialization
---Displays comprehensive web-based planning interface for Taiwan deployment
---Features:
--- - Aircraft & Loadouts tab: Configure air force deployment and ammunition storage
--- - GPS Jammers tab: Position electronic warfare units with interactive map
--- - Summary tab: Review and submit complete deployment configuration
---Processes user input and applies changes to game state and unit deployment
---Currently only available for Taiwan side
---@param config SBJ__CONFIG Configuration table
---@param sideName string Side name (currently only 'Taiwan' is supported)
function UnitStatusUI.createSetupMenu(config, sideName)
  ---@type SBJ__SaveData
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error('saveData is nil')
    return
  end

  if sideName == 'Taiwan' then
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
    local form = GameApi.UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })

    -- Process submitted configuration
    if form['pressed'] and form['pressed'] == 'Done' then
      if form['summaryData'] then
        -- Parse JSON configuration from form
        local jsonStr = form['summaryData']:gsub("^'", ""):gsub("'$", "")
        ---@type table
        local result = gKH.json.parse(jsonStr)
        local jammerDescriptors = result.ewUnits
        local abDeploymentDescriptors = result.bases

        -- Apply GPS jamming unit deployments
        if jammerDescriptors then
          for _, descriptor in ipairs(jammerDescriptors) do
            GPSJamming.addGPSJammer(config, descriptor, sideName)
          end
        end

        -- Apply aircraft and loadout configurations
        if abDeploymentDescriptors then
          UnitGenerator.addAircraft(abDeploymentDescriptors)
          UnitGenerator.initAircraftContexts(config, saveData.t.air.landBased)
        end
      end
    end
  end

  gKH.State.SaveTableToKey(saveData, "SaveData")
end

return UnitStatusUI
