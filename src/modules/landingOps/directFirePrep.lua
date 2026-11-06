local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local AttackManager = require("src.modules.attackManager")
local StrikePlanner = require("src.modules.strikePlanner.init")

---Direct fire preparation on the landing zones: SAG naval gunfire and the recon flight that cues air strikes
local DirectFirePrep = {}

---Phases in which the SAG may fire on the airlanding zone
---@type table<string, true>
local NAVAL_FIRE_PHASES = {
  [constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT]   = true,
  [constants.AMPHIBIOUS_PHASES.MINE_CLEARING]     = true,
  [constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT]      = true,
  [constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING] = true,
  [constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING]   = true,
}

---Find a SAG descriptor by group name across all zones
---@param zones SBJ__OperationalZoneDescriptor[]
---@param groupName string
---@return SBJ__SAGDescriptor|nil sag
---@return string|nil zoneName
local function findSAG(zones, groupName)
  for _, zone in ipairs(zones) do
    for _, sag in ipairs(zone.sags) do
      if sag.groupName == groupName then
        return sag, zone.name
      end
    end
  end

  return nil, nil
end

---Attack airlanding zone contacts with SAG surface fire support while the zone is in the assault phases
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneStates table<string, SBJ__ZoneState>
---@param ship CMO__Unit
---@return boolean # True if the attack workflow was handled
function DirectFirePrep.attackAirlandingZone(amphibOps, zoneStates, ship)
  if not ship.group or ship.dbid ~= constants.PLATFORMS.TYPE_052D then
    return false
  end

  local sagConfig, zoneName = findSAG(amphibOps.zones, ship.group.name)
  if not sagConfig or not zoneName then
    return false
  end

  local zoneState = zoneStates[zoneName]
  if not zoneState or not NAVAL_FIRE_PHASES[zoneState.phase] then
    return false
  end

  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    return false
  end

  local contactGUIDs = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(sagConfig.area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      table.insert(contactGUIDs, contact.guid)
    end
  end

  if #contactGUIDs == 0 then
    return false
  end

  GameApi.ScenEdit_SetDoctrine(
    { side = ship.side, unitname = ship.group.name },
    { weapon_control_status_land = constants.WCS.TIGHT }
  )

  AttackManager.attackContacts({
    contacts = contactGUIDs,
    qty = math.floor(amphibOps.fireSupport.airlandingShotQty / #contactGUIDs),
    attackingUnits = { ship },
    weaponDBID = constants.WEAPONS.HPJ_38,
  })

  return true
end

---Schedule the zone's recon flight; the strike planner strikes what it finds
---@param config SBJ__Config
---@param reconState SBJ__ReconState
---@param zone SBJ__OperationalZoneDescriptor
function DirectFirePrep.scheduleAirRecon(config, reconState, zone)
  if zone.air.reconTemplate then
    StrikePlanner.addReconEntry(reconState, config.red.recon.templates[zone.air.reconTemplate])
  end
end

return DirectFirePrep
