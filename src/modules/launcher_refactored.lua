local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local CONFIG = require("src.core.constants")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")

local Launcher = {}

-- Private functions

---尋找單位所在的區域
---@param unit CMO__Unit 單位物件
---@param positions table 位置資訊表
---@return string[]|nil 區域名稱或 nil
local function findUnitArea(unit, positions)
  for _, p in pairs(positions) do
    if unit:inArea(p.RL.area) then
      return p.RL.area
    end
  end
  return nil
end

---命令砲兵營移動至再裝填點 (RL)
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
local function toRL(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  for _, guid in ipairs(group.group.unitlist) do
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

    if not unit then
      Logger.error('Failed to get unit ' .. guid .. ': ' .. err)
      goto continue
    end

    unit, err = Utils.SafeCall("GameApi.ScenEdit_SetUnit", GameApi.ScenEdit_SetUnit, {
      guid = unit.guid,
      manualthrottle = 'Flank',
      manualSpeed = 30,
      course = battery.position.RL.course,
      holdposition = false
    })

    if not unit then
      Logger.error('Failed to set unit ' .. guid .. ': ' .. err)
      goto continue
    end

    local doctrine, err = Utils.SafeCall(
      "GameApi.ScenEdit_SetDoctrine",
      GameApi.ScenEdit_SetDoctrine,
      { side = 'China', guid = unit.guid },
      { weapon_control_status_land = 2 }
    ) -- WCS Hold

    if not doctrine then
      Logger.error('Failed to set doctrine for unit ' .. guid .. ': ' .. err)
    end
    -- local unit = SE_GetUnit({ guid = guid })
    -- if unit then
    --   ScenEdit_SetUnit({
    --     guid = unit.guid,
    --     manualthrottle = 'Flank',
    --     manualSpeed = 30,
    --     course = battery.position.RL.course,
    --     holdposition = false
    --   })
    --   ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 }) -- WCS Hold
    -- end

    ::continue::
  end
end

---命令砲兵營移動至隱蔽區 (HA)
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
local function toHA(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })
    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = battery.position.HA.course,
        holdposition = false
      })
      ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 }) -- WCS Hold
    end
  end
end

---命令彈藥分隊移動至彈藥儲放區 (AHA)
---@param section SBJ__AmmunitionSection 彈藥分隊物件
---@param group CMO__Unit 單位群組
local function toAHA(section, group)
  section.state = CONFIG.batteryState.REPOSITIONING
  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })
    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = section.position.AHA.course,
        holdposition = false,
      })
    end
  end
  if CONFIG.isDevMode then
    GameUtils.PrintBox('China', 'func/toAHA/' .. tostring(section.name))
  end
end

---從彈藥庫轉運彈藥至彈藥分隊
---@param section SBJ__AmmunitionSection 彈藥分隊物件
---@param ammunition SBJ__Ammunition 彈藥庫物件
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

---命令彈藥分隊移動至再裝填點 (RL)
---@param section SBJ__AmmunitionSection 彈藥分隊物件
---@param group CMO__Unit 單位群組
local function ammoSecToRL(section, group)
  section.state = CONFIG.batteryState.REPOSITIONING
  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })
    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = { section.position.RL.course[#section.position.RL.course] },
        holdposition = false
      })
    end
  end
end

---處理砲兵營的自動化重新部署邏輯
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param battery SBJ__Battery
---@param group CMO__Unit
---@param isRepositioningAutomatically boolean
local function handleAutomaticBatteryRepositioning(saveData, platform, side, battery, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]
  if battery.state == CONFIG.batteryState.STATIC then
    if Launcher.IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
      toRL(battery, group)
    end
  end
  if battery.state == CONFIG.batteryState.RELOAD then
    if battery.reloadStartTime == nil then
      battery.reloadStartTime = ScenEdit_CurrentTime() - config.reloadTime
    end
    local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
    local result = Launcher.IsMetWithAmmoTrucks(saveData, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= config.reloadTime and result.isMet and Launcher.IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))
    if isMoreThanReloadTime then
      Launcher.Reload(battery, platforms.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
      toHA(battery, group)
    end
  end
end

---處理砲兵營的手動再裝填邏輯
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param battery SBJ__Battery
---@param group CMO__Unit
---@param isRepositioningAutomatically boolean
local function handleManualBatteryReload(saveData, platform, side, battery, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]
  if battery.reloadStartTime == nil then
    battery.reloadStartTime = ScenEdit_CurrentTime() + config.reloadTime * 100
  end
  local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
  local result = Launcher.IsMetWithAmmoTrucks(saveData, group, platform, isRepositioningAutomatically)
  local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= config.reloadTime and result.isMet and Launcher.IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))
  if isMoreThanReloadTime then
    Launcher.Reload(battery, platforms.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
    if CONFIG.isDevMode then
      ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1)
    end
  end
