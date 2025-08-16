# 架構原則 (Architecture Principles)

## 核心架構理念

### 1. 事件驅動架構 (Event-Driven Architecture)
專案採用事件驅動模式，透過 CMO 遊戲引擎的事件系統觸發各種模組執行：

```
CMO事件觸發 → 對應模組處理 → 狀態更新 → 持久化保存
```

**設計原則**:
- **鬆散耦合**: 模組間通過 CMO 事件系統通訊，減少直接依賴
- **響應式設計**: 即時響應遊戲環境變化
- **狀態管理**: 集中化狀態管理 (`saveData.lua`)

**初始化流程**:
`src/core/init.lua` 負責遊戲開始時的數據初始化，包括：
- 目標清單建立 (`initTargetlist`)
- 空中任務命令設定 (`initATO`) 
- 火力支援計畫配置 (`initFSP`)
- 各陣營軍事系統初始化 (`initC2`, `initSIGINT`)

### 2. 分層架構 (Layered Architecture)
```
┌─────────────────────────────────────┐
│  陣營事件處理層 (scripts/)           │  ← 業務邏輯層
├─────────────────────────────────────┤
│  功能模組層 (modules/)              │  ← 服務層
├─────────────────────────────────────┤
│  核心系統層 (core/)                 │  ← 核心層
├─────────────────────────────────────┤
│  工具抽象層 (utils/)                │  ← 抽象層
├─────────────────────────────────────┤
│  CMO 遊戲引擎                       │  ← 基礎設施層
└─────────────────────────────────────┘
```

## 設計模式應用

### 1. API 包裝器模式 (Wrapper Pattern)
`src/utils/gameApi.lua` 實作統一的 API 抽象層：

```lua
-- 包裝器提供統一介面、錯誤處理、重試邏輯
function GameApi.ScenEdit_GetUnit(guid)
    -- 標準化參數處理
    -- 錯誤檢查與重試
    -- 統一錯誤回報
end
```

**優勢**:
- 統一錯誤處理策略
- API 呼叫標準化
- 易於測試和模擬
- 版本相容性管理

### 2. 模組載入器模式 (Module Loader Pattern)
使用 Lua 的 `require()` 系統實現模組化：

```lua
-- 依賴注入式模組載入
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
```

### 3. 配置管理模式 (Configuration Management Pattern)
中央化配置管理 (`src/core/constants.lua`)：

```lua
-- 命名空間結構組織
config.c.*    -- 中國配置
config.t.*    -- 台灣配置  
config.u.*    -- 美國配置
config.s.*    -- 共享配置
```

## 軍事領域建模

### 1. 模組協調架構
實際的系統組織分為初始化系統和作戰協調系統：

**初始化系統**:
```
unitGenerator.lua (軍事單位初始化) ← 遊戲開始時根據配置生成所有軍事單位
├── 戰機部署 (addAircraft) - 各基地戰機數量與武器掛載
├── 艦隊編隊 (createCSG/createSAGs) - 航母群、水面群組
├── 潛艇部署 (addSubmarines) - 戰略潛艇配置
├── 設施建置 (addC2Facilities) - 指揮控制設施
└── 電戰設備 (addGPSJammingZones) - GPS干擾設備部署
```

**作戰協調系統**:
```
scheduledStrikePlanner.lua (作戰協調中心) ← 調度和協調各攻擊系統
├── dynamicFireSupportPlan.lua (動態火力支援)
├── airTaskingOrder.lua (空中任務命令)
├── fireSupportPlan.lua (火力支援計畫)
├── recon.lua (偵察系統)
└── attackManager.lua (攻擊協調)
    ↓
assignMission.lua (任務指派) ← 負責具體任務分配給軍事單位
```

**功能分離**:
- **unitGenerator.lua**: 遊戲初始化階段，根據 `config` 配置生成所有軍事資產
- **scheduledStrikePlanner.lua**: 遊戲運行中的作戰協調，與初始化無關

### 2. 編隊管理架構
幾何演算法實現軍事編隊：

```lua
-- 編隊定位演算法 (unitGenerator.lua)
FORMATION = {
    ANGLES = { LEFT = -45, RIGHT = 45, REAR = -180 },
    DISTANCES = { CLOSE = 1.5, MEDIUM = 4.5, FAR = 20 }
}
```

