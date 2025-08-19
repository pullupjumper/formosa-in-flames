# Design Document

## Overview

本設計文件描述了增強火力支援計畫系統的技術架構和實作方案。該系統將在現有的 `fireSupportPlan.lua` 基礎上，新增基於偵察結果的動態 FSEM 創建功能。

系統的核心流程是：在指定時間點自動執行目標評估，根據 BDA 結果決定是否需要補充打擊，並在必要時動態創建新的 FSEM 插入到現有的 FSP 序列中。

## Architecture

### 執行流程圖

```
偵察時程觸發 → 處理FSEM模板 → 逐一處理FST → BDA評估 → 數量判斷 → FSEM創建 → FSP整合
      │              │             │         │        │         │         │
      │              │             │         │        │         │         └─→ 更新時程表
      │              │             │         │        │         └─→ 分配火力單位和武器
      │              │             │         │        └─→ 檢查各FST目標數量閾值
      │              │             │         └─→ 篩選需要打擊的目標
      │              │             └─→ 根據FST模板進行目標篩選
      │              └─→ 從偵察時程表獲取FSEM模板
      └─→ 衛星/偵察機完成偵察後觸發（含延遲）
```

### 模組結構

## 模組結構更新

```lua
-- 實際的模組結構（最終實現版本）
local DynamicFireSupportPlan = {
  execute = function(config, saveData, contacts),  -- 唯一公開函式
  
  -- 所有內部函式現在都是私有的 (local function)
  -- processReconSchedule = function(...), -- 偵察時程處理 (私有)
  -- createFSEMFromTemplate = function(...), -- 從模板創建 FSEM (私有)
  -- processFST = function(...),           -- 處理單個 FST (私有)
  -- collectAssignedBatteries = function(...), -- 收集已分配的火力單位 (私有)
  -- validateBatteryStatus = function(...),    -- 驗證火力單位狀態 (私有)
  -- checkBatteryAvailability = function(...), -- 檢查火力單位可用性 (私有)
  -- insertFSEM = function(...),              -- FSP 整合功能 (私有)
}

-- 注意：只有 execute 函式是公開 API，其他函式為內部實現細節
```

## 測試架構設計

由於模組採用了嚴格的封裝設計（只有一個公開函式），測試策略調整為：

### 公開 API 測試
- **測試對象**：`DynamicFireSupportPlan.execute(config, saveData, contacts)`
- **測試方法**：通過不同輸入場景間接測試內部邏輯
- **測試覆蓋**：正常流程、錯誤處理、邊界條件

### 測試場景設計
1. **正常執行流程**：完整的偵察時程處理和 FSEM 創建
2. **功能開關測試**：`dynamicFSP.enabled = false`
3. **時間觸發測試**：偵察時間未到達的情況
4. **目標不足測試**：`minTargetCount > 實際目標數量`
5. **資源缺失測試**：電池配置為空
6. **配置錯誤測試**：缺失必要配置項目
7. **空時程表測試**：`reconSchedule = {}`
8. **集成測試**：驗證完整 FSEM 創建和插入流程

## Components and Interfaces

### 核心函式介面

### 核心函式介面（更新）

```lua
-- 主要執行函式
function DynamicFireSupportPlan.execute(config, saveData, contacts)
  -- config: 配置參數，包含偵察時程表
  -- saveData: 遊戲狀態資料
  -- contacts: 從事件腳本傳入的 GameApi.ScenEdit_GetContacts('China') 結果
  -- 處理整個偵察時程表，檢查所有項目是否到達執行時間
end

-- 重構後的輔助函式
function collectAssignedBatteries(saveData)
  -- 收集當前所有已分配的battery GUID
  -- 返回: table<string, boolean> assignedBatteries
end

function validateBatteryStatus(config, saveData, batteryGuid, wpnSystem)
  -- 驗證單個battery的狀態和可用性
  -- 返回: boolean isValid, string|nil reason
end

function checkBatteryAvailability(config, saveData, templateBatteries, wpnSystem)
  -- 檢查模板中指定的batteries是否可用（重構版本）
  -- 使用上述兩個輔助函式，提升可讀性和可維護性
end

function processFST(config, saveData, contacts, fstTemplate, isFirstWave)
  -- 處理單個 FST 模板，進行目標篩選和 BDA 評估
  -- 支援動態目標過濾和固定目標清單兩種模式
  -- contacts: 從主函式傳入的聯絡人資料
  -- isFirstWave: 是否為第一波攻擊（影響 BDA 評估方式）
end

function createFSEMFromTemplate(config, saveData, fsemTemplate, evaluatedTargets)
  -- 從模板和評估結果創建實際的 FSEM
  -- 整合battery可用性檢查和時間計算
end
```

