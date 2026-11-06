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

---Create JSON string for C2 system status data
---@param saveData SBJ__SaveData
---@param sideName string
---@param types SBJ__C2TypeKey[]
---@return string # JSON formatted C2 status data, flat `guid -> node` with each node's `type`
local function createC2NodeDataString(saveData, sideName, types)
  local iads = PersistentState.iads(saveData, sideName)
  ---@type SBJ__C2NodeSet
  local rows = {}

  for _, type in pairs(types) do
    local c2States = iads[type]

    if c2States then
      for _, c2State in pairs(c2States) do
        rows[c2State.guid] = { type = type, name = c2State.name, areas = {} }
        local c2 = GameApi.ScenEdit_GetUnit(c2State.guid, sideName)

        if c2 then
          rows[c2State.guid].pos = { latitude = c2.latitude, longitude = c2.longitude }
        end

        for _, rps in ipairs(c2State.areas or {}) do
          local points = GameApi.ScenEdit_GetReferencePoints({ side = sideName, area = rps })

          if points then
            local area = {}

            for _, point in ipairs(points) do
              table.insert(area, { latitude = tonumber(point.latitude), longitude = tonumber(point.longitude) })
            end

            table.insert(rows[c2State.guid].areas, area)
          end
        end

        if c2State.sam then
          rows[c2State.guid].sam = {}

          for _, SAMState in pairs(c2State.sam) do
            local unit = GameApi.ScenEdit_GetUnit(SAMState.guid)

            -- A destroyed unit no longer exists in the game, so it is skipped instead of drawn
            if not unit then
              goto continue
            end

            local doctrine = GameApi.ScenEdit_GetDoctrine(SAMState.guid)
            rows[c2State.guid].sam[SAMState.guid] = {
              type = type,
              name = SAMState.name,
              OODADetection = tostring(SAMState.currOODA.detection) .. "/" .. tostring(SAMState.OODA.detection),
              OODATargeting = tostring(SAMState.currOODA.targeting) .. "/" .. tostring(SAMState.OODA.targeting),
              isOutOfComms = SAMState.isOutOfComms,
              EMCONSetting = SAMState.EMCONSetting,
              isDestroyed = false,
              weaponFree = doctrine.weapon_control_status_air ~= constants.WCS.HOLD,
              pos = { latitude = unit.latitude, longitude = unit.longitude }
            }

            ::continue::
          end
        end

        if c2State.radar then
          rows[c2State.guid].radar = {}

          for _, radarState in pairs(c2State.radar) do
            local unit = GameApi.ScenEdit_GetUnit(radarState.guid)

            -- A destroyed unit no longer exists in the game, so it is skipped instead of drawn
            if not unit then
              goto continue
            end

            rows[c2State.guid].radar[radarState.guid] = {
              type = type,
              name = radarState.name,
              OODADetection = tostring(radarState.currOODA.detection) .. "/" .. tostring(radarState.OODA.detection),
              OODATargeting = tostring(radarState.currOODA.targeting) .. "/" .. tostring(radarState.OODA.targeting),
              isOutOfComms = radarState.isOutOfComms,
              EMCONSetting = radarState.EMCONSetting,
              isDestroyed = false,
              pos = { latitude = unit.latitude, longitude = unit.longitude }
            }

            ::continue::
          end
        end
      end
    end
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for SIGINT transmission data
---@param saveData SBJ__SaveData
---@param sideName string Side name (constants.SIDES.RED or constants.SIDES.ALLY)
---@return string # JSON formatted signal data
local function createSignalDataString(saveData, sideName)
  ---@type SBJ__Signal[]
  local rows = {}
  local transmissions = PersistentState.sigint(saveData, sideName).transmissions

  for _, transmission in pairs(transmissions) do
    table.insert(rows, {
      name = transmission.name,
      type = transmission.type,
      autodetectable = transmission.autodetectable,
      latitude = transmission.latitude,
      longitude = transmission.longitude,
      firstDetected = transmission.firstDetected,
      lastDetected = transmission.lastDetected,
      detectionCount = transmission.detectionCount,
      confidence = transmission.confidence,
      currentDetectionLevel = transmission.currentDetectionLevel
    })
  end

  return gKH.json.stringify(rows)
end

---Get HTML template for the control panel (deployment, signals, C2 and add-units in one page)
---@return string # Control panel template
local function getControlPanelTemplate()
  return [[]]
end

---Create JSON string for GPS jamming unit data
---@param config SBJ__Config
---@param sideName string
---@return string # JSON formatted GPS jamming unit data
local function createGnssJammerDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  local descriptors = config[field].gnssJamming.jammers
  ---@type SBJ__GNSSJammerDescriptor[]
  local rows = {}

  for _, descriptor in pairs(descriptors) do
    local row = Utils.deepCopy(descriptor)
    table.insert(rows, row)
  end

  return gKH.json.stringify(rows)
end

