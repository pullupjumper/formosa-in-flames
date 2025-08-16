-- /src/modules/strikePlanner/airTaskingOrder.lua
-- Air Tasking Order logic with integrated strike package processing.
-- Handles the complete lifecycle of ATO waves and strike packages.

local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local AssignMission = require("src.modules.assignMission")

local AirTaskingOrder = {}

--------------------------------------------------------------------------------
-- Strike Package Processing Functions (integrated from strikePackageProcessor)
--------------------------------------------------------------------------------

--- 計算開始武器掛載的時間
---@param packageData SBJ__Package
---@return number|nil loadoutStartTime timestamp
local function calculateLoadoutStartTime(packageData)
  local earliestStartTime = nil
  local roles = { "striker", "escort", "wildWeasel", "jammer" }

  -- 找出所有機群中最早的出擊時間
  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].startTime then
      local startTimeTimestamp = Utils.parseDatetimeToTimestamp(packageData[role].startTime)
      if not earliestStartTime or startTimeTimestamp < earliestStartTime then
        earliestStartTime = startTimeTimestamp
      end
    end
  end

  if not earliestStartTime then
    return nil
  end

  -- 取得 package 層級的 timeToReady
  local timeToReady = packageData.timeToReady or (9 * 60)
  -- local timeToReadySeconds = timeToReady * 60
  -- local loadoutStartTime = earliestStartTime - timeToReadySeconds
  local loadoutStartTime = earliestStartTime - timeToReady

  return loadoutStartTime
end

--- 檢查是否到達開始武器掛載的時間
---@param packageData SBJ__Package
---@return boolean
local function isTimeToStartLoadout(packageData)
  -- 取得 package 層級的 loadoutStatus
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    Logger.error("loadoutStatus not found in package data")
    return false
  end

  -- 計算開始掛載時間
  if not loadoutStatus.loadoutStartTime then
    loadoutStatus.loadoutStartTime = calculateLoadoutStartTime(packageData)
  end

  if not loadoutStatus.loadoutStartTime then
    return false -- 無法計算開始時間
  end

  -- 將時間戳轉回字串格式供 GameUtils.isAfterStartTime() 使用
  ---@type string
  local loadoutStartTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.loadoutStartTime)
  return GameUtils.isAfterStartTime(loadoutStartTimeStr)
end

--- 為整個 package 的所有機群設定武器掛載
---@param packageData SBJ__Package
local function initiateLoadoutForPackage(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer" }
  local timeToReady = packageData.timeToReady or (9 * 60)

  Logger.log("Starting loadout for package: " .. packageData.striker.missionParams.name)

  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].loadoutID then
      local roleData = packageData[role]
      local loadoutID = roleData.loadoutID
      local unitCount = roleData.unitCount
      local targetUnitDBID = roleData.unitDBID

      -- 如果沒有指定 unitDBID，跳過這個角色
      if not targetUnitDBID then
        Logger.log("No unitDBID specified for role: " .. role .. ", skipping loadout setup")
        goto continue
      end

      -- 獲取基地
      local base = GameApi.ScenEdit_GetUnit(roleData.baseGUID)
      if base and #base.embarkedUnits['Aircraft'] > 0 then
        local unitsProcessed = 0

        -- 只為匹配 unitDBID 的飛機設定 loadout
        for _, unitGUID in ipairs(base.embarkedUnits['Aircraft']) do
          if unitsProcessed >= unitCount then
            break -- 已處理足夠數量的單位
          end

          local unit = GameApi.ScenEdit_GetUnit(unitGUID)
          if unit then
            -- 只處理符合指定 unitDBID 的飛機
            if unit.dbid == targetUnitDBID then
              local result = GameApi.ScenEdit_SetLoadout({
                unitname = unit.name,
                LoadoutID = loadoutID,
                TimeToReady_Minutes = timeToReady / 60
              })

              if result then
                unitsProcessed = unitsProcessed + 1
                Logger.log(string.format(
                  "Setting loadout for %s (DBID:%d, %s %d/%d) with ID %d, ready in %d seconds",
                  unit.name, unit.dbid, role, unitsProcessed, unitCount, loadoutID, timeToReady
                ))
              else
                Logger.error("Failed to set loadout for " .. unit.name)
              end
            end
            -- 如果 unit.dbid != targetUnitDBID，則跳過此單位，不做任何動作
          end
        end

        Logger.log(string.format(
          "Completed loadout setup for %s: %d/%d units processed (target DBID: %d)",
          role, unitsProcessed, unitCount, targetUnitDBID
        ))

        -- 如果沒有找到足夠的符合型號飛機，記錄警告
        if unitsProcessed < unitCount then
          Logger.log(string.format(
            "loging: Only found %d aircraft with DBID %d for %s role, need %d",
            unitsProcessed, targetUnitDBID, role, unitCount
          ))
        end
      end

      ::continue::
    end
  end

  -- 更新狀態 - 使用現有時間函數
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local loadoutStatus = packageData.loadoutStatus
  loadoutStatus.isLoadoutInitiated = true
  loadoutStatus.loadoutInitiatedTime = currentTime
  loadoutStatus.expectedReadyTime = currentTime + timeToReady

  local expectedReadyTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.expectedReadyTime)
  Logger.log("All loadouts initiated, expected ready at: " .. expectedReadyTimeStr)
