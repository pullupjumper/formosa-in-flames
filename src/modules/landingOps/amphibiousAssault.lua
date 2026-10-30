local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local AcvWave = require("src.modules.landingOps.acvWave")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local ShipMovement = require("src.modules.landingOps.shipMovement")

local AmphibiousAssault = {}

-- ============================================================================
-- Constants
-- ============================================================================


---@type table<number, boolean>
local FERRY_OR_LST_DBIDS = {
  [constants.PLATFORMS.TYPE_071]    = true,
  [constants.PLATFORMS.TYPE_072III] = true,
  [constants.PLATFORMS.TYPE_072A]   = true,
  [constants.PLATFORMS.TYPE_073A]   = true,
}
local FERRY_NAME = "Ferry"

---@type table<string, boolean>
local NON_LST_NAMES = {
  RORO  = true,
  Barge = true,
}

---Unit types counted in each operational zone after they land
---@type {name: string, dbid: number}[]
local LANDED_UNIT_TYPES = {
  { name = "ZBD-05",        dbid = constants.PLATFORMS.ZBD05 },
  { name = "ZTD-05",        dbid = constants.PLATFORMS.ZTD05 },
  { name = "PLL-05",        dbid = constants.PLATFORMS.PLL05 },
  { name = "PLZ-96",        dbid = constants.PLATFORMS.PLZ96 },
  { name = "PGZ-09",        dbid = constants.PLATFORMS.PGZ09 },
  { name = "PGZ-95",        dbid = constants.PLATFORMS.PGZ95 },
  { name = "SA-15",         dbid = constants.PLATFORMS.SA15 },
  { name = "AirborneCorps", dbid = constants.PLATFORMS.MC },
  { name = "HMMWV",         dbid = constants.PLATFORMS.HMMWV },
  { name = "ZBD-03",        dbid = constants.PLATFORMS.ZBD03 },
}

-- ============================================================================
-- Validation and Filtering
-- ============================================================================

---Check if a unit is a Landing Ship Tank. Exclude auxiliary vessels and Type 082 sweepers
---@param unit CMO__Unit
---@return boolean # True if unit is an LST (not RORO, Barge or Type 082)
local function isLST(unit)
  return not NON_LST_NAMES[unit.name] and unit.dbid ~= constants.PLATFORMS.TYPE_082
end

---Check if a ship is a ferry or Landing Ship Tank (LST).
---Include Type 071/072/073 and ferries that can launch ACVs or beach.
---@param ship CMO__Unit
---@return boolean # True if ship is a ferry or LST
local function isFerryOrLST(ship)
  return FERRY_OR_LST_DBIDS[ship.dbid] == true or ship.name == FERRY_NAME
end

---Get the operational zone of a ship from its location.
---Match the ship position against the ACV deployment areas to get the zone configuration.
---@param zones SBJ__OperationalZoneDescriptor[]
---@param ship CMO__Unit
---@return SBJ__OperationalZoneDescriptor|nil # Zone descriptor, or nil if the ship is not in any zone
local function getShipZone(zones, ship)
  for _, zone in ipairs(zones) do
    if ship:inArea(zone.landing.acv.area) then
      return zone
    end
  end

  return nil
end

-- ============================================================================
-- Course Setting
-- ============================================================================

---Move an LST to its station inside the offshore band.
---In fast-forward debug, teleport it onto the station first.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param entry SBJ__LstStation
---@param params SBJ__MoveLSTToLaunchStationParams
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveLSTToLaunchStation(amphibOps, zone, entry, params)
  local unit = entry.unit
  local alongM = entry.alongM + params.shiftM
  local station = LaneGeometry.buildPoint(params.frame, alongM, entry.lateralM)

  if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
    DebugFlow.teleport(unit.guid, station)
  end
  unit.course = { station }
  unit.manualSpeed = zone.landing.lstSettings.speed
  return {
    tag = "OK",
    fields = {
      ship = unit.name,
      offshoreNm = string.format("%.1f", -alongM / constants.METERS_PER_NM),
      speed = zone.landing.lstSettings.speed
    }
  }
