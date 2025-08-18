local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.constants")
local AttackManager = require("src.modules.strikePlanner.attackManager")

local contacts = GameApi.ScenEdit_GetContacts('China')

if not contacts then
  return
end

local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end

if ship and ship.group and ship.dbid == config.platform.TYPE_052D then
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(config.c.PHIBOP.sag[ship.group.name].area) and (contact.typed == 8) then
      table.insert(filteredContacts, contact.guid)
    end
  end

  if Utils.getCount(filteredContacts) > 0 then
    AttackManager.attackContacts({
      contacts = filteredContacts,
      qty = 440 // Utils.getCount(filteredContacts),
      batteries = { ship },
      weaponDBID = 2691,
    })
  end
end
