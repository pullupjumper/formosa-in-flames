# 動態火力支援計畫 (Dynamic Fire Support Plan)

## 概述

動態火力支援計畫系統是一個基於偵察結果的自動化火力支援決策模組，能夠根據即時情報動態創建和執行火力支援任務。

## 功能特點

### 1. 自動化BDA評估
- 根據偵察時程自動觸發戰損評估
- 支援固定目標清單和動態目標篩選
- 智能判斷目標是否需要補充打擊

### 2. 動態FSEM創建
- 自動創建火力支援執行矩陣(FSEM)
- 支援多種武器系統配置
- 智能分配可用火力單位

### 3. 靈活的偵察時程
- 支援衛星和偵察機兩種偵察類型
- 可配置延遲觸發時間
- 執行狀態持久化管理

## 系統架構

```
偵察時程觸發 → 處理FSEM模板 → 逐一處理FST → BDA評估 → 數量判斷 → FSEM創建 → FSP整合
```

## 配置說明

### 基本配置 (constants.lua)

```lua
config.c.ground.dynamicFSP = {
  enabled = true,  -- 啟用/停用功能
  reconSchedule = { ... }  -- 偵察時程表
}
```

### 偵察時程表結構

```lua
{
  time = "2027-06-09 14:30:00",  -- 偵察時間
  type = "satellite",            -- 偵察類型: "satellite" | "aircraft"
  delay = 300,                   -- 延遲觸發時間（秒）
  executed = false,              -- 執行狀態
  fsemTemplate = {               -- FSEM模板
    name = "DYNAMIC/SATELLITE/BDA/1",
    strikeInterval = 600,        -- 打擊間隔（秒）
    FSTs = { ... }               -- FST模板陣列
  }
}
```

### FST模板結構

```lua
{
  name = "機場跑道設施打擊",
  target = {
    objs = {                     -- 固定目標使用
      { baseName = "佳山基地", subTypes = { "跑道", "滑行道" } }
    },
    areas = { "OPAREA/NORTH" },  -- 作戰區域
    filterNames = nil,           -- 動態目標使用篩選函數名稱
    contactAge = 30 * 60,        -- 聯絡人有效時間
    minTargetCount = 2,          -- 最小目標數量閾值
    ammoPerTarget = 2            -- 每目標彈藥數量
  },
  weaponSystem = "mlrs",         -- 武器系統類型
  weaponDBID = config.weaponDBID1  -- 武器DBID
}
```

## 使用方式

### 1. 自動觸發
系統會在 `scheduledStrikePlanner.lua` 中自動執行，每次腳本運行時檢查偵察時程：

```lua
if config.c.ground.dynamicFSP and config.c.ground.dynamicFSP.enabled then
  DynamicFireSupportPlan.execute(config, saveData, contacts)
end
```

### 2. 手動執行
也可以在需要時手動調用：

```lua
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")
local result = DynamicFireSupportPlan.execute(config, saveData, contacts)
```

## 目標篩選方式

### 固定目標 (objs)
用於機場、港口等固定設施：
```lua
objs = {
  { baseName = "佳山基地", subTypes = { "跑道", "滑行道" } },
  { baseName = "志航基地", subTypes = { "彈藥庫", "機堡" } }
}
```

### 動態目標 (filterNames)
用於移動或不確定位置的目標：
```lua
filterNames = { "analyzeEmissions" }  -- 使用TargetingProcess中的函數
```

可用的篩選函數：
- `analyzeEmissions` - 防空雷達和SAM系統
- `findNavalTargets` - 海上目標
- `findMobileTargets` - 移動目標
- `findC2` - 指揮控制設施
- `findInfantry` - 步兵單位
- `findAirborne` - 空中目標

## 武器系統支援

支援的武器系統類型：
- `mlrs` - 多管火箭炮系統
- `srbm` - 短程彈道飛彈
- `mrbm` - 中程彈道飛彈
- `glcm` - 地射巡航飛彈
- `ascm` - 反艦巡航飛彈

## 效能優化

### 1. 早期中斷
- 火力單位分配達到需求數量時立即停止
- 已分配火力單位跳過API調用

### 2. 快取機制
- 執行狀態持久化存儲
- 避免重複執行相同偵察時程

### 3. 條件檢查
- 空值檢查避免不必要的處理
- 數量驗證確保有效操作

## 錯誤處理

### 1. 配置驗證
- 檢查必要的配置參數
- 驗證武器系統存在性

### 2. 目標驗證
- 檢查目標數量是否達到閾值
- 驗證篩選函數存在性

### 3. 資源檢查
- 驗證火力單位可用性
- 檢查彈藥庫存狀況

## 日誌輸出

系統提供詳細的日誌輸出，包括：
- 偵察時程處理狀態
- 目標篩選結果
- 火力單位分配情況
- FSEM創建結果
- 錯誤和異常情況

## 測試

使用 Busted 測試框架進行測試：

```bash
# 執行單元測試
busted test/modules/dynamicFireSupportPlan_spec.lua

# 執行所有測試
busted
```

## 注意事項

1. **偵察時程設定**：確保時間格式正確，使用 "YYYY-MM-DD HH:MM:SS" 格式
2. **武器系統配置**：確保 weaponDBID 與實際武器匹配
3. **作戰區域**：使用 constants.lua 中定義的區域名稱
4. **目標閾值**：根據實際戰術需求設定 minTargetCount
5. **執行狀態**：系統會自動管理執行狀態，避免手動修改 executed 欄位

## 整合說明

動態火力支援計畫系統與現有系統完全整合：
- 與 `FireSupportPlan.strike()` 相容
- 使用相同的火力單位資源池
- 遵循相同的執行時序
- 支援現有的錯誤處理機制

系統設計確保不會與現有火力支援任務產生資源衝突，所有動態創建的 FSEM 都會正確插入到現有的 FSP 執行序列中。