### 資料結構（更新版本）

```lua
-- 偵察時程表項目結構
---@class ReconScheduleEntry
local reconEntry = {
  time = "2027-06-09 14:30:00",
  type = "satellite", -- "satellite" or "aircraft"
  delay = 300,        -- Trigger assessment after X seconds
  executed = false,   -- Execution status flag
  fsemTemplate = {
    name = "DYNAMIC/SATELLITE/BDA/1",
    strikeInterval = 600, -- Interval between FSTs in seconds
    isFirstWave = false,  -- Whether this is first wave attack (affects BDA assessment)
    FSTs = { ... } -- FST 模板陣列
  }
}

-- FST 模板結構（配置中的模板，不包含運行時欄位）
---@class FSTTemplate
local fstTemplate = {
  name = "Airfield runway facilities strike", -- 英文化後的名稱
  wpnSystem = "SRBM", -- 注意：使用 wpnSystem 而非 weaponSystem
  batteries = { -- 預定義的battery配置
    {
      name = '636th Bde',
      guid = 'IC8B0X-0HN822OHANPB3',
      weaponDBID = config.weapon.DF16A
    },
    {
      name = '617th Bde', 
      guid = 'IC8B0X-0HN822OHANRHI',
      weaponDBID = config.weapon.DF16A
    }
  },
  target = {
    list = {},         -- 模板中為空，運行時填充
    evaluatedlist = {}, -- 模板中為空，運行時填充
    objs = {
      { baseName = "Jiashan AB",          subTypes = { "Runway %(%d+m%)", "Taxiway" } },
      { baseName = "Taitung/Jhihhang AB", subTypes = { "Runway %(%d+m%)", "Taxiway" } },
      { baseName = "Hualien AB",          subTypes = { "Runway %(%d+m%)", "Taxiway" } }
    },
    areas = {}, -- 可選的區域篩選
    filterNames = nil, -- 動態目標篩選函式名稱（nil表示使用objs）
    contactAge = config.c.ground.srbm.contactAge, -- 從config獲取
    minTargetCount = 3, -- 最小目標數量閾值
    ammoPerTarget = 4   -- 每個目標的彈藥數量
  }
  -- 注意：FST模板不包含 startTime 和 isFinished，這些是運行時添加的
}

-- 實際執行的FST結構（運行時從模板創建）
---@class ExecutedFST
local executedFST = {
  name = "Airfield runway facilities strike", -- 從模板複製
  wpnSystem = "SRBM",                        -- 從模板複製
  batteries = { ... },                       -- 從模板經過可用性檢查後的結果
  startTime = "2027-06-09 01:05:00",         -- 運行時計算：fsemStartTime + (fstIndex * strikeInterval)
  isFinished = false,                        -- 運行時初始化為false
  target = {
    list = { ... },         -- 運行時評估後的目標清單
    evaluatedlist = { ... }, -- 同list，運行時填充
    objs = { ... },         -- 從模板複製
    areas = { ... },        -- 從模板複製
    filterNames = nil,      -- 從模板複製
    contactAge = 3600,      -- 從模板複製
    minTargetCount = 3,     -- 從模板複製
    ammoPerTarget = 4       -- 從模板複製
  }
}

-- Battery 結構
---@class BatteryTemplate
local batteryTemplate = {
  name = '636th Bde',     -- 顯示名稱
  guid = 'IC8B0X-0HN822OHANPB3', -- 遊戲中的唯一ID
  weaponDBID = 'dynamically_resolved' -- 從 saveData 中解析，例如：config.weapon.DF15B
}
```
```

## Data Models

### 現有資料結構整合

系統將整合到現有的 `saveData.c.ground.FSP` 結構中：

```lua
-- 在現有 FSP 中新增動態 FSEM
saveData.c.ground.FSP["DYNAMIC/BDA/FOLLOWUP"] = dynamicFSEM
```

### 偵察時程表和 FSEM 模板（實際配置）

```lua
-- 在 saveData.lua 中的實際配置結構
saveData.c.ground.dynamicFSP.enabled = true
saveData.c.ground.dynamicFSP.reconSchedule = {
  {
    time = "2027-06-09 14:30:00",
    type = "satellite", -- Large-scale reconnaissance (satellite)
    delay = 300,        -- Trigger assessment after 5 minutes
    executed = false,   -- Execution status flag
    fsemTemplate = {
      name = "DYNAMIC/SATELLITE/BDA/1",
      strikeInterval = 600, -- 10-minute interval
      isFirstWave = false,  -- BDA follow-up strike, not first wave
      FSTs = {
        {
          name = "Airfield runway facilities strike",
          wpnSystem = "SRBM",
          batteries = {
            {
              name = '636th Bde',
              guid = 'IC8B0X-0HN822OHANPB3',
              weaponDBID = config.weapon.DF16A
            },
            {
              name = '617th Bde',
              guid = 'IC8B0X-0HN822OHANRHI',
              weaponDBID = config.weapon.DF16A
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {
              { baseName = "Jiashan AB",          subTypes = { "Runway %(%d+m%)", "Taxiway" } },
              { baseName = "Taitung/Jhihhang AB", subTypes = { "Runway %(%d+m%)", "Taxiway" } },
              { baseName = "Hualien AB",          subTypes = { "Runway %(%d+m%)", "Taxiway" } }
            },
            areas = {},
            filterNames = nil,
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 3,
            ammoPerTarget = 4
          }
        },
        {
          name = "Airfield shelter facilities strike",
          wpnSystem = "SRBM",
          batteries = {
            {
              name = '616th Bde',
              guid = 'X58F5H-0HN1G2IFLF6QE',
              weaponDBID = config.weapon.DF15C
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {
              { baseName = "Jiashan AB",          subTypes = { "Shelter", "Tarmac", "Hangar" } },
              { baseName = "Taitung/Jhihhang AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
              { baseName = "Hualien AB",          subTypes = { "Shelter", "Tarmac", "Hangar" } }
            },
            areas = {},
            filterNames = nil,
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 2,
            ammoPerTarget = 2
          }
        }
      }
    }
  },
  {
    time = "2027-06-09 16:00:00",
    type = "aircraft", -- Small-scale reconnaissance (reconnaissance aircraft)
    delay = 180,       -- Trigger assessment after 3 minutes
    executed = false,
    fsemTemplate = {
      name = "DYNAMIC/UAV/BDA/1",
      strikeInterval = 300, -- 5-minute interval
      isFirstWave = false,  -- BDA follow-up strike, not first wave
      FSTs = {
        {
          name = "Air defense radar system strike",
          wpnSystem = "SRBM",
          batteries = {
            {
              name = '614th Bde',
              guid = 'X58F5H-0HN1LQGRV8HNQ',
              weaponDBID = config.weapon.DF11A
            },
            {
              name = '613rd Bde',
              guid = 'X58F5H-0HN1G2DEBC7O8',
              weaponDBID = config.weapon.DF15B
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {
              { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } }
            },
            areas = { config.c.areas["OPAREA/SOUTH"] },
            filterNames = { "analyzeEmissions" },
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 3
          }
        }
      }
    }
  },
  {
    time = "2027-06-09 01:00:00",
    type = "satellite",
    delay = 300,
    executed = false,
    fsemTemplate = {
      name = "DYNAMIC/SATELLITE/BDA/2",
      strikeInterval = 0, -- No interval between FSTs
      isFirstWave = false,  -- BDA follow-up strike, not first wave
      FSTs = {
        {
          name = "Naval target strike",
          wpnSystem = "MRBM",
          batteries = {
            {
              name = '624th Bde',
              guid = 'IC8B0X-0HNCOR6HG2JE1',
              weaponDBID = config.weapon.DF21D
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {},
            areas = { config.c.areas["OPAREA/PACIFIC"] },
            filterNames = { "findNavalTargets" },
            contactAge = config.c.ground.mrbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 6
          }
        }
      }
    }
  }
}
```

## 代碼品質改進

### 模組重構亮點

1. **函式職責分離**：原本的 `checkBatteryAvailability` 函式過長，已拆分為三個更小的函式：
   - `collectAssignedBatteries`: 專門收集已分配的battery資訊
   - `validateBatteryStatus`: 驗證單個battery的狀態
   - `checkBatteryAvailability`: 協調整個檢查流程

2. **錯誤處理優化**：
   - 使用 `validateBatteryStatus` 返回詳細錯誤原因
   - 區分不同類型錯誤（Logger.error vs Logger.log）
   - 提供更好的調試信息

3. **可讀性提升**：
   - 每個函式都有明確的單一職責
   - 完整的英文註釋和日志消息
   - 清晰的函式命名和參數註解

4. **可維護性增強**：
   - 函式可獨立測試和重用
   - 邏輯模組化，便於修改和擴展
   - 符合單一職責原則

### 國際化改進

- 所有中文註釋已轉換為英文
- Logger輸出消息全部英文化
- saveData中的動態FSP配置註釋更新為英文
- 保持代碼的國際化標準

### 錯誤處理策略

由於遊戲 API 已透過 `GameApi` 模組封裝並使用代理模式統一捕捉錯誤，因此主要專注於業務邏輯的驗證：

1. **目標篩選結果驗證**
   ```lua
   if not targetList or #targetList == 0 then
     Logger.log("No targets found for BDA evaluation")
     return false
   end
   ```

2. **BDA 評估結果驗證**
   ```lua
   -- 根據目標類型選擇評估方式，GameApi 會處理 API 異常
   local strikeTargets = {}
   
   if fstTemplate.target.filterNames then
     -- 動態目標使用傳入的 contacts 進行篩選
     if not contacts or #contacts == 0 then
       Logger.log("No contacts available for dynamic target filtering")
       return false
     end
     -- 使用相應的篩選函式處理
   else
     -- 固定目標使用 assessTargetsDamage
     local task = {
       target = {
         list = filteredTargets,
         contactAge = 30 * 60
       }
     }
     strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
   end
   ```

3. **FSEM 創建結果驗證**
   ```lua
   if not newFSEM or not newFSEM.FSTs or #newFSEM.FSTs == 0 then
     Logger.error("Failed to create valid FSEM")
     return false
   end
   ```

4. **資源可用性檢查**
   ```lua
   -- 檢查火力單位可用性，以 FSP 中的 FSEM 為基準
   local function checkBatteryAvailability(config, saveData, wpnSystem, requiredCount)
     local availableBatteries = {}
     local batteries = saveData.c.ground[string.lower(wpnSystem)].batteries
     
     -- 收集所有已被分配但尚未執行的火力單位
     local assignedBatteries = {}
     for _, FSEM in pairs(saveData.c.ground.FSP) do
       if not FSEM.isFinished and FSEM.isActivated then
         for _, FST in ipairs(FSEM.FSTs) do
           if not FST.isFinished and FST.batteries then
             for _, batteryGuid in ipairs(FST.batteries) do
               assignedBatteries[batteryGuid] = true
             end
           end
         end
       end
     end
     
     -- 篩選可用的火力單位（未被分配且狀態良好）
     for guid, battery in pairs(batteries) do
       local actualUnit = GameApi.ScenEdit_GetUnit(guid)
       local isNotAssigned = not assignedBatteries[guid]
       local isInGoodState = actualUnit and battery.state == config.batteryState.HIDE
       local hasAmmo = not Launcher.isLowAmmo(actualUnit, battery.ammoThreshold, battery.weaponDBID)
       
       if isNotAssigned and isInGoodState and hasAmmo then
         table.insert(availableBatteries, { guid = guid, battery = battery })
       end
     end
     
     return availableBatteries
   end
   
   local availableBatteries = checkBatteryAvailability(config, saveData, "mlrs", 2)
   if #availableBatteries < 2 then
     Logger.log("Insufficient batteries available, skipping FSEM creation")
     return false
   end
   ```

## Testing Strategy

### 單元測試

1. **目標篩選測試**
   - 測試不同基地名稱和設施類型的篩選
   - 驗證空目標清單的處理

2. **BDA 評估測試**
   - 模擬不同損毀狀態的目標
   - 測試偵察時間點的判斷邏輯

3. **FSEM 創建測試**
   - 驗證 FSEM 結構的正確性
   - 測試火力單位分配邏輯

4. **FSP 整合測試**
   - 測試 FSEM 插入到現有序列
   - 驗證時程更新的正確性

### 整合測試

1. **完整流程測試**
   - 從定時觸發到 FSEM 插入的完整流程
   - 測試多次執行的穩定性

2. **錯誤情境測試**
   - 模擬各種異常情況
   - 驗證錯誤恢復機制

### 效能測試

1. **大量目標處理**
   - 測試處理大量目標時的效能
   - 驗證記憶體使用情況

2. **並發執行測試**
   - 測試與現有 FSP 系統的並發執行
   - 驗證資源競爭的處理

## Implementation Notes

### 現有函式整合

1. **目標篩選函式**
   ```lua
   -- 利用現有的 TargetingProcess.selectTargetsByQueryParams
   local filteredTargets = TargetingProcess.selectTargetsByQueryParams({
     targetlist = saveData.c.targetlist,
     queryParams = {
       { baseName = "佳山基地", subTypes = { "跑道", "滑行道" } },
       { baseName = "志航基地", subTypes = { "跑道", "滑行道", "彈藥庫" } }
     }
   })
   ```

2. **BDA 評估函式**
   ```lua
   -- 根據目標類型選擇不同的評估方式
   local strikeTargets = {}
   
   if fstTemplate.target.filterNames then
     -- 對於需要動態過濾的目標（如雷達、防空系統），使用傳入的 contacts
     local filterOpts = {
       contacts = contacts,
       task = {
         target = {
           areas = fstTemplate.target.areas,
           contactAge = fstTemplate.target.contactAge
         }
       },
       config = config,
       saveData = saveData
     }
     
     -- 直接呼叫 TargetingProcess 中對應的函式
     for _, filterName in ipairs(fstTemplate.target.filterNames) do
       local targetingFunction = TargetingProcess[filterName]
       if targetingFunction then
         local targets = targetingFunction(filterOpts)
         if targets and #targets > 0 then
           Utils.insertList(strikeTargets, targets)
         end
       else
         Logger.error("Unknown targeting function: " .. filterName)
       end
     end
   else
     -- 對於固定目標清單，使用 assessTargetsDamage
     local task = {
       target = {
         list = filteredTargets,
         contactAge = fstTemplate.target.contactAge
       }
     }
     strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
   end
   ```

3. **日誌記錄**
   ```lua
   -- 使用現有的 Logger 模組
   Logger.log("開始 BDA 評估，目標數量: " .. #filteredTargets)
   Logger.error("BDA 評估失敗: " .. errorMessage)
   ```

### 執行時機和狀態管理

建議在現有的 `scheduledStrikePlanner.lua` 中新增定時檢查，或創建新的定時事件腳本。

#### 定時事件執行邏輯

根據實際的 `scheduledStrikePlanner.lua` 實現：

```lua
-- 在 scheduledStrikePlanner.lua 中的實際整合方式
local gKH = require('src.core.gKH_State_Standalone')
local config = require("src.core.constants")
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")

-- 獲取聯絡人資料（一次性獲取，避免重複 API 調用）
local contacts = GameApi.ScenEdit_GetContacts('China')

if not contacts then
  return
end

-- 載入保存的狀態資料
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

-- 動態火力支援計畫執行 - 檢查偵察時程並執行 BDA 評估
if saveData.c.ground.dynamicFSP and saveData.c.ground.dynamicFSP.enabled then
  DynamicFireSupportPlan.execute(config, saveData, contacts)
end

-- 其他系統的處理...
if saveData.c.ground.isActivated then
  FireSupportPlan.strike(config, saveData, contacts)
end

if saveData.c.air.isActivated then
  AirTaskingOrder.airStrike(config, saveData, contacts)
end

-- 保存更新後的狀態資料
gKH.State.SaveTableToKey(saveData, "SaveData")
```

### 關鍵執行特點：

1. **統一聯絡人資料**：`contacts` 只獲取一次，傳遞給所有子系統
2. **狀態載入/保存**：使用 `gKH.State` 進行持久化管理
3. **條件檢查**：每個子系統都有自己的啟用條件檢查
4. **順序執行**：按預定順序執行各個子系統
5. **統一保存**：所有系統處理完後統一保存狀態

-- DynamicFireSupportPlan.execute 實際實作邏輯
function DynamicFireSupportPlan.execute(config, saveData, contacts)
  -- 檢查動態 FSP 功能是否啟用
  if not saveData.c.ground.dynamicFSP or not saveData.c.ground.dynamicFSP.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local hasExecutedAny = false

  -- 處理偵察時程表中的每個項目
  for _, reconEntry in ipairs(saveData.c.ground.dynamicFSP.reconSchedule) do
    -- 檢查是否已執行過
    if not reconEntry.executed then
      local reconTime = Utils.parseDatetimeToTimestamp(reconEntry.time)
      local triggerTime = reconTime + reconEntry.delay
      
      -- 檢查是否到達觸發時間（偵察完成 + 延遲）
      if currentTime >= triggerTime then
        -- 處理這個偵察時程項目
        local success = processReconSchedule(config, saveData, contacts, reconEntry)
        
        if success then
          -- 只有成功時才標記為已執行
          reconEntry.executed = true
          hasExecutedAny = true
          Logger.log("Successfully executed dynamic FSP for recon at: " .. reconEntry.time)
        else
          -- 失敗時不標記為已執行，允許後續重試
          Logger.error("Failed to execute dynamic FSP for recon at: " .. reconEntry.time)
        end
      end
    end
  end
  
  -- 返回是否至少成功執行了一個偵察時程項目
  return hasExecutedAny
end

-- 重要行為說明：
-- 1. 只有成功創建 FSEM 時才標記 reconEntry.executed = true
-- 2. 如果目標不足或資源不可用，不標記為已執行，允許後續重試
-- 3. 返回值表示是否至少有一個偵察項目成功處理
```

#### 執行狀態持久化

根據實際的 `scheduledStrikePlanner.lua` 實現，狀態持久化採用 `gKH.State` 系統：

```lua
-- 狀態載入（在腳本開始時）
local saveData = gKH.State.LoadTableFromKey("SaveData")

-- 動態火力支援計畫會直接修改 saveData 中的資料：
-- 1. 設置 reconEntry.executed = true（成功時）
-- 2. 在 saveData.c.ground.FSP 中新增動態 FSEM
-- 3. 所有變更都會反映在 saveData 物件中

-- 狀態保存（在腳本結束時）
gKH.State.SaveTableToKey(saveData, "SaveData")
```

### 持久化的關鍵資料：

1. **偵察時程狀態**：
   ```lua
   saveData.c.ground.dynamicFSP.reconSchedule[n].executed = true
   ```

2. **動態 FSEM**：
   ```lua
   saveData.c.ground.FSP["DYNAMIC/SATELLITE/BDA/1"] = {
     name = "DYNAMIC/SATELLITE/BDA/1",
     isActivated = true,
     isFinished = false,
     FSTs = { ... }
   }
   ```

3. **系統啟用狀態**：
   ```lua
   saveData.c.ground.dynamicFSP.enabled = true/false
   ```

### 重要特點：

- **自動持久化**：不需要手動調用 SaveTableToKey，由 scheduledStrikePlanner 統一處理
- **狀態同步**：所有火力支援系統共享同一個 saveData 物件
- **事務性**：所有系統處理完後才保存，確保資料一致性
- **錯誤恢復**：如果處理失敗，執行狀態不會被標記，允許下次重試
```

### 相容性考量

- 確保新 FSEM 的結構與現有 `FireSupportPlan.strike()` 函式相容
- 維持現有 FSP 序列的執行順序
- 避免與現有火力單位分配產生衝突