end

---處理彈藥分隊的自動化重新部署邏輯
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param section SBJ__AmmunitionSection
---@param group CMO__Unit
---@param isRepositioningAutomatically boolean
local function handleAutomaticSectionRepositioning(saveData, platform, side, section, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]
  if section.state == CONFIG.batteryState.STATIC then
    if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
      toAHA(section, group)
    end
  end
  if section.state == CONFIG.batteryState.RELOAD then
    local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
    local result = Launcher.IsMetWithAmmo(saveData, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= config.reloadTime and section.wpnCurrent == 0 and result.isMet)
    if isMoreThanReloadTime then
      transload(section, platforms.ammunitions[section.ammunition])
      ammoSecToRL(section, group)
      if CONFIG.isDevMode then
        ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
      end
    end
  end
end

---處理彈藥分隊的手動再裝填邏輯
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param section SBJ__AmmunitionSection
---@param group CMO__Unit
---@param isRepositioningAutomatically boolean
local function handleManualSectionReload(saveData, platform, side, section, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]
  if section.reloadStartTime == nil then
    section.reloadStartTime = ScenEdit_CurrentTime() + config.reloadTime * 100
  end
  local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
  local result = Launcher.IsMetWithAmmo(saveData, group, platform, isRepositioningAutomatically)
  local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= config.reloadTime and section.wpnCurrent == 0 and result.isMet)
  if isMoreThanReloadTime then
    transload(section, platforms.ammunitions[section.ammunition])
    if CONFIG.isDevMode then
      ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
    end
  end
end

---處理所有彈藥分隊的狀態和行動
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param isRepositioningAutomatically boolean
local function processAmmunitionSections(saveData, platform, side, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  for _, section in pairs(platforms.ammunitionSections) do
    local group = SE_GetUnit({ guid = section.guid })
    if not group then goto continue end
    if isRepositioningAutomatically then
      handleAutomaticSectionRepositioning(saveData, platform, side, section, group, isRepositioningAutomatically)
    else
      handleManualSectionReload(saveData, platform, side, section, group, isRepositioningAutomatically)
    end
    ::continue::
  end
end

---處理所有砲兵營的狀態和行動
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param isRepositioningAutomatically boolean
local function processBatteries(saveData, platform, side, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platformConfig = saveData[field]['ground'][platform]
  for _, battery in pairs(platformConfig.batteries) do
    local group = SE_GetUnit({ guid = battery.guid })
    if not group then goto continue end
    if isRepositioningAutomatically then
      handleAutomaticBatteryRepositioning(saveData, platform, side, battery, group, isRepositioningAutomatically)
    else
      handleManualBatteryReload(saveData, platform, side, battery, group, isRepositioningAutomatically)
    end
    ::continue::
  end
end

-- Public functions

---為砲兵營執行再裝填
---@param battery SBJ__Battery 砲兵營物件
---@param ammunitionSection SBJ__AmmunitionSection 彈藥分隊物件
---@param weaponDBID number 武器資料庫 ID
function Launcher.Reload(battery, ammunitionSection, weaponDBID)
  local group = SE_GetUnit({ guid = battery.guid })
  if group == nil then return end

  for index, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit == nil or unit.mounts == nil then goto continue end

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
        ScenEdit_AddReloadsToUnit({
          guid = unit.guid,
          wpn_dbid = weaponDBID,
          number = requiredNum
        })
        ammunitionSection.wpnCurrent = ammunitionSection.wpnCurrent - requiredNum
      elseif ammunitionSection.wpnCurrent > 0 and ammunitionSection.wpnCurrent < requiredNum then
        ScenEdit_AddReloadsToUnit({
          guid = unit.guid,
          wpn_dbid = weaponDBID,
          number = ammunitionSection.wpnCurrent
        })
        ammunitionSection.wpnCurrent = 0
      end
    end

    ::continue::
  end

  battery.reloadStartTime = nil
end

---設定砲兵營的再裝填開始時間
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
---@param isRepositioningAutomatically boolean 是否自動重新部署
function Launcher.SetReloadStartTime(battery, group, isRepositioningAutomatically)
  battery.state = CONFIG.batteryState.RELOAD
  battery.reloadStartTime = ScenEdit_CurrentTime()

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u and isRepositioningAutomatically then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

---設定砲兵營的武器管制狀態為自由開火
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.SetWCSToFree(battery, group)
  battery.state = CONFIG.batteryState.STATIC

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 }) -- WCS Free
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

