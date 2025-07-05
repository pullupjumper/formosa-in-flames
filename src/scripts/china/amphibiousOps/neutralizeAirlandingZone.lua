local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local CONFIG = require("src.core.constants")
local AttackManager = require("src.modules.strikePlanner.attackManager")

local contacts = GameApi.ScenEdit_GetContacts('China')

if not contacts then
  return
end

local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end

if ship and ship.group and ship.dbid == CONFIG.platformDBID48 then
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(CONFIG.c.PHIBOP.sag[ship.group.name].area) and (contact.typed == 8) then
      table.insert(filteredContacts, contact.guid)
    end
  end

  if Utils.GetCount(filteredContacts) > 0 then
    AttackManager.AttackContacts({
      contacts = filteredContacts,
      qty = 440 // Utils.GetCount(filteredContacts),
      batteries = { ship },
      weaponDBID = 2691,
    })
  end
end
