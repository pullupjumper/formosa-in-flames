local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local gKH = require('src.core.gKH_State_Standalone')

---@class UnitStatusUI
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
---@return table<string, table<string, number>> Returns table with area names as keys and unit type counts as values
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

---Display HTML dialog for weapon control status settings table, allows EMCON status configuration
---Creates an interactive checkbox interface for configuring EMCON settings
---Supports Pac-2/3, Sky Bow-3, and TC-2 weapon systems
---Updates weapon control status and emission settings based on user selection
---@param config SBJ__CONFIG Configuration table
function UnitStatusUI.wcsSettingTable(config)
  local units = GameApi.VP_GetSide({ side = 'Taiwan' }):unitsBy(config.unitType.FACILITY)

  local HTMLTemplate = [[
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
---@param side string Side name ('China' or 'Taiwan')
---@param ... string Weapon system type list
---@return string JSON formatted artillery battery status data
local function createBatteryDataString(config, saveData, side, ...)
  local key = 't'
  local wpnSystems = { ... }

  if side == 'China' then
    key = 'c'
  end

  local rows = {}

  for index, wpnSystem in pairs(wpnSystems) do
    if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].ammunitionSections then
      for k, value in pairs(saveData[key].ground[wpnSystem].ammunitionSections) do
        rows[k] = {}
      end
    end
  end

  for index, wpnSystem in pairs(wpnSystems) do
    if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].batteries then
      for _, bty in pairs(saveData[key].ground[wpnSystem].batteries) do
        local name = bty.name
        local status = ''
        local missilesInAmmoVehicles = saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection]
            .wpnCurrent
        local ammoSec = saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection]
        local reloadTime = config[key].ground[wpnSystem].reloadTime / 60
        local missilesInAHA = saveData[key].ground[wpnSystem].ammunitions
            [saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection].ammunition].wpnCurrent
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

        if side == 'China' then
          table.insert(rows[bty.ammunitionSection], {
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
          table.insert(rows[bty.ammunitionSection], {
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
---@param side string Side name ('China' or 'Taiwan')
---@return string JSON formatted ammunition inventory data
local function createMagazineDataString(config, side)
  local key = 't'

  if side == 'China' then
    key = 'c'
  end

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
---@param side string Side name ('China' or 'Taiwan')
---@param ... string System type list
---@return string JSON formatted C2 status data
local function createC2NodeDataString(saveData, side, ...)
  local key = 't'

  if side == 'China' then
    key = 'c'
  end

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
---@param side string Side name ('China' or 'Taiwan')
---@return string JSON formatted signal data
local function createSignalDataString(saveData, side)
  local key = 'u'

  if side == 'China' then
    key = 'c'
  end

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
---@return string Complete HTML template with placeholders for data injection
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
                  <th class="text-right">Temp</th>
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
          <td class="text-right">${signal.confidence || 0}%%</td>
          <td class="text-right">${signal.temp || 0}</td>
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
---@param side string Side name ('China' or 'Taiwan')
function UnitStatusUI.createUI(config, side)
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    Logger.error('saveData is nil')
    return
  end

  if side == 'China' then
    local signalDataString = createSignalDataString(saveData, side)
    local batteryDataString = createBatteryDataString(config, saveData, side, 'srbm', 'mlrs', 'glcm', 'ascm', 'mrbm')
    local magazineDataString = createMagazineDataString(config, side)
    local c2NodeDataString = createC2NodeDataString(saveData, side, 'C2')
    local landingUnitsString = UnitStatusUI.countUnitsInEachArea(config)
    landingUnitsString = gKH.json.stringify(landingUnitsString)


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
    local signalDataString = createSignalDataString(saveData, side)
    local batteryDataString = createBatteryDataString(config, saveData, side, 'srbm', 'mlrs', 'glcm', 'ascm')
    local magazineDataString = createMagazineDataString(config, side)
    local c2NodeDataString = createC2NodeDataString(saveData, side, 'ROCC', 'TAAOC')

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

---@return UnitStatusUI
return UnitStatusUI