---設定砲兵營的狀態為隱蔽
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.SetStateToHIDE(battery, group)
  battery.state = CONFIG.batteryState.HIDE

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 2 }) -- WCS Hold
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

---檢查單位/群組的彈藥是否低於指定百分比
---@param group CMO__Unit 單位或群組物件
---@param percentage number 百分比閾值
---@param weaponDBID number 武器資料庫 ID
---@return boolean 是否為低彈藥量
function Launcher.IsLowAmmo(group, percentage, weaponDBID)
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
    local unit = SE_GetUnit({ guid = group.guid })
    processUnit(unit)
  else
    for _, guid in ipairs(group.group.unitlist) do
      local unit = SE_GetUnit({ guid = guid })
      processUnit(unit)
    end
  end

  local currentPercentage = (totalWpnCurrentNum / totalWpnDefaultNum) * 100
  return currentPercentage <= percentage
end

---命令砲兵營移動至射擊陣地 (FP)
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.ToFringPosition(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  local courseIdx = math.random(Utils.GetCount(battery.position.FP))

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })
    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = battery.position.FP[courseIdx].course,
        holdposition = false
      })
    end
  end
end

---檢查砲兵營是否已與彈藥車會合
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param platform string
---@param isRepositioningAutomatically boolean
---@return table {isMet: boolean, battery: SBJ__Battery|nil}
function Launcher.IsMetWithAmmoTrucks(saveData, unit, platform, isRepositioningAutomatically)
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'
  if not unit.group then return { isMet = false, battery = nil } end
  local group = SE_GetUnit({ guid = unit.group.guid })
  if not group then return { isMet = false, battery = nil } end

  local batteryField, ammunitionField = 'batteries', 'ammunitionSections'
  if string.find(group.name, 'Ammo') or string.find(group.name, 'SUPP') then
    batteryField, ammunitionField = 'ammunitionSections', 'batteries'
  end

  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  for _, battery in pairs(platforms[batteryField]) do
    local isStateValid = true
    if isRepositioningAutomatically then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
      isStateValid = (battery.state == repoState or battery.state == reloadState)
    end

    if battery.guid == group.guid and isStateValid then
      local area = findUnitArea(unit, config.positions)
      if not area then return { isMet = false, battery = nil } end
      for _, section in pairs(platforms[ammunitionField]) do
        local ammoSec = SE_GetUnit({ guid = section.guid })
        if ammoSec and ammoSec:inArea(area) then
          return { isMet = true, battery = battery }
        end
      end
    end
  end
  return { isMet = false, battery = nil }
end

---檢查彈藥分隊是否已與彈藥庫會合
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param platform string
---@param isRepositioningAutomatically boolean
---@return table {isMet: boolean, battery: SBJ__AmmunitionSection|nil}
function Launcher.IsMetWithAmmo(saveData, unit, platform, isRepositioningAutomatically)
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'
  if not unit.group then return { isMet = false, battery = nil } end
  local group = SE_GetUnit({ guid = unit.group.guid })
  if not group then return { isMet = false, battery = nil } end

  local platfroms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  for _, section in pairs(platfroms.ammunitionSections) do
    local isStateValid = true
    if isRepositioningAutomatically then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
      isStateValid = (section.state == repoState or section.state == reloadState)
    end

    if section.guid == group.guid and isStateValid then
      local ammo = SE_GetUnit({ guid = section.ammunition })
      for _, p in pairs(config.positions) do
        local isInSameArea = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))
        if isInSameArea then
          return { isMet = true, battery = section }
        end
      end
    end
  end
  return { isMet = false, battery = nil }
end

---檢查所有砲兵營和彈藥分隊的狀態，並觸發相應的行動
---@param saveData SBJ__SaveData
---@param platform string
---@param side string
---@param isRepositioningAutomatically boolean
function Launcher.CheckBatteryState(saveData, platform, side, isRepositioningAutomatically)
  processBatteries(saveData, platform, side, isRepositioningAutomatically)
  processAmmunitionSections(saveData, platform, side, isRepositioningAutomatically)
end

---處理彈藥分隊單位被摧毀時的邏輯
---@param unit CMO__Unit 被摧毀的單位
---@param side string 陣營
---@param platform string 平台類型
---@param saveData SBJ__SaveData
function Launcher.DestroyAmmoSecHandler(unit, side, platform, saveData)
  local field = (side == 'China') and 'c' or 't'
  local isAmmo = false
  if unit.group == nil then isAmmo = true end

  if isAmmo then
    local ammo = saveData[field].ground[platform].ammunitions[unit.guid]
    if ammo and ammo.wpnCurrent > 0 then
      ammo.wpnCurrent = 0
    end
  else
    local ammoSec = saveData[field].ground[platform].ammunitionSections[unit.group.guid]
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