---Create JSON string for deployed aircraft data with base coordinates
---@param config SBJ__Config
---@param sideName string
---@return string # JSON formatted deployed aircraft data with coordinates
local function createDeployedAircraftDataString(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local field = sideConfig.field
  ---@type SBJ__Airbase[]
  local rows = {}
  local descriptors = config[field].air.deployedACs

  for _, descriptor in pairs(descriptors) do
    local base = GameApi.ScenEdit_GetUnit(descriptor.baseGUID)

    if base then
      table.insert(rows, {
        name = descriptor.name,
        baseGUID = descriptor.baseGUID,
        latitude = base.latitude,
        longitude = base.longitude,
        embarkedUnits = Utils.deepCopy(descriptor.embarkedUnits),
        loadouts = Utils.deepCopy(descriptor.loadouts)
      })
    end
  end

  return gKH.json.stringify(rows)
end

---Collect each amphibious operation's staging point and boat zone as a waypoint route
---@param config SBJ__Config
---@return string # JSON formatted amphibious task force location data with coordinates
local function createAmphibiousTaskForceLocationDataString(config)
  ---@type SBJ__AmphibiousLocation[]
  local data = {}

  for _, zone in ipairs(config.red.amphibOps.zones) do
    local item = { name = zone.name, waypoints = {} }

    local point = GameApi.ScenEdit_GetReferencePoint({
      side = constants.SIDES.RED,
      name = zone.fleet.groups[1].from.startingPoint[1],
    })

    if point then
      table.insert(item.waypoints, { latitude = point.latitude, longitude = point.longitude })
    end

    local destination = GameApi.ScenEdit_GetReferencePoint({
      side = constants.SIDES.RED,
      name = zone.landing.hovercraft.zone[1],
    })

    if destination then
      table.insert(item.waypoints, { latitude = destination.latitude, longitude = destination.longitude })
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


---Apply the control panel's submitted deployments: GNSS jammers, then aircraft, then missile batteries
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param result SBJ__ControlPanelResult
local function updateFromControlPanelResult(config, saveData, sideName, result)
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
    MissileSystem.redeployFromControlPanel(config, saveData, sideName, missileSystems)

    local rebuiltNames = {}
    for _, system in ipairs(missileSystems) do
      table.insert(rebuiltNames, system.unitname)
    end
    IntegratedAirDefenseSystem.relinkRebuiltUnits(PersistentState.iads(saveData, sideName), sideName, rebuiltNames)
  end
end

---Same units as each side's `addXXX` special action scripts, in the order they run
---@type table<string, SBJ__AddUnitAction[]>
local ADD_UNIT_ACTIONS = {
  [constants.SIDES.RED] = {
    {
      id = "addACs",
      label = "Add aircraft",
      run = function(config)
        UnitGenerator.addAircraft(config.red.air.deployedACs)
      end
    },
    {
      id = "addC2Facilities",
      label = "Add C2 facilities",
      run = function(config)
        PersistentState.update(function(saveData)
          IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)
        end)
      end
    },
    {
      id = "addCSG",
      label = "Add CSG",
      run = function(config)
        UnitGenerator.createCSG(config.red.surface.lacm.csg)
      end
    },
    {
      id = "addGnssJammers",
      label = "Add GNSS jammers",
      run = function(config)
        GnssJamming.deploySide(config, constants.SIDES.RED)
      end
    },
    {
      id = "addLandingShips",
      label = "Add landing ships",
      run = function(config)
        UnitGenerator.removeLandingShips()
        UnitGenerator.addLandingShips(config.red.amphibOps)
      end
    },
    {
      id = "addSAGs",
      label = "Add SAGs",
      run = function(config)
        local sags = {}
        for _, zone in ipairs(config.red.amphibOps.zones) do
          for _, sag in ipairs(zone.sags) do
            table.insert(sags, sag)
          end
        end
        UnitGenerator.createSAGs(constants.SIDES.RED, sags)
      end
    },
    {
      id = "addSubmarines",
      label = "Add submarines",
      run = function(config)
        UnitGenerator.addSubmarines(config, constants.SIDES.RED)
      end
    },
    {
      id = "addMissileSystems",
      label = "Add missile systems",
      run = function(config)
        PersistentState.update(function(saveData)
          MissileSystem.deploySide(config, saveData, constants.SIDES.RED)
        end)
      end
    },
  },
  [constants.SIDES.BLUE] = {
    {
      id = "addACs",
      label = "Add aircraft",
      run = function(config)
        PersistentState.update(function(saveData)
          UnitGenerator.addAircraft(config.blue.air.deployedACs)
          CommsJamming.updateTargetAircraft(config, saveData)
        end)
      end
    },
    {
      id = "addDeployedShipsAtPort",
      label = "Add deployed ships at port",
      run = function(config)
        UnitGenerator.addDeployedShipsAtPort(constants.SIDES.BLUE, config.blue.surface.deployedShips)
      end
    },
    {
      id = "addSAGs",
      label = "Add SAGs",
      run = function(config)
        UnitGenerator.createSAGs(constants.SIDES.BLUE, config.blue.surface.sags)
      end
    },
    {
      id = "addMissileSystems",
      label = "Add missile systems",
      run = function(config)
        PersistentState.update(function(saveData)
          MissileSystem.deploySide(config, saveData, constants.SIDES.BLUE)
        end)
      end
    },
  },
}

