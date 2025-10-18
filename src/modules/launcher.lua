local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")

local Launcher = {}

-- Private functions

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param positions SBJ__Position[] Position information table
---@return string[]|nil Area name or nil
local function findUnitArea(unit, positions)
  for _, p in pairs(positions) do
    if unit:inArea(p.RL.area) then
      return p.RL.area
    end
  end

  return nil
end


-- Private helper functions
---Set unit movement and weapon control status
---@param unit CMO__Unit Unit object
---@param throttle string Throttle setting (e.g. 'Flank', 'Stop')
---@param speed number Speed
---@param course CMO__TableOfWaypoints|nil Waypoints
---@param holdPosition boolean Whether to hold position
---@param wcs number|nil Weapon control status (1: Free, 2: Hold)
---@param formation table|nil Formation settings
local function setUnitProperties(unit, throttle, speed, course, holdPosition, wcs, formation)
  if not unit then return end

  local unitSetParams = {
    guid = unit.guid,
    manualthrottle = throttle,
    manualSpeed = speed,
    holdposition = holdPosition
  }
  if course then unitSetParams.course = course end
  GameApi.ScenEdit_SetUnit(unitSetParams)

  if wcs then
    GameApi.ScenEdit_SetDoctrine({ side = unit.side, guid = unit.guid }, { weapon_control_status_land = wcs })
  end

  if formation then
    unit.formation = formation
  end
end


---Command artillery battery to move to reload point (RL)
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
local function toRL(config, battery, group)
  battery.state = config.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, battery.position.RL.course, false, 2)
  end
end

---Command artillery battery to move to hide area (HA)
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
local function toHA(config, battery, group)
  battery.state = config.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, battery.position.HA.course, false, 2)
  end
end

---Command ammunition section to move to ammunition storage area (AHA)
---@param config SBJ__CONFIG
---@param section SBJ__AmmunitionSectionContext Ammunition section object
---@param group CMO__Unit Unit group
local function toAHA(config, section, group)
  section.state = config.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, section.position.AHA.course, false)
  end
end

---Transfer ammunition from ammunition depot to ammunition section
---@param section SBJ__AmmunitionSectionContext Ammunition section object
---@param ammunition SBJ__AmmunitionContext Ammunition depot object
local function transload(section, ammunition)
  if ammunition.wpnCurrent > 0 and section.wpnCurrent < section.wpnDefault then
    if ammunition.wpnCurrent >= section.wpnDefault then
      section.wpnCurrent = section.wpnCurrent + section.wpnDefault
      ammunition.wpnCurrent = ammunition.wpnCurrent - section.wpnDefault
    else
      section.wpnCurrent = section.wpnCurrent + ammunition.wpnCurrent
      ammunition.wpnCurrent = 0
    end
  end

  section.reloadStartTime = nil
end

