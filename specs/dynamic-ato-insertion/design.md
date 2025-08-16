# 動態ATO插入模組 - 技術設計文件

## 設計概述

動態ATO插入模組負責監控偵察結果，評估目標威脅，並自動生成和插入新的空中任務到現有ATO結構中。採用單一模組集中所有功能，參考dynamicFireSupportPlan的架構模式。

## 模組架構設計

### 單一模組結構
```
src/modules/strikePlanner/dynamicATOInsertion.lua
```

### 核心功能組織
模組內部按功能區塊組織：
- **偵察觸發處理**：監控reconSchedule，觸發評估
- **目標評估決策**：整合TargetingProcess，威脅分析
- **ATO套件生成**：創建wave/package結構
- **資源衝突檢查**：避免與現有任務衝突
- **數據插入管理**：維護saveData.c.air.ATO完整性

## 數據結構設計

### saveData擴展結構
```lua
saveData.c.air.dynamicATO = {
  enabled = true,
  reconSchedule = {
    {
      time = "2027-06-09 03:00:00",
      type = "satellite", -- 或 "aircraft" 
      delay = 300, -- 延遲評估時間（秒）
      executed = false,
      packageTemplate = {
        name = "DYN/STRIKE/RADAR/1",
        targetType = "STRIKE",
        isFirstWave = false,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = config.baseGUID2,
              unitDBID = config.platformDBID29,
              unitCount = 8,
              loadoutID = config.loadoutDBID7
            },
            target = {
              list = {},
              objs = {
                -- 固定目標模式
                { baseName = nil, subTypes = { 'Radar', 'Sky Bow' } }
              },
              areas = { config.c.areas["OPAREA/NORTH"] },
              filterNames = { 'analyzeEmissions' }, -- 動態目標模式
              contactAge = config.c.ground.srbm.contactAge,
              minTargetCount = 2
            }
          }
        }
      }
    }
  },
  generatedWaves = {}, -- 記錄已生成的wave名稱
  lastEvaluationTime = nil
}
```

### constants.lua配置
無需額外配置結構，直接使用現有的constants配置：
- 復用現有的baseGUID、platformDBID、weaponDBID等配置
- 使用現有的areas定義和contactAge設定
- 目標評估閾值直接在packageTemplate中定義

## 核心功能設計

### 主處理函數
```lua
---處理動態ATO插入的主入口函數
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData  
---@param currentTime string
function DynamicATOInsertion.process(config, saveData, currentTime)
  -- 1. 檢查偵察時程觸發
  -- 2. 執行目標評估
  -- 3. 生成ATO套件
  -- 4. 檢查資源衝突
  -- 5. 插入saveData.c.air.ATO
end
```

### 內部功能流程

#### 1. 偵察觸發檢查
- 遍歷reconSchedule，檢查時間觸發條件
- 支援延遲評估機制
- 標記已執行的偵察事件

#### 2. 目標評估決策
採用與dynamicFireSupportPlan相同的兩種評估模式：

**固定目標模式（objs）**：
- 針對已知的基礎設施目標（機場、港口等）
- 使用TargetingProcess.selectTargetsByQueryParams篩選
- 執行TargetingProcess.assessTargetsDamage進行BDA評估

**動態目標模式（filterNames）**：
- 針對移動或電子信號目標（雷達、C2、艦船等）
- 使用TargetingProcess中的專門函數：
  - `analyzeEmissions`：分析電子信號目標
  - `findRadioDirection`：定位通訊目標
  - `findNavalTargets`：搜尋海上目標
  - `findAirborne`：發現空中目標

#### 3. ATO套件生成
- 根據目標類型選擇wave模板
- 分配可用飛機和基地
- 生成完整的package結構
- 自動配置支援要素

#### 4. 資源衝突檢查
- 參考現有ATO檢查飛機可用性
- 避免時間衝突和基地過載
- 實施智慧排程和延遲機制

#### 5. 數據插入管理
- 生成唯一的wave名稱
- 維護ATO數據結構完整性
- 更新相關狀態標記

## API介面設計

### 主要對外接口
```lua
---處理動態ATO插入的主入口函數（參考dynamicFireSupportPlan.process）
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData  
---@param contacts CMO__Contact[]
function DynamicATOInsertion.process(config, saveData, contacts)
```

### 內部核心函數
```lua
-- 偵察時程處理（參考dynamicFireSupportPlan的reconSchedule邏輯）
local function processReconSchedule(config, saveData, contacts)
  -- 內部調用GameApi.ScenEdit_CurrentTime()獲取遊戲時間
  -- 檢查reconSchedule中的觸發時間
end

-- 處理個別ATO模板（參考processFST模式）
local function processATOTemplate(config, saveData, contacts, atoTemplate, isFirstWave)
  -- 兩種目標評估模式：
  -- 1. 固定目標（objs）：使用selectTargetsByQueryParams + assessTargetsDamage
  -- 2. 動態目標（filterNames）：使用analyzeEmissions/findNavalTargets等
end

-- 資源衝突檢查（參考collectAssignedBatteries模式）
local function collectAssignedAircraft(saveData)
  -- 收集當前ATO中已分配的飛機資源
  -- 返回已分配飛機的baseGUID和數量統計
end

-- ATO插入和數據完整性維護
local function insertATOWave(saveData, newWave)
  -- 插入saveData.c.air.ATO
  -- 維護數據結構完整性
end
```

### 與現有系統整合點

#### TargetingProcess整合
- **固定目標評估**：
  ```lua
  TargetingProcess.selectTargetsByQueryParams({
    targetlist = saveData.c.targetlist,
    queryParams = atoTemplate.target.objs
  })
  TargetingProcess.assessTargetsDamage(task, isFirstWave)
  ```

- **動態目標評估**：
  ```lua
  -- 根據filterNames調用相應函數
  TargetingProcess.analyzeEmissions(filterOpts)
  TargetingProcess.findNavalTargets(filterOpts)
  TargetingProcess.findRadioDirection(filterOpts)
  ```

#### 錯誤處理策略
- 所有關鍵操作使用`Utils.safeCall()`包裝
- 使用`Logger.log()`和`Logger.error()`記錄處理狀態
- 參考dynamicFireSupportPlan的錯誤處理模式

## 實作重點

### 參考dynamicFireSupportPlan模式
- 復用processFST的目標評估邏輯
- 採用類似的reconSchedule觸發機制
- 借鑑collectAssignedBatteries的資源檢查方式

### 與現有系統整合
- 完全兼容saveData.c.air.ATO結構
- 使用統一的GameAPI包裝層
- 遵循現有的錯誤處理機制
- 支援LuaLS類型標註

### 開發策略
1. **先實現基本觸發機制**：建立reconSchedule處理框架
2. **整合目標評估**：復用TargetingProcess邏輯
3. **開發ATO生成**：實現package結構創建
4. **完善衝突檢查**：確保資源分配正確性
5. **測試整合驗證**：確保與現有系統無縫協作

這樣的單一模組設計既保持了功能的內聚性，又便於維護和測試。