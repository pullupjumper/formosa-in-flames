local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")

local Launcher = {}

-- Private functions

---尋找單位所在的區域
---@param unit CMO__Unit 單位物件
---@param positions SBJ__Position[] 位置資訊表
---@return string[]|nil 區域名稱或 nil
local function findUnitArea(unit, positions)
  for _, p in pairs(positions) do
    if unit:inArea(p.RL.area) then
      return p.RL.area
    end
  end

  return nil
end


-- 私有輔助函數
---設定單位的移動和武器管制狀態
---@param unit CMO__Unit 單位物件
---@param throttle string 油門設定 (例如 'Flank', 'Stop')
---@param speed number 速度
---@param course CMO__TableOfWaypoints|nil 航線點
---@param holdPosition boolean 是否保持陣位
---@param wcs number|nil 武器管制狀態 (1: Free, 2: Hold)
---@param formation table|nil 編隊設定
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


---命令砲兵營移動至再裝填點 (RL)
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
local function toRL(CONFIG, battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, battery.position.RL.course, false, 2)
  end
end

---命令砲兵營移動至隱蔽區 (HA)
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
local function toHA(CONFIG, battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, battery.position.HA.course, false, 2)
  end
end

---命令彈藥分隊移動至彈藥儲放區 (AHA)
---@param CONFIG SBJ__CONFIG
---@param section SBJ__AmmunitionSection 彈藥分隊物件
---@param group CMO__Unit 單位群組
local function toAHA(CONFIG, section, group)
  section.state = CONFIG.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, section.position.AHA.course, false)
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
---@param CONFIG SBJ__CONFIG
---@param section SBJ__AmmunitionSection 彈藥分隊物件
---@param group CMO__Unit 單位群組
local function ammoSecToRL(CONFIG, section, group)
  section.state = CONFIG.batteryState.REPOSITIONING

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties(unit, 'Flank', 30, section.position.RL.course[#section.position.RL.course], false)
  end
end

---處理砲兵營的自動化重新部署邏輯
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param battery SBJ__Battery
---@param group CMO__Unit
---@param isAuto boolean
local function handleAutomaticBatteryRepositioning(CONFIG, saveData, wpnSystem, side, battery, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = CONFIG[field]['ground'][wpnSystem]

  if battery.state == CONFIG.batteryState.STATIC then
    if Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
      toRL(CONFIG, battery, group)
    end
  end

  if battery.state == CONFIG.batteryState.RELOAD then
    if battery.reloadStartTime == nil then
      battery.reloadStartTime = GameApi.ScenEdit_CurrentTime() - systemConfig.reloadTime
    end

    local elapsedTime = GameApi.ScenEdit_CurrentTime() - battery.reloadStartTime
    local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, group, wpnSystem, isAuto)
    local isMoreThanReloadTime = (
      battery.reloadStartTime ~= nil and
      elapsedTime >= systemConfig.reloadTime and
      result.isMet and
      Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

    if isMoreThanReloadTime then
      Launcher.reload(battery, system.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
      toHA(CONFIG, battery, group)
    end
  end
end

---處理砲兵營的手動再裝填邏輯
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param battery SBJ__Battery
---@param group CMO__Unit
---@param isAuto boolean
local function handleManualBatteryReload(CONFIG, saveData, wpnSystem, side, battery, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = CONFIG[field]['ground'][wpnSystem]

  if battery.reloadStartTime == nil then
    battery.reloadStartTime = GameApi.ScenEdit_CurrentTime() + systemConfig.reloadTime * 100
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - battery.reloadStartTime
  local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, group, wpnSystem, isAuto)
  local isMoreThanReloadTime = (
    battery.reloadStartTime ~= nil and
    elapsedTime >= systemConfig.reloadTime and
    result.isMet and
    Launcher.isLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

  if isMoreThanReloadTime then
    Launcher.reload(battery, system.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)

    if CONFIG.isDevMode then
      GameApi.ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1)
    end
  end
end

---處理彈藥分隊的自動化重新部署邏輯
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param section SBJ__AmmunitionSection
---@param group CMO__Unit
---@param isAuto boolean
local function handleAutomaticSectionRepositioning(CONFIG, saveData, wpnSystem, side, section, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = CONFIG[field]['ground'][wpnSystem]

  if section.state == CONFIG.batteryState.STATIC then
    if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
      toAHA(CONFIG, section, group)
    end
  end

  if section.state == CONFIG.batteryState.RELOAD then
    local elapsedTime = GameApi.ScenEdit_CurrentTime() - section.reloadStartTime
    local result = Launcher.isMetWithAmmo(CONFIG, saveData, group, wpnSystem, isAuto)
    local isMoreThanReloadTime = (
      section.reloadStartTime ~= nil and
      elapsedTime >= systemConfig.reloadTime and
      section.wpnCurrent == 0 and result.isMet)

    if isMoreThanReloadTime then
      transload(section, system.ammunitions[section.ammunition])
      ammoSecToRL(CONFIG, section, group)

      if CONFIG.isDevMode then
        GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
      end
    end
  end
end

---處理彈藥分隊的手動再裝填邏輯
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param section SBJ__AmmunitionSection
---@param group CMO__Unit
---@param isAuto boolean
local function handleManualSectionReload(CONFIG, saveData, wpnSystem, side, section, group, isAuto)
  local field = (side == 'China') and 'c' or 't'
  local system = saveData[field]['ground'][wpnSystem]
  local systemConfig = CONFIG[field]['ground'][wpnSystem]

  if section.reloadStartTime == nil then
    section.reloadStartTime = GameApi.ScenEdit_CurrentTime() + systemConfig.reloadTime * 100
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - section.reloadStartTime
  local result = Launcher.isMetWithAmmo(CONFIG, saveData, group, wpnSystem, isAuto)
  local isMoreThanReloadTime = (
    section.reloadStartTime ~= nil and
    elapsedTime >= systemConfig.reloadTime and
    section.wpnCurrent == 0 and result.isMet)

  if isMoreThanReloadTime then
    transload(section, system.ammunitions[section.ammunition])

    if CONFIG.isDevMode then
      GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
    end
  end
end

---處理所有彈藥分隊的狀態和行動
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
local function processAmmunitionSections(CONFIG, saveData, wpnSystem, side, isAuto)
  local field = (side == 'China') and 'c' or 't'

  for _, section in pairs(saveData[field]['ground'][wpnSystem].ammunitionSections) do
    local group = GameApi.ScenEdit_GetUnit(section.guid)

    if group then
      if isAuto then
        handleAutomaticSectionRepositioning(CONFIG, saveData, wpnSystem, side, section, group,
          isAuto)
      else
        handleManualSectionReload(CONFIG, saveData, wpnSystem, side, section, group, isAuto)
      end
    end
  end
end

---處理所有砲兵營的狀態和行動
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
local function processBatteries(CONFIG, saveData, wpnSystem, side, isAuto)
  local field = (side == 'China') and 'c' or 't'

  for _, battery in pairs(saveData[field]['ground'][wpnSystem].batteries) do
    local group = GameApi.ScenEdit_GetUnit(battery.guid)

    if group then
      if isAuto then
        handleAutomaticBatteryRepositioning(CONFIG, saveData, wpnSystem, side, battery, group, isAuto)
      else
        handleManualBatteryReload(CONFIG, saveData, wpnSystem, side, battery, group, isAuto)
      end
    end
  end
end

-- Public functions

---為砲兵營執行再裝填
---@param battery SBJ__Battery 砲兵營物件
---@param ammunitionSection SBJ__AmmunitionSection 彈藥分隊物件
---@param weaponDBID number 武器資料庫 ID
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

---設定砲兵營的再裝填開始時間
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
---@param isAuto boolean 是否自動重新部署
function Launcher.setReloadStartTime(CONFIG, battery, group, isAuto)
  battery.state = CONFIG.batteryState.RELOAD
  battery.reloadStartTime = GameApi.ScenEdit_CurrentTime()

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u and isAuto then
      setUnitProperties(u, 'Stop', 0, nil, true, nil, { spacing = 0, transpose = true })
    end
  end
end

---設定砲兵營的武器管制狀態為自由開火
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.setWCSToFree(CONFIG, battery, group)
  battery.state = CONFIG.batteryState.STATIC

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties(u, 'Stop', 0, nil, true, 1, { spacing = 0, transpose = true })
    end
  end
end

---設定砲兵營的狀態為隱蔽
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.setStateToHIDE(CONFIG, battery, group)
  battery.state = CONFIG.batteryState.HIDE

  for _, guid in ipairs(group.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties(u, 'Stop', 0, nil, true, 2, { spacing = 0, transpose = true })
    end
  end
end

---檢查單位/群組的彈藥是否低於指定百分比
---@param group CMO__Unit 單位或群組物件
---@param percentage number 百分比閾值
---@param weaponDBID number 武器資料庫 ID
---@return boolean 是否為低彈藥量
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

---命令砲兵營移動至射擊陣地 (FP)
---@param CONFIG SBJ__CONFIG
---@param battery SBJ__Battery 砲兵營物件
---@param group CMO__Unit 單位群組
function Launcher.toFringPosition(CONFIG, battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  local courseIdx = math.random(Utils.getCount(battery.position.FP))

  for _, guid in ipairs(group.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      setUnitProperties(unit, 'Flank', 30, battery.position.FP[courseIdx].course, false)
    end
  end
end

---檢查砲兵營是否已與彈藥車會合
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param wpnSystem string
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__Battery|nil}
function Launcher.isMetWithAmmoTrucks(CONFIG, saveData, unit, wpnSystem, isAuto)
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
  local positions = CONFIG[field]['ground'][wpnSystem].positions

  for _, battery in pairs(system[batteryField]) do
    local isStateValid = true

    if isAuto then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
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

---檢查彈藥分隊是否已與彈藥庫會合
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param wpnSystem string
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__AmmunitionSection|nil}
function Launcher.isMetWithAmmo(CONFIG, saveData, unit, wpnSystem, isAuto)
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'
  if not unit.group then return { isMet = false, battery = nil } end
  local group = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not group then return { isMet = false, battery = nil } end
  local system = saveData[field]['ground'][wpnSystem]
  local positions = CONFIG[field]['ground'][wpnSystem].positions

  for _, section in pairs(system.ammunitionSections) do
    local isStateValid = true

    if isAuto then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
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

---檢查所有砲兵營和彈藥分隊的狀態，並觸發相應的行動
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param wpnSystem string
---@param side string
---@param isAuto boolean
function Launcher.checkBatteryState(CONFIG, saveData, wpnSystem, side, isAuto)
  processBatteries(CONFIG, saveData, wpnSystem, side, isAuto)
  processAmmunitionSections(CONFIG, saveData, wpnSystem, side, isAuto)
end

---處理彈藥分隊單位被摧毀時的邏輯
---@param unit CMO__Unit 被摧毀的單位
---@param side string 陣營
---@param wpnSystem string 平台類型
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
