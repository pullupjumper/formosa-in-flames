# Landing Operations Per-Zone 狀態機重構計畫

## 目標

將 Landing Operations 的全域統一狀態機改為 per-zone 獨立狀態機，讓不同作戰區域（如 Taoyuan、Sishu）各自獨立推進階段，互不阻塞。

---

## 現狀問題

目前 `saveData.c.amphibOps` 使用扁平的 boolean flag 控制所有 zone 的統一流程：

```
isShipsStartedMoving → isWaitingForShipArrival → isWaitingForAmphibiousAssault → isWaitingForSecondWaveUnloading
```

- 所有 zone 必須同步推進，一個 zone 未完成會阻塞其他 zone
- `landingCheck.lua` 中有硬編碼值（`> 15`、`operations[1]`、`result["Taoyuan"]`）
- 多個互斥 boolean 容易出現不合法狀態組合

---

## 設計方案

### 1. Phase Enum — `constants.lua`

在 `constants.lua` 新增 phase enum，避免散落的魔法字串：

```lua
constants.AMPHIBIOUS_PHASES = {
  MOVING              = "MOVING",
  WAITING_ARRIVAL     = "WAITING_ARRIVAL",
  WAITING_ASSAULT     = "WAITING_ASSAULT",
  WAITING_SECOND_WAVE = "WAITING_SECOND_WAVE",
  COMPLETED           = "COMPLETED",
}
```

#### Phase 狀態流轉

```
MOVING → WAITING_ARRIVAL → WAITING_ASSAULT → WAITING_SECOND_WAVE → COMPLETED
```

### 2. 資料結構變更 — `saveData.lua`

刪除 5 個扁平 flag，改為 `zoneStates` table，以 zone name 為 key，使用 phase enum：

```lua
-- 刪除
saveData.c.amphibOps.isShipsStartedMoving = true
saveData.c.amphibOps.isWaitingForShipArrival = false
saveData.c.amphibOps.isWaitingForAmphibiousAssault = false
saveData.c.amphibOps.isWaitingForSecondWaveUnloading = false
saveData.c.amphibOps.amphibiousAssaultStartTime = nil
saveData.c.amphibOps.airlandingMissionStartTime = nil

-- 新增
saveData.c.amphibOps.zoneStates = {}
for _, zone in ipairs(config.c.amphibOps.operationalZones) do
  saveData.c.amphibOps.zoneStates[zone.name] = {
    phase = constants.AMPHIBIOUS_PHASES.MOVING,
    amphibiousAssaultStartTime = nil,
    airlandingMissionStartTime = nil,
  }
end

-- 保持不變
saveData.c.amphibOps.startTime = config.c.triggers.amphibiousOps.startTime
saveData.c.amphibOps.isTesting = true
saveData.c.amphibOps.calculationResult = {}
saveData.c.amphibOps.barges = {}
```

### 3. 設定變更 — `config.lua`

將原本硬編碼在 `landingCheck.lua` 的判斷值移至各 zone 的設定：

| 新增欄位 | 位置 | 說明 | 原本硬編碼值 |
|---|---|---|---|
| `arrivalThreshold` | `operationalZones[].arrivalThreshold` | 到達錨泊區的最低艦船數 | `15`（全域） |
| `sagNames` | `operations[].sagNames` | 該作戰區對應的 SAG 群組名稱清單 | 無（全域遍歷 `sag`） |

`airLandingZone` 和 `numOfContactsInAirLandingZone` 已在 `operations` 中以 per-zone 存在。

#### SAG 對應關係

| Operation | sagNames |
|---|---|
| Taoyuan | `{ "SAG 173", "SAG 155" }` |
| Sishu | `{ "SAG 154", "SAG 175" }` |
| Penghu | `{ "SAG 167" }` |

```lua
-- operations 範例
{
  name = "Taoyuan",
  sagNames = { "SAG 173", "SAG 155" },
  ...
}
```

SAG 詳細描述符維持在 `config.c.amphibOps.sag` 作為 lookup table，各模組依 `sagNames` 查找。

### 4. 驅動層重寫 — `landingCheck.lua`