end

--- 檢查武器掛載是否完成
---@param packageData SBJ__Package
---@return boolean
local function isLoadoutReady(packageData)
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    Logger.error("loadoutStatus not found in package data")
    return false
  end

  -- 如果 loadout 已準備完成
  if loadoutStatus.isLoadoutInitiated and loadoutStatus.expectedReadyTime then
    ---@type string
    local expectedReadyTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.expectedReadyTime)
    return GameUtils.isAfterStartTime(expectedReadyTimeStr)
  end

  -- 如果尚未開始 loadout 程序，現在開始
  if not loadoutStatus.isLoadoutInitiated then
    initiateLoadoutForPackage(packageData)
    return false -- 第一次設定，需要等待
  end

  -- 正在等待中
  return false
end

--- 找出最早出擊的機群
---@param packageData SBJ__Package
---@return table|nil earliestRole
local function findEarliestRole(packageData)
  local earliestRole = nil
  local earliestTime = nil
  local roles = { "striker", "escort", "wildWeasel", "jammer" }

  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].startTime then
      local startTime = Utils.parseDatetimeToTimestamp(packageData[role].startTime)
      if not earliestTime or startTime < earliestTime then
        earliestTime = startTime
        earliestRole = packageData[role]
      end
    end
  end

  return earliestRole
end

--- Creates a mission for a specific role if it doesn't exist.
---@param packageData SBJ__Package
---@param role string
---@return boolean
local function createMission(packageData, role)
  local mission = GameApi.ScenEdit_GetMission("China", packageData[role].missionParams.name)

  if not mission then
    Logger.log("Mission not found, creating: " .. packageData[role].missionParams.name)

    mission = GameUtils.createMission(
      "China",
      packageData[role].missionParams.name,
      packageData[role].missionParams.type,
      packageData[role].missionParams.opts,
      packageData[role].emcon
    )

    if mission and packageData[role].endTime then
      mission['OnDeactivateDelete'] = true
      mission['OnDeactivateRTB'] = true
      mission['TakeOffTime'] = packageData[role].startTime
      mission['endtime'] = packageData[role].endTime
    end
  end

  return mission ~= nil
end

