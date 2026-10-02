local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Utils = require("src.utils.utils")
local GnssJamming = require("src.modules.ew.gnssJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local MissileSystem = require("src.modules.missileSystem.init")
local LandingOps = require("src.modules.landingOps.init")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local gKH = require("src.core.gKH_State_Standalone")
local PersistentState = require("src.core.persistentState")
local constants = require("src.core.constants")

local UnitStatusUI = {}

---Generate HTML template for WCS settings UI
---@return string # HTML string representing the WCS settings page
local function getWCSSettingTemplate()
  return [[]]
end

---Display HTML dialog for EMCON settings configuration
function UnitStatusUI.buildWcsSettingTable()
  local filteredUnits = GameApi.VP_GetSide({ side = constants.SIDES.BLUE }):unitsBy(constants.UNIT_TYPES.FACILITY)

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
      IntegratedAirDefenseSystem.setSamDoctrine(result.doctrine, filteredUnits)
    end
  end
end

---Create JSON string for base ammunition inventory data
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted ammunition inventory data
local function createMagazineDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local descriptors = config[field].air.deployedACs

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
---@param types SBJ__C2TypeKey[] C2 node types to include
---@return string # JSON formatted C2 status data
local function createC2NodeDataString(saveData, sideName, types)
  local iads = PersistentState.iads(saveData, sideName)
  local rows = {}

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
---@param sideName string Side name (constants.SIDES.RED or constants.SIDES.ALLY)
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

---Get HTML template for the add-units menu
---@return string # Add-units menu template
local function getAddUnitsMenuTemplate()
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

---Create JSON string for deployed aircraft data with base coordinates
---@param config SBJ__Config Configuration table containing aircraft deployment data
---@param sideName string Side name ('China' or 'Taiwan')
---@return string # JSON formatted deployed aircraft data with coordinates
local function createDeployedAircraftDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local rows = {}
  local descriptors = config[field].air.deployedACs

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

  for _, op in ipairs(config.red.amphibOps.operations) do
    local item = { name = op.name, waypoints = {} }

    local point = GameApi.ScenEdit_GetReferencePoint({
      side = constants.SIDES.RED,
      name = op.from.areas[1].startingPoints.type075[1],
    })

    if point then
      table.insert(item.waypoints, { latitude = point.latitude, longitude = point.longitude })
    end

    for _, opZone in ipairs(config.red.amphibOps.operationalZones) do
      if op.name == opZone.name then
        local destination = GameApi.ScenEdit_GetReferencePoint({
          side = constants.SIDES.RED,
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

---Per-side content of the status dashboard
local STATUS_UI_SIDES = {
  [constants.SIDES.RED] = {
    signalSide = constants.SIDES.RED,
    c2Types = { "c2" },
    showsLandedUnits = true
  },
  [constants.SIDES.BLUE] = {
    signalSide = constants.SIDES.ALLY,
    c2Types = { "rocc", "taaoc" },
    showsLandedUnits = false
  }
}
---@cast STATUS_UI_SIDES table<string, {signalSide: string, c2Types: SBJ__C2TypeKey[], showsLandedUnits: boolean}>


---Create comprehensive status UI with multi-tab military dashboard
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
function UnitStatusUI.createUI(config, sideName)
  local view = STATUS_UI_SIDES[sideName] or STATUS_UI_SIDES[constants.SIDES.BLUE]

  PersistentState.read(function(saveData)
    local batteryRows = MissileSystem.buildBatteryStatusRows(config, saveData, sideName)
    local landingUnitsString = view.showsLandedUnits
        and gKH.json.stringify(LandingOps.countUnitsInEachArea(config))
        or "{}"

    local msg = string.format(
      getHTMLTemplate(),
      createSignalDataString(saveData, view.signalSide),
      gKH.json.stringify(batteryRows),
      createC2NodeDataString(saveData, sideName, view.c2Types),
      createMagazineDataString(config, sideName),
      landingUnitsString
    )
    GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
  end)
end

---Apply the setup menu's submitted deployments: GNSS jammers, then aircraft, then missile batteries
---@param config SBJ__Config Configuration table; the side's ground config is mutated by battery redeploys
---@param saveData SBJ__SaveData Persistent save data; mutated
---@param sideName string Side name ('China' or 'Taiwan')
---@param result SBJ__SetupResult Parsed setup menu submission
local function updateFromSetupResult(config, saveData, sideName, result)
  local jammerDescriptors = result.jammers
  local airbaseDeploymentDescriptors = result.airbases
  local missileSystems = result.missileSystems

  if jammerDescriptors and #jammerDescriptors > 0 then
    GnssJamming.removeJammers(sideName, jammerDescriptors)
    for _, descriptor in ipairs(jammerDescriptors) do
      GnssJamming.addGnssJammer(sideName, descriptor)
    end
  end

  if airbaseDeploymentDescriptors and #airbaseDeploymentDescriptors > 0 then
    UnitGenerator.addAircraft(airbaseDeploymentDescriptors)

    if sideName == constants.SIDES.BLUE then
      CommsJamming.updateTargetAircraft(config, saveData)
    end
  end

  if missileSystems and #missileSystems > 0 then
    MissileSystem.redeployFromSetup(config, saveData, sideName, missileSystems)
  end
end

---Create interactive setup menu for Taiwan deployment planning
---@param config SBJ__Config Configuration table
---@param sideName string Side name (currently only 'Taiwan' is supported)
function UnitStatusUI.createSetupMenu(config, sideName)
  PersistentState.update(function(saveData)
    -- Prepare data for HTML template
    local gpsJammerDataString = createGnssJammerDataString(config, sideName)
    local deployedAircraftDataString = createDeployedAircraftDataString(config, sideName)
    local missileSystemDataString = gKH.json.stringify(MissileSystem.buildSetupMenuRows(config, sideName))
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
      updateFromSetupResult(config, saveData, sideName, result)
    end
  end)
end

---Same units as each side's `addXXX` special action scripts, in the order they run
---@type table<string, SBJ__AddUnitAction[]>
local ADD_UNIT_ACTIONS = {
  [constants.SIDES.RED] = {
    { id = "addACs", label = "Add aircraft", run = function(config)
      UnitGenerator.addAircraft(config.red.air.deployedACs)
    end },
    { id = "addC2Facilities", label = "Add C2 facilities", run = function(config)
      PersistentState.update(function(saveData)
        IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)
      end)
    end },
    { id = "addCSG", label = "Add CSG", run = function(config)
      UnitGenerator.createCSG(config.red.surface.lacm.csg)
    end },
    { id = "addGnssJammers", label = "Add GNSS jammers", run = function(config)
      GnssJamming.deploySide(config, constants.SIDES.RED)
    end },
    { id = "addLandingShips", label = "Add landing ships", run = function(config)
      UnitGenerator.removeLandingShips()
      UnitGenerator.addLandingShips(config.red.amphibOps)
    end },
    { id = "addSAGs", label = "Add SAGs", run = function(config)
      UnitGenerator.createSAGs(constants.SIDES.RED, config.red.amphibOps.sags)
    end },
    { id = "addSubmarines", label = "Add submarines", run = function(config)
      UnitGenerator.addSubmarines(config, constants.SIDES.RED)
    end },
    { id = "addMissileSystems", label = "Add missile systems", run = function(config)
      PersistentState.update(function(saveData)
        MissileSystem.deploySide(config, saveData, constants.SIDES.RED)
      end)
    end },
  },
  [constants.SIDES.BLUE] = {
    { id = "addACs", label = "Add aircraft", run = function(config)
      PersistentState.update(function(saveData)
        UnitGenerator.addAircraft(config.blue.air.deployedACs)
        CommsJamming.updateTargetAircraft(config, saveData)
      end)
    end },
    { id = "addDeployedShipsAtPort", label = "Add deployed ships at port", run = function(config)
      UnitGenerator.addDeployedShipsAtPort(constants.SIDES.BLUE, config.blue.surface.deployedShips)
    end },
    { id = "addSAGs", label = "Add SAGs", run = function(config)
      UnitGenerator.createSAGs(constants.SIDES.BLUE, config.blue.surface.sags)
    end },
    { id = "addMissileSystems", label = "Add missile systems", run = function(config)
      PersistentState.update(function(saveData)
        MissileSystem.deploySide(config, saveData, constants.SIDES.BLUE)
      end)
    end },
  },
}

---Run the ticked add-units actions in menu order
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
---@param actionIds string[] Ids submitted by the page
local function runAddUnitActions(config, sideName, actionIds)
  local chosen = {}
  for _, id in ipairs(actionIds) do
    chosen[id] = true
  end

  for _, action in ipairs(ADD_UNIT_ACTIONS[sideName] or {}) do
    if chosen[action.id] then
      action.run(config)
    end
  end
end

---Show the add-units menu and run what the player ticked
---@param config SBJ__Config Configuration table
---@param sideName string Side name ('China' or 'Taiwan')
function UnitStatusUI.createAddUnitsMenu(config, sideName)
  local rows = {}
  for _, action in ipairs(ADD_UNIT_ACTIONS[sideName] or {}) do
    table.insert(rows, { id = action.id, label = action.label })
  end

  local msg = string.format(getAddUnitsMenuTemplate(), gKH.json.stringify(rows), sideName)
  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })

  if not (form["pressed"] == "Done" and form["selectedActions"]) then
    return
  end

  local jsonStr = form["selectedActions"]:gsub("^'", ""):gsub("'$", "")
  local result = gKH.json.parse(jsonStr)
  ---@cast result SBJ__AddUnitsMenuResult

  if result and result.actionIds then
    runAddUnitActions(config, sideName, result.actionIds)
  end
end

return UnitStatusUI
