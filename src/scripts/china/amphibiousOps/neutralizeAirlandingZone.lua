local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local AttackManager = require("src.modules.strikePlanner.attackManager")
local constants = require("src.core.constants")
local ship = GameApi.ScenEdit_UnitX()
local contacts = GameApi.ScenEdit_GetContacts("China")

if not contacts then
  return
end

if not ship then
  return
end

if ship and ship.group and ship.dbid == constants.PLATFORMS.TYPE_052D then
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(config.c.amphibOps.sag[ship.group.name].area) and (contact.typed == 8) then
      table.insert(filteredContacts, contact.guid)
    end
  end

  if Utils.getCount(filteredContacts) > 0 then
    GameApi.ScenEdit_SetDoctrine(
      { side = ship.side, unitname = ship.group.name },
      { weapon_control_status_land = constants.WCS.FREE }
    )

    AttackManager.attackContacts({
      contacts = filteredContacts,
      qty = 440 // Utils.getCount(filteredContacts),
      firingUnits = { ship },
      weaponDBID = constants.WEAPONS.HPJ_38,
    })
  end
end