--- Assigns all units in the package to their respective missions.
---@param packageData SBJ__Package
---@return boolean Returns true if the primary striker units were assigned.
local function assignUnits(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
  local strikerAssigned = false

  for _, role in ipairs(roles) do
    if packageData[role] then
      local result = AssignMission.assignEmbarkedUnitToStrikeMission(
        packageData[role].baseGUID,
        packageData[role].unitCount,
        packageData[role].weaponDBID,
        packageData[role].unitDBID, -- Handles jammer case where weaponDBID is 0
        packageData[role].missionParams.name,
        false
      )
      if role == "striker" and result and #result > 0 then
        strikerAssigned = true
      end
    end
  end

  return strikerAssigned
end

--- Processes a single strike package through its complete lifecycle
---@param packageData SBJ__Package The pure data table from saveData
---@return boolean hasLaunched
local function processPackage(packageData)
  -- 1. 檢查是否到達武器掛載開始時間
  if not isTimeToStartLoadout(packageData) then
    return false -- 還沒到開始掛載的時間
  end

  -- 2. 檢查武器掛載是否完成
  if not isLoadoutReady(packageData) then
    return false -- 正在掛載武器或等待完成
  end

  -- 3. 檢查最早機群是否到達出擊時間
  local earliestRole = findEarliestRole(packageData)
  if not (earliestRole and GameUtils.isAfterStartTime(earliestRole.startTime)) then
    return false -- 最早機群還沒到出擊時間
  end

  -- 4. 建立所有任務 - 攻擊任務是關鍵
  local roles = { "tanker", "striker", "escort", "wildWeasel", "jammer", }

  for _, role in ipairs(roles) do
    if packageData[role] then
      local missionCreated = createMission(packageData, role)

      if role == 'striker' and not missionCreated then
        Logger.error("Critical failure: Could not create striker mission. Aborting package.")
        return false -- 如果主要任務建立失敗，中止整個流程
      end
    end
  end

  Logger.log("All missions for package " .. packageData.striker.missionParams.name .. " created or verified.")

  -- 5. 尋找目標
  -- local evaluatedTargetlist = findTargets(packageData, config, saveData, contacts, isFirstWave)
  local evaluatedTargetlist = packageData.target.list
  Logger.log(packageData.striker.missionParams.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < packageData.target.minTargetCount then
    Logger.log("Not enough targets found for " ..
      packageData.striker.missionParams.name .. ". Need " .. packageData.target.minTargetCount)
    return false
  end

  -- 6. 將目標分配給攻擊任務
  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    evaluatedTargetlist,
    packageData.striker.missionParams.name
  )

  if not targetsAssigned then
    return false
  end

  Logger.log("Targets assigned to mission " .. packageData.striker.missionParams.name)

  -- 7. 將單位分配給所有任務
  if assignUnits(packageData) then
    Logger.log(packageData.striker.missionParams.name ..
      " status -> LAUNCHED. All loadouts ready, package has been launched.")
    return true -- 成功
  else
    Logger.error(packageData.striker.missionParams.name .. " failed to assign striker units.")
    return false
  end
end

--------------------------------------------------------------------------------
-- Wave Management Functions
--------------------------------------------------------------------------------

--- Checks if all packages in a wave have been launched.
---@param waveData table
---@return boolean
local function isWaveFinished(waveData)
  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      return false -- At least one package has not been launched
    end
  end
  return true
end

--- The main entry point for air strikes.
--- It iterates through waves and packages, handing off the processing to the processor.
---@param saveData SBJ__SaveData
function AirTaskingOrder.airStrike(saveData)
  if not saveData or not saveData.c or not saveData.c.air or not saveData.c.air.ATO then
    -- Guard against missing data
    return
  end

  for _, waveData in pairs(saveData.c.air.ATO) do
    if waveData.isActivated and not waveData.hasLaunched then
      for _, packageData in ipairs(waveData.packages) do
        if not packageData.hasLaunched then
          -- Process the entire sequence for a package in one go.
          -- Returns true if the package was successfully launched.
          local launched = processPackage(packageData)
          if launched then
            packageData.hasLaunched = true
            -- As per original logic, break after one successful launch to process
            -- the next package in the next 5-minute tick.
            break
          end
        end
      end

      -- After processing, check if the entire wave is now finished.
      if isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end
end

return AirTaskingOrder
