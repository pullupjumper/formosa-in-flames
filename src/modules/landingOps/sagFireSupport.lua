local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local AttackManager = require("src.modules.attackManager")

---SAG surface fire support on the airlanding zones
local SagFireSupport = {}

---Find a SAG descriptor by group name across all zones
---@param zones SBJ__OperationalZoneDescriptor[]
---@param groupName string
---@return SBJ__SAGDescriptor|nil
local function findSAG(zones, groupName)
  for _, zone in ipairs(zones) do
    for _, sag in ipairs(zone.sags) do
      if sag.groupName == groupName then
        return sag
      end
    end
  end

  return nil
end

---Attack airlanding zone contacts with SAG surface fire support
---@param amphibOps SBJ__AmphibOpsConfig
---@param ship CMO__Unit
---@return boolean # True if the attack workflow was handled
function SagFireSupport.attackAirlandingZone(amphibOps, ship)
  if not ship.group or ship.dbid ~= constants.PLATFORMS.TYPE_052D then
    return false
  end

  local sagConfig = findSAG(amphibOps.zones, ship.group.name)
  if not sagConfig then
    return false
  end

  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    return false
  end

  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(sagConfig.area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      table.insert(filteredContacts, contact.guid)
    end
  end

  if #filteredContacts == 0 then
    return false
  end

  GameApi.ScenEdit_SetDoctrine(
    { side = ship.side, unitname = ship.group.name },
    { weapon_control_status_land = constants.WCS.FREE }
  )

  AttackManager.attackContacts({
    contacts = filteredContacts,
    qty = math.floor(amphibOps.fireSupport.airlandingShotQty / #filteredContacts),
    firingUnits = { ship },
    weaponDBID = constants.WEAPONS.HPJ_38,
  })

  return true
end

return SagFireSupport