end

---Set the course of a Surface Action Group.
---In fast-forward debug, teleport every ship in the group into formation at the end of its route first.
---@param amphibOps SBJ__AmphibOpsConfig
---@param descriptor SBJ__SAGDescriptor
---@param heading number Zone heading the SAG faces
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setCourseForSAG(amphibOps, descriptor, heading)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.groupName)

  if not unit then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "sag_unit_not_found" } }
  end

  local route = descriptor.to.amphibiousVehicleStagingArea
  local fields = { sag = descriptor.groupName, dest = "amphibious_vehicle_staging_area" }

  if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
    if not unit.group or not unit.group.unitlist then
      return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "sag_unitlist_missing" } }
    end

    fields.positioned, fields.skipped = ShipMovement.teleportSagToFormation(unit, route[#route], heading)
  end

  unit.course = route
  return { tag = "OK", fields = fields }
end

---Find the LSTs anchored on the deploy line with their lane coordinates
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param units CMO__SideUnit[]
---@return SBJ__LstStation[]
local function findDeployLineLSTs(zone, frame, units)
  local entries = {}

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == "Ship" and unit:inArea(zone.movement.holdingAreas.deployLine) and isLST(unit) then
      local alongM, lateralM = LaneGeometry.projectPoint(frame, unit)
      table.insert(entries, { unit = unit, alongM = alongM, lateralM = lateralM })
    end
  end

  return entries
end

---Move every LST anchored in a zone to its launch station.
---The formation keeps its shape. Shift it along the landing bearing to the middle of the offshore band.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean success True when the formation fits the band
---@return SBJ__LogResult[] results Deferred log results in emission order
local function moveZoneLSTsToLaunchStations(amphibOps, zone, units)
  local center = GameUtils.findAreaLocations(constants.SIDES.RED, zone.landing.laneCenter)[1]
  if not center then
    return false, { { tag = "FAIL", fields = { reason = "lane_center_not_set" } } }
  end

  local frame = { origin = center, bearing = zone.heading }
  local entries = findDeployLineLSTs(zone, frame, units)
  if #entries == 0 then
    return true, {}
  end

  local nearM = amphibOps.route.launchStationNearNm * constants.METERS_PER_NM
  local farM = amphibOps.route.launchStationFarNm * constants.METERS_PER_NM
  local seawardM, shoreM = entries[1].alongM, entries[1].alongM
  for _, entry in ipairs(entries) do
    seawardM = math.min(seawardM, entry.alongM)
    shoreM = math.max(shoreM, entry.alongM)
  end

  if shoreM - seawardM > farM - nearM then
    return false, { {
      tag = "FAIL",
      fields = {
        reason = "formation_exceeds_station_band",
        depthNm = string.format("%.2f", (shoreM - seawardM) / constants.METERS_PER_NM),
        bandNm = amphibOps.route.launchStationFarNm - amphibOps.route.launchStationNearNm,
      }
    } }
  end

  local shiftM = -(nearM + farM) / 2 - (seawardM + shoreM) / 2
  local results = {}
  for _, entry in ipairs(entries) do
    table.insert(results, moveLSTToLaunchStation(amphibOps, zone, entry, { frame = frame, shiftM = shiftM }))
  end

  return true, results
end

---Move every SAG in a zone to its launch station. Stop at the first failure
---@param amphibOps SBJ__AmphibOpsConfig
---@param sags SBJ__SAGDescriptor[]
---@param heading number Zone heading the SAGs face
---@return boolean success True when no SAG failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function moveZoneSAGsToLaunchStations(amphibOps, sags, heading)
  local results = {}

  for _, descriptor in ipairs(sags) do
    local result = setCourseForSAG(amphibOps, descriptor, heading)
    table.insert(results, result)

    if result.tag == "FAIL" then
      return false, results
    end
  end

  return true, results
end

-- ============================================================================
-- Public API
-- ============================================================================

---Find the lateral positions of the LSTs anchored on the deploy line
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param units CMO__SideUnit[]
---@return number[] # Meters to the right of the landing bearing
function AmphibiousAssault.findDeployLineLSTLaterals(zone, frame, units)
  local laterals = {}
  for _, entry in ipairs(findDeployLineLSTs(zone, frame, units)) do
    table.insert(laterals, entry.lateralM)
  end
  return laterals
end

---Move the LSTs to their offshore stations and the SAGs to the staging areas.
---The LSTs on the deploy line keep their formation and move to launchStationNearNm..launchStationFarNm off the shore.
---RORO ships, barges and Type 082s stay put.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean # True if all LST courses were set
function AmphibiousAssault.moveToLaunchStations(amphibOps, zone, units)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Move to launch stations")

  local success, results = moveZoneLSTsToLaunchStations(amphibOps, zone, units)
  report.addAll(results)

  if success then
    local sagResults
    success, sagResults = moveZoneSAGsToLaunchStations(amphibOps, zone.sags, zone.heading)
    report.addAll(sagResults)
  end

  report.emit()

  return success
end

---Count enemy ground force contacts in the air landing zone.
---Count only contacts of type FACILITY_MOBILE to assess the threat level of the landing zone.
---@param contacts CMO__Contact[]
---@param area CMO__ReferencePoint[]
---@return integer # Number of enemy ground units in the area
function AmphibiousAssault.countContactsInArea(contacts, area)
  local count = 0
  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      count = count + 1
    end
  end
  return count
end

---Count landed China units by type in each operational zone's CAS area
---@param zones SBJ__OperationalZoneDescriptor[]
---@return table<string, table<string, number>> # Unit counts keyed by zone name, then by unit type label
function AmphibiousAssault.countUnitsInEachArea(zones)
  local unitsFromRed = GameApi.VP_GetSide({ side = constants.SIDES.RED }).units
  local result = {}

  for _, zone in ipairs(zones) do
    local item = {}
    for _, unitType in ipairs(LANDED_UNIT_TYPES) do
      item[unitType.name] = 0
    end

    for _, u in ipairs(unitsFromRed) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if unit and unit:inArea(zone.air.attackHelicopter.zone) then
        for _, unitType in ipairs(LANDED_UNIT_TYPES) do
          if unit.dbid == unitType.dbid then
            item[unitType.name] = item[unitType.name] + 1
          end
        end
      end
    end

    result[zone.name] = item
  end

  return result
end

---Launch amphibious combat vehicles for a ship after its zone reaches the assault landing.
---A paused wave leaves the ship waiting at the launch line. An empty ship returns to base.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneStates table<string, SBJ__ZoneState> Zone states indexed by zone name
---@param ship CMO__Unit
---@return boolean # True if the launch workflow was handled
function AmphibiousAssault.launchACV(amphibOps, zoneStates, ship)
  if not isFerryOrLST(ship) then
    return false
  end

  local zone = getShipZone(amphibOps.zones, ship)
  if not zone then
    return false
  end

  local zoneState = zoneStates[zone.name]
  if not zoneState or not constants.AMPHIBIOUS_LANDING_PHASES[zoneState.phase] then
    return false
  end

  local result = AcvWave.release(amphibOps, zone, zoneState, ship)

  if result and result.isEmpty then
    local hosted = GameApi.ScenEdit_HostUnitToParent({
      HostedUnitNameOrID = ship.guid,
      SelectedBaseNameOrID = zone.movement.baseGUID
    })

    if not hosted then
      return false
    end

    ship:RTB(true)
  end

  return true
end

---Check if any LST or ferry on the deploy line still carries ACVs
---@param zone SBJ__OperationalZoneDescriptor
---@param ships CMO__SideUnit[]
---@return boolean # True if some ship in the ACV area still holds ZBD/ZTD cargo
function AmphibiousAssault.hasUnreleasedACV(zone, ships)
  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)
    if ship and isFerryOrLST(ship) and ship:inArea(zone.landing.acv.area) then
      if AcvWave.hasCargo(ship) then
        return true
      end
    end
  end

  return false
end

return AmphibiousAssault