---Run the ticked add-units actions in menu order
---@param config SBJ__Config
---@param sideName string
---@param actionIds string[]
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

---Rows the add-units page lists for a side
---@param sideName string
---@return SBJ__AddUnitOption[]
local function buildAddUnitRows(sideName)
  local rows = {}
  for _, action in ipairs(ADD_UNIT_ACTIONS[sideName] or {}) do
    table.insert(rows, { id = action.id, label = action.label })
  end
  return rows
end

---Parse a hidden-input value the page wrote, or nil when the page never wrote it.
---CMO returns an untouched input as an empty string, which the JSON parser rejects.
---@generic T
---@param raw string|nil Raw form value, wrapped in single quotes by CMO
---@return T|nil
local function parseFormJson(raw)
  if raw == nil then
    return nil
  end
  local jsonStr = raw:gsub("^'", ""):gsub("'$", "")
  if jsonStr == "" then
    return nil
  end
  return gKH.json.parse(jsonStr)
end

---Apply the SAM doctrine the control panel submitted to the Taiwan facilities
---@param emconResult SBJ__EmconResult|nil
local function applySamDoctrine(emconResult)
  if emconResult and emconResult.sams and #emconResult.sams > 0 then
    IntegratedAirDefenseSystem.setSamDoctrine(emconResult.sams)
  end
end

---Apply the SAM-to-C2 assignments the control panel submitted to the side's IADS
---@param saveData SBJ__SaveData
---@param sideName string
---@param emconResult SBJ__EmconResult|nil
local function applyC2Assignments(saveData, sideName, emconResult)
  if emconResult and emconResult.c2Nodes and #emconResult.c2Nodes > 0 then
    IntegratedAirDefenseSystem.reassignSamUnits(PersistentState.iads(saveData, sideName), emconResult.c2Nodes)
  end
end

---Show the control panel and apply what the player submitted.
---In play mode (`config.isEditMode` false) the deployment is accepted once: the first
---submission locks it, and later ones are ignored. Add-units is edit mode only.
---@param config SBJ__Config
---@param sideName string
function UnitStatusUI.createControlPanel(config, sideName)
  local view = STATUS_UI_SIDES[sideName] or STATUS_UI_SIDES[constants.SIDES.BLUE]
  local isEditMode = config.isEditMode == true
  local msg

  local isLoaded = PersistentState.read(function(saveData)
    local isLocked = not isEditMode and PersistentState.isDeploymentLocked(saveData, sideName)
    local landingUnitsString = view.showsLandedUnits
        and gKH.json.stringify(LandingOps.countUnitsInEachArea(config))
        or "{}"

    msg = string.format(
      getControlPanelTemplate(),
      createGnssJammerDataString(config, sideName),
      createDeployedAircraftDataString(config, sideName),
      gKH.json.stringify(MissileSystem.buildDeploymentSystems(config, saveData, sideName)),
      sideName,
      gKH.json.stringify(buildAddUnitRows(sideName)),
      createAmphibiousTaskForceLocationDataString(config),
      createC2NodeDataString(saveData, sideName, view.c2Types),
      createSignalDataString(saveData, view.signalSide),
      gKH.json.stringify(MissileSystem.buildBatteryStatuses(config, saveData, sideName)),
      landingUnitsString,
      tostring(isEditMode),
      tostring(isLocked)
    )
  end)
  if not isLoaded then
    return
  end

  local form = GameApi.UI_CallAdvancedHTMLDialog("Title", msg, { "Done" })
  if form["pressed"] ~= "Done" then
    return
  end
  ---@type SBJ__ControlPanelResult|nil
  local controlPanelResult = parseFormJson(form["summaryData"])
  local emconResult = parseFormJson(form["emconData"])
  if controlPanelResult then
    PersistentState.update(function(saveData)
      if not isEditMode and PersistentState.isDeploymentLocked(saveData, sideName) then
        return
      end
      -- Node assignments name units by their current GUIDs, so they go before a redeploy replaces them
      applyC2Assignments(saveData, sideName, emconResult)
      updateFromControlPanelResult(config, saveData, sideName, controlPanelResult)
      if not isEditMode then
        PersistentState.setDeploymentLocked(saveData, sideName)
      end
    end)
  end

  applySamDoctrine(emconResult)

  ---@type SBJ__AddUnitsMenuResult|nil
  local addUnits = isEditMode and parseFormJson(form["selectedActions"]) or nil
  if addUnits and addUnits.actionIds then
    runAddUnitActions(config, sideName, addUnits.actionIds)
  end
end

return UnitStatusUI