### 3. 任務數據結構
空中任務命令 (ATO) 的數據組織：

```
空中任務命令 (ATO)
├── 打擊包處理 (StrikePackageProcessor)
├── 護航任務配置 (escort)
├── 壓制敵防空配置 (wildWeasel)
└── 偵察任務數據 (recon)
```

## 資料流架構

### 1. 狀態管理流程
```
初始化 → 配置載入 → 狀態建立 → 事件處理 → 狀態更新 → 持久化
```

### 2. 錯誤處理流程  
`src/utils/gameApi.lua` 提供統一的 API 抽象層和錯誤處理：

```lua
-- gameApi.lua 使用代理模式統一處理所有 CMO API 呼叫
-- 內部使用 Utils.safeCall 包裝關鍵操作
local result, err = Utils.safeCall('GameApi.' .. key, targetFunc, ...)
if not result then
    Logger.error(err)
    return nil
end
```

**設計特點**:
- **代理模式**: `gameApi.lua` 作為所有 CMO API 的統一入口點
- **錯誤集中處理**: 所有 API 錯誤在代理層統一捕獲和處理
- **自動重試**: 內建重試邏輯處理 CMO API 的時序問題

### 3. 測試資料流
```
測試設定 → API 模擬 → 功能執行 → 結果驗證 → 清理
```

## 可擴展性原則

### 1. 水平擴展
- **新陣營支援**: 透過命名空間擴展配置
- **新任務類型**: 實作對應策略模式
- **新軍事平台**: 添加 DBID 配置項

### 2. 垂直擴展
- **增強 AI 邏輯**: 擴展決策演算法
- **複雜任務鏈**: 多層次任務依賴關係
- **進階軍事概念**: 整合更多現代戰爭理論

## 效能最佳化原則

### 1. API 呼叫最佳化
- **批次處理**: 減少單次 API 呼叫
- **重試機制**: `gameApi.lua` 內建重試邏輯處理 CMO API 時序問題
- **錯誤處理**: 統一的 API 錯誤處理避免系統崩潰

### 2. 軍事單位管理
```lua
-- unitGenerator.lua 中的單位清理機制
local function cleanupExistingGroup(groupName, sideName)
  -- 清理重複的軍事群組避免衝突
end
```

### 3. 基本效能優化
- **API 重試機制**: `gameApi.lua` 內建重試邏輯處理 CMO API 時序問題
- **隨機採樣**: SIGINT 模組使用隨機跳過策略減少處理負載
- **配置快取**: SIGINT 模組快取陣營配置避免重複查找

## 測試架構

### 1. 基本測試設置
專案使用 Busted 測試框架進行模組測試：

- **測試文件**: `test/modules/dynamicFireSupportPlan_spec.lua`
- **測試框架**: Busted
- **API 模擬**: 基本的 GameApi 函數 Mock

### 2. 測試執行
```bash
# 從 test 目錄執行測試
busted
```

## 監控與可觀測性

### 1. 日誌架構
`src/utils/logger.lua` 提供環境自適應日誌系統：

```lua
-- 自動環境偵測
Logger.inGame = type(ScenEdit_SpecialMessage) == "userdata"

-- 可用的日誌函式
Logger.log(message)    -- 一般資訊日誌
Logger.error(message)  -- 錯誤日誌
```

**特性**:
- **環境自適應**: 自動偵測遊戲/開發環境
- **格式化輸出**: 遊戲中使用格式化訊息框 (`printBox`)
- **雙語支援**: 支援中英文日誌訊息
- **統一介面**: 標準化的日誌記錄方式

### 2. 基本日誌功能
- **環境自適應日誌**: 自動偵測遊戲/開發環境
- **錯誤記錄**: `Logger.error()` 用於記錄錯誤信息

## 文件架構

### 1. 程式碼文件
- **型別標註**: LuaLS 提供編譯期檢查
- **函式文件**: 完整的參數和回傳值說明
- **模組概述**: 每個模組的用途說明

### 2. 架構文件
- **系統概覽**: 整體架構描述
- **設計決策**: 重要設計選擇的理由
- **最佳實踐**: 開發指導原則

這些架構原則確保了專案的可維護性、可擴展性和專業性，同時滿足複雜軍事模擬的特殊需求。