新增 local helper 函數 `findOperationByName`，並改寫為 per-zone 迴圈 + phase enum 驅動：

```lua
local amphibOpsConfig = config.c.amphibOps

---@param operations SBJ__AmphibiousOperationDescriptor[]
---@param name string
---@return SBJ__AmphibiousOperationDescriptor|nil
local function findOperationByName(operations, name)
  for _, op in ipairs(operations) do
    if op.name == name then return op end
  end
  return nil
end

for _, zone in ipairs(amphibOpsConfig.operationalZones) do
  local zoneState = saveData.c.amphibOps.zoneStates[zone.name]
  local operation = findOperationByName(amphibOpsConfig.operations, zone.name)

  -- Phase 1: 艦隊移動
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.MOVING
      and GameUtils.isAfterStartTime(saveData.c.amphibOps.startTime) then
    local done = ShipMovement.moveToStagingArea(amphibOpsConfig, saveData, filteredShips, operation)
    if done then
      zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
    end
  end

  -- Phase 2: 等待到達 + 後勤裝載
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL then
    local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredShips)
    local hasArrived = Utils.getCount(result.units) > zone.arrivalThreshold
        and not result.isUnitMoving

    if hasArrived then
      local ok = AmphibiousLogistics.createCargoMissions(zone)
          and AmphibiousLogistics.transferAndAssign(zone, result.units)
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT
        zoneState.amphibiousAssaultStartTime = currentTime

        -- GJ-11 偵察任務：暫時只對 Taoyuan 執行
        if zone.name == "Taoyuan" then
          local entry = Utils.deepCopy(config.c.recon.template.GJ11_RECON)
          ---@cast entry SBJ__ReconQueueEntry
          local _, flightTime = GameUtils.calculatePathDistanceAndTime(entry.course, entry.speed)
          local endTime = currentTime + flightTime
          entry.takeoffTime = os.date("%Y-%m-%d %H:%M:%S", currentTime)
          entry.endTime = os.date("%Y-%m-%d %H:%M:%S", endTime)
          entry.hasLaunched = false
          entry.isFinished = false
          entry.trackingTargetGUID = nil
          table.insert(saveData.c.recon.queue, entry)
        end
      end
    end
  end

  -- Phase 3: 兩棲突擊
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT then
    local contactCount = AmphibiousAssault.countContactsInArea(
      contacts, operation.airLandingZone
    )
    local elapsed = currentTime - (zoneState.amphibiousAssaultStartTime or currentTime)
    local shouldLaunch = contactCount < operation.numOfContactsInAirLandingZone
        or elapsed >= amphibOpsConfig.periodOfTime

    if shouldLaunch then
      local ok = AmphibiousAssault.setLandingMissionStartTime(zone, saveData, zoneState)
          and AmphibiousAssault.setCoursesForLSTs(zone, filteredShips, operation, amphibOpsConfig.sag)
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE
      end
    end
  end

  -- Phase 4: 第二波卸載
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE then
    local result = UnitStatusUI.countUnitsInEachArea(config)
    local hasBeachhead = result[zone.name] and result[zone.name]["ZBD-05"] >= 1

    if hasBeachhead then
      local ok = SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, filteredShips
      )
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.COMPLETED
      end
    end
  end
end

-- 貨物重新裝載（保持獨立，遍歷所有 zone）
for _, zone in ipairs(amphibOpsConfig.operationalZones) do
  local zoneState = saveData.c.amphibOps.zoneStates[zone.name]
  if zoneState.airlandingMissionStartTime ~= nil then
    local elapsed = currentTime - zoneState.airlandingMissionStartTime
    if elapsed >= (3600 * 2) then
      local ok = AmphibiousLogistics.retransferCargos(zone, filteredShips)
      if ok then
        zoneState.airlandingMissionStartTime = currentTime
      end
    end
  end
end
```

### 5. 模組函數簽名變更

核心原則：**zone 迴圈由 `landingCheck.lua` 驅動，模組只處理單一 zone**。

#### amphibiousLogistics.lua

| 函數 | 之前參數 | 之後參數 |
|---|---|---|
| `getUnitsInAnchorageArea` | `(amphibOpsConfig, filteredUnits)` | `(zone, filteredUnits)` |
| `createCargoMissions` | `(amphibOpsConfig)` | `(zone)` |
| `transferAndAssign` | `(amphibOpsConfig, units)` | `(zone, units)` |
| `retransferCargos` | `(amphibOpsConfig, units)` | `(zone, units)` |

移除函數內部的 `for _, zone in ipairs(operationalZones)` 迴圈。

#### amphibiousAssault.lua

| 函數 | 之前參數 | 之後參數 |
|---|---|---|
| `setLandingMissionStartTime` | `(amphibOpsConfig, saveData)` | `(zone, saveData, zoneState)` |
| `setCoursesForLSTs` | `(amphibOpsConfig, units)` | `(zone, units, operation, sagLookup)` |

- `setLandingMissionStartTime`：`airlandingMissionStartTime` 寫入 `zoneState` 而非 `saveData.c.amphibOps`
- `setCoursesForLSTs`：只處理該 zone 的 `lstAnchorageArea` 內的 LST；依 `operation.sagNames` 從 `sagLookup` 查找對應 SAG 並設定航向

#### shipMovement.lua

| 函數 | 之前參數 | 之後參數 |
|---|---|---|
| `moveToStagingArea` | `(amphibOpsConfig, saveData, filteredUnits)` | `(amphibOpsConfig, saveData, filteredUnits, operation)` |

- 新增 `operation` 參數，只處理該 operation 的 `stagingArea` 內的艦船
- 依 `operation.sagNames` 從 `amphibOpsConfig.sag` 查找對應 SAG 並處理移動
- `calculateDestination` 保持不變（一次預算所有位置）

#### secondWaveUnloading.lua

| 函數 | 之前參數 | 之後參數 |
|---|---|---|
| `startSecondWaveUnloading` | `(amphibOpsConfig, saveData, filteredUnits)` | `(zone, saveData, filteredUnits)` |

移除內部 zone 迴圈。

### 6. SAG 處理

SAG 護航編隊改為 per-zone，依各 zone 的階段執行：

- `operations` 中新增 `sagNames` 欄位，建立 SAG 與 zone 的對應
- **Phase 1**（`shipMovement.moveToStagingArea`）：依 `operation.sagNames` 只處理該 zone 的 SAG，移動至錨泊區
- **Phase 3**（`amphibiousAssault.setCoursesForLSTs`）：接收 `operation` 和 `sagLookup`，依 `operation.sagNames` 查找 SAG 並設定前往兩棲載具集結區的航向
- SAG 詳細描述符維持在 `config.c.amphibOps.sag` 作為 lookup table

### 7. 測試更新

所有 `test/modules/landingOps/` 下的 spec 檔案需配合新簽名更新。

---

## 變更檔案清單

| 檔案 | 變動範圍 |
|---|---|
| `src/core/constants.lua` | 新增 `AMPHIBIOUS_PHASES` enum |
| `src/core/saveData.lua` | 刪除扁平 flag，新增 `zoneStates` 初始化迴圈 |
| `src/core/config.lua` | operations 加上 `sagNames`；operationalZones 加上 `arrivalThreshold` |
| `src/scripts/china/amphibiousOps/landingCheck.lua` | 新增 `findOperationByName` local function，全面改寫為 per-zone 狀態機 |
| `src/modules/landingOps/amphibiousLogistics.lua` | 4 個公開函數改簽名，移除內部 zone 迴圈 |
| `src/modules/landingOps/amphibiousAssault.lua` | `setCoursesForLSTs` 改簽名（含 operation + sagLookup），移除內部 zone/SAG 迴圈 |
| `src/modules/landingOps/shipMovement.lua` | `moveToStagingArea` 新增 `operation` 參數，SAG 依 `sagNames` 過濾 |
| `src/modules/landingOps/secondWaveUnloading.lua` | `startSecondWaveUnloading` 改簽名 |
| `test/modules/landingOps/*_spec.lua` | 配合新簽名更新 |