---Command ammunition section to move to reload point (RL)
---@param config SBJ__CONFIG
---@param section SBJ__AmmunitionSectionContext Ammunition section object
---@param group CMO__Unit Unit group
local function ammoSecToRL(config, section, group)
  section.state = config.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, section.position.RL.course[#section.position.RL.course], false)
  end
end

---Handle automatic artillery battery repositioning logic
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param battery SBJ__BatteryContext
---@param group CMO__Unit
---@param isAuto boolean
local function handleAutomaticBatteryRepositioning(config, saveData, wpnSystem, side, battery, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = config[field]['ground'][wpnSystem]

  if battery.state == config.batteryState.STATIC then
    if Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
      toRL(config, battery, group)
    end
  end

  if battery.state == config.batteryState.RELOAD then
    if battery.reloadStartTime == nil then
      battery.reloadStartTime = GameApi.ScenEdit_CurrentTime() - systemConfig.reloadTime
    end

    local elapsedTime = GameApi.ScenEdit_CurrentTime() - battery.reloadStartTime
    local result = Launcher.isMetWithAmmoTrucks(config, saveData, group, wpnSystem, isAuto)
    local isMoreThanReloadTime = (
      battery.reloadStartTime ~= nil and
      elapsedTime >= systemConfig.reloadTime and
      result.isMet and
      Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

    if isMoreThanReloadTime then
      Launcher.reload(battery, system.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
      toHA(config, battery, group)
    end
  end
end

---Handle manual artillery battery reload logic
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param battery SBJ__BatteryContext
---@param group CMO__Unit
---@param isAuto boolean
local function handleManualBatteryReload(config, saveData, wpnSystem, side, battery, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = config[field]['ground'][wpnSystem]

  if battery.reloadStartTime == nil then
    battery.reloadStartTime = GameApi.ScenEdit_CurrentTime() + systemConfig.reloadTime * 100
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - battery.reloadStartTime
  local result = Launcher.isMetWithAmmoTrucks(config, saveData, group, wpnSystem, isAuto)
  local isMoreThanReloadTime = (
    battery.reloadStartTime ~= nil and
    elapsedTime >= systemConfig.reloadTime and
    result.isMet and
    Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

  if isMoreThanReloadTime then
    Launcher.reload(battery, system.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1)
    end
  end
end

---Handle automatic ammunition section repositioning logic
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param section SBJ__AmmunitionSectionContext
---@param group CMO__Unit
---@param isAuto boolean
local function handleAutomaticSectionRepositioning(config, saveData, wpnSystem, side, section, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = config[field]['ground'][wpnSystem]

  if section.state == config.batteryState.STATIC then
    if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
      toAHA(config, section, group)
    end
  end

  if section.state == config.batteryState.RELOAD then
    local elapsedTime = GameApi.ScenEdit_CurrentTime() - section.reloadStartTime
    local result = Launcher.isMetWithAmmo(config, saveData, group, wpnSystem, isAuto)
    local isMoreThanReloadTime = (
      section.reloadStartTime ~= nil and
      elapsedTime >= systemConfig.reloadTime and
      section.wpnCurrent == 0 and result.isMet)

    if isMoreThanReloadTime then
      transload(section, system.ammunitions[section.ammunition])
      ammoSecToRL(config, section, group)

      if config.isDevMode then
        GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
      end
    end
  end
end

---Handle manual ammunition section reload logic
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param section SBJ__AmmunitionSectionContext
---@param group CMO__Unit
---@param isAuto boolean
local function handleManualSectionReload(config, saveData, wpnSystem, side, section, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = config[field]['ground'][wpnSystem]

  if section.reloadStartTime == nil then
    section.reloadStartTime = GameApi.ScenEdit_CurrentTime() + systemConfig.reloadTime * 100
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - section.reloadStartTime
  local result = Launcher.isMetWithAmmo(config, saveData, group, wpnSystem, isAuto)
  local isMoreThanReloadTime = (
    section.reloadStartTime ~= nil and
    elapsedTime >= systemConfig.reloadTime and
    section.wpnCurrent == 0 and result.isMet)

  if isMoreThanReloadTime then
    transload(section, system.ammunitions[section.ammunition])

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
    end
  end
end

---Handle status and actions of all ammunition sections
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
local function processAmmunitionSections(config, saveData, wpnSystem, side, isAuto)
  local field = (side == 'China') and 'c' or 't'

  for _, section in pairs(saveData[field]['ground'][wpnSystem].ammunitionSections) do
    local group = GameApi.ScenEdit_GetUnit(section.guid)

    if group then
      if isAuto then
        handleAutomaticSectionRepositioning(config, saveData, wpnSystem, side, section, group,
          isAuto)
      else
        handleManualSectionReload(config, saveData, wpnSystem, side, section, group, isAuto)
      end
    end
  end
end

---Handle status and actions of all artillery batteries
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
local function processBatteries(config, saveData, wpnSystem, side, isAuto)
  local field = (side == 'China') and 'c' or 't'

  for _, battery in pairs(saveData[field]['ground'][wpnSystem].batteries) do
    local group = GameApi.ScenEdit_GetUnit(battery.guid)

    if group then
      if isAuto then
        handleAutomaticBatteryRepositioning(config, saveData, wpnSystem, side, battery, group, isAuto)
      else
        handleManualBatteryReload(config, saveData, wpnSystem, side, battery, group, isAuto)
      end
    end
  end
end

-- Public functions

---Execute reload for artillery battery
---@param battery SBJ__BatteryContext Artillery battery object
---@param ammunitionSection SBJ__AmmunitionSectionContext Ammunition section object
---@param weaponDBID number Weapon database ID
function Launcher.reload(battery, ammunitionSection, weaponDBID)
  local group = GameApi.ScenEdit_GetUnit(battery.guid)
  if not group then return end

  for index, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and unit.mounts then
      for _, mount in ipairs(unit.mounts) do
        local totalWpnCurrentNum = 0
        local totalWpnDefaultNum = 0

        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
          if wpn['wpn_dbid'] == weaponDBID then
            totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
            totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
          end
        end

        local requiredNum = totalWpnDefaultNum - totalWpnCurrentNum

        if ammunitionSection.wpnCurrent >= requiredNum then
          GameApi.ScenEdit_AddReloadsToUnit({
            guid = unit.guid,
            wpn_dbid = weaponDBID,
            number = requiredNum
          })

          ammunitionSection.wpnCurrent = ammunitionSection.wpnCurrent - requiredNum
        elseif ammunitionSection.wpnCurrent > 0 and ammunitionSection.wpnCurrent < requiredNum then
          GameApi.ScenEdit_AddReloadsToUnit({
            guid = unit.guid,
            wpn_dbid = weaponDBID,
            number = ammunitionSection.wpnCurrent
          })

          ammunitionSection.wpnCurrent = 0
        end
      end
    end
  end

  battery.reloadStartTime = nil
end

---Set artillery battery reload start time
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
---@param isAuto boolean Whether in automatic mode
function Launcher.setReloadStartTime(config, battery, group, isAuto)
  battery.state = config.batteryState.RELOAD
  battery.reloadStartTime = GameApi.ScenEdit_CurrentTime()

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u and isAuto then
      setUnitProperties(u, 'Stop', 0, nil, true, nil, { spacing = 0, transpose = true })
    end
  end
end

---Set artillery battery weapon control status to free fire
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
function Launcher.setWCSToFree(config, battery, group)
  battery.state = config.batteryState.STATIC

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties(u, 'Stop', 0, nil, true, 1, { spacing = 0, transpose = true })
    end
  end
end

---Set artillery battery status to hide
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
function Launcher.setStateToHIDE(config, battery, group)
  battery.state = config.batteryState.HIDE

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties(u, 'Stop', 0, nil, true, 2, { spacing = 0, transpose = true })
    end
  end
end

---Check if unit/group ammunition is below specified percentage
---@param group CMO__Unit Unit or group object
---@param percentage number Percentage threshold
---@param weaponDBID number Weapon database ID
---@return boolean Whether it is low ammunition
function Launcher.isLowAmmo(group, percentage, weaponDBID)
  local totalWpnCurrentNum = 0
  local totalWpnDefaultNum = 0

  local function processUnit(unit)
    if not unit then return end

    for _, mount in ipairs(unit.mounts) do
      for _, weapon in ipairs(mount.mount_weapons) do
        if weapon.wpn_dbid == weaponDBID then
          totalWpnCurrentNum = totalWpnCurrentNum + weapon.wpn_current
          totalWpnDefaultNum = totalWpnDefaultNum + weapon.wpn_maxcap
        end
      end
    end
  end

  if group.group == nil then
    local unit = GameApi.ScenEdit_GetUnit(group.guid)
    processUnit(unit)
  else
    for _, guid in ipairs(group.group.unitlist) do
      local unit = GameApi.ScenEdit_GetUnit(guid)
      processUnit(unit)
    end
  end

  if totalWpnDefaultNum == 0 then return false end
  local currentPercentage = (totalWpnCurrentNum / totalWpnDefaultNum) * 100
  return currentPercentage <= percentage
end

---Command artillery battery to move to firing position (FP)
---@param config SBJ__CONFIG
---@param battery SBJ__BatteryContext Artillery battery object
---@param group CMO__Unit Unit group
function Launcher.toFringPosition(config, battery, group)
  battery.state = config.batteryState.REPOSITIONING
  local courseIdx = math.random(Utils.getCount(battery.position.FP))

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      setUnitProperties(unit, 'Flank', 30, battery.position.FP[courseIdx].course, false)
    end
  end
end

---Check if artillery battery has met with ammunition trucks
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param wpnSystem string
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__BatteryContext|nil}
function Launcher.isMetWithAmmoTrucks(config, saveData, unit, wpnSystem, isAuto)
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'
  if not unit.group then return { isMet = false, battery = nil } end
  local group = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not group then return { isMet = false, battery = nil } end
  local batteryField, ammunitionField = 'batteries', 'ammunitionSections'

  if string.find(group.name, 'Ammo') or string.find(group.name, 'SUPP') then
    batteryField, ammunitionField = 'ammunitionSections', 'batteries'
  end

  local system = saveData[field]['ground'][wpnSystem]
  local positions = config[field]['ground'][wpnSystem].positions

  for _, battery in pairs(system[batteryField]) do
    local isStateValid = true

    if isAuto then
      local repoState = config.batteryState.REPOSITIONING
      local reloadState = config.batteryState.RELOAD
      isStateValid = (battery.state == repoState or battery.state == reloadState)
    end

    if battery.guid == group.guid and isStateValid then
      local area = findUnitArea(unit, positions)
      if not area then return { isMet = false, battery = nil } end

      for _, section in pairs(system[ammunitionField]) do
        local ammoSec = GameApi.ScenEdit_GetUnit(section.guid)

        if ammoSec and ammoSec:inArea(area) then
          return { isMet = true, battery = battery }
        end
      end
    end
  end

  return { isMet = false, battery = nil }
end

---Check if ammunition section has met with ammunition depot
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param wpnSystem string
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__AmmunitionSectionContext|nil}
function Launcher.isMetWithAmmo(config, saveData, unit, wpnSystem, isAuto)
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'
  if not unit.group then return { isMet = false, battery = nil } end
  local group = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not group then return { isMet = false, battery = nil } end
  local system = saveData[field]['ground'][wpnSystem]
  local positions = config[field]['ground'][wpnSystem].positions

  for _, section in pairs(system.ammunitionSections) do
    local isStateValid = true

    if isAuto then
      local repoState = config.batteryState.REPOSITIONING
      local reloadState = config.batteryState.RELOAD
      isStateValid = (section.state == repoState or section.state == reloadState)
    end

    if section.guid == group.guid and isStateValid then
      local ammo = GameApi.ScenEdit_GetUnit(section.ammunition)

      for _, p in pairs(positions) do
        local isInSameArea = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))

        if isInSameArea then
          return { isMet = true, battery = section }
        end
      end
    end
  end

  return { isMet = false, battery = nil }
end

---Check status of all artillery batteries and ammunition sections, and trigger corresponding actions
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
function Launcher.checkBatteryState(config, saveData, wpnSystem, side, isAuto)
  processBatteries(config, saveData, wpnSystem, side, isAuto)
  processAmmunitionSections(config, saveData, wpnSystem, side, isAuto)
end

---Handle logic when ammunition section unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param side string Side
---@param wpnSystem string Platform type
---@param saveData SBJ__SaveData
function Launcher.destroyAmmoSecHandler(unit, side, wpnSystem, saveData)
  local field = (side == 'China') and 'c' or 't'
  local isAmmo = false
  if unit.group == nil then isAmmo = true end

  if isAmmo then
    local ammo = saveData[field].ground[wpnSystem].ammunitions[unit.guid]

    if ammo and ammo.wpnCurrent > 0 then
      ammo.wpnCurrent = 0
    end
  else
    local ammoSec = saveData[field].ground[wpnSystem].ammunitionSections[unit.group.guid]

    if ammoSec and ammoSec.wpnCurrent > 0 then
      if (ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount) < 0 then
        ammoSec.wpnCurrent = 0
      else
        ammoSec.wpnCurrent = ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount
      end
    end
  end
end

return Launcher
