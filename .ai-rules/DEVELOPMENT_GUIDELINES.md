# 開發指南 (Development Guidelines)

## 開發環境設定

### 必要工具
```bash
# 測試工具
luarocks install busted

# 建構工具 (Python 3.6+)
python tools/build_lua_scenario.py
```

### 開發模式啟用
```lua
-- src/core/constants.lua
config.isDevMode = true  -- 啟用控制台日誌和除錯功能
```

## 程式碼規範

### 1. 型別標註規範
所有公開函式必須包含完整的 LuaLS 標註：

```lua
---處理任務分配
---@param missionType string 任務類型
---@param unitGUID string 單位 GUID
---@param targetGUID string|nil 目標 GUID (可選)
---@return boolean success 是否成功分配
---@return string|nil errorMsg 錯誤訊息
function AssignMission.assignToUnit(missionType, unitGUID, targetGUID)
    -- 實作內容
end
```

### 2. 型別前綴約定
- `SBJ__*`: 專案特定型別 (如 `SBJ__CONFIG`, `SBJ__SaveData`)
- `CMO__*`: 遊戲 API 型別 (如 `CMO__Unit`, `CMO__AttackOptions`)

### 3. 命名約定
- **檔案名稱**: camelCase (如 `assignMission.lua`)  
- **函式名稱**: camelCase (如 `createStrikePackage()`)
- **變數名稱**: camelCase (本地變量), UPPER_CASE (常數)
- **模組名稱**: PascalCase (如 `AssignMission`, `GameApi`)

### 4. 程式碼結構
```lua
-- 模組依賴 (檔案頂部)
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.constants")

-- 本地變數
local MODULE_NAME = "AssignMission"

-- 私有函式
local function privateHelper()
    -- 實作
end

-- 公開 API
local AssignMission = {}

function AssignMission.publicMethod()
    -- 實作
end

return AssignMission
```

## API 使用規範

### 1. 強制使用 GameAPI 包裝器
**絕對禁止直接呼叫 CMO API**，必須使用 `src/utils/gameApi.lua` 包裝器：

```lua
-- ❌ 錯誤做法
local unit = ScenEdit_GetUnit({guid = unitGUID})

-- ✅ 正確做法  
local unit = GameApi.ScenEdit_GetUnit(unitGUID)
```

### 2. 錯誤處理策略
CMO API 錯誤處理已在 `gameApi.lua` 中統一實現：

```lua
-- gameApi.lua 自動處理所有 API 錯誤
local unit = GameApi.ScenEdit_GetUnit(unitGUID)
if not unit then
    -- 錯誤已在 gameApi 層記錄
    return false
end
```

### 3. 日誌記錄規範
使用環境自適應日誌系統：

```lua
-- 資訊日誌
Logger.log("任務已成功分配給單位: " .. unitName)

-- 錯誤日誌
Logger.error("API 呼叫失敗: " .. errorMsg)
```

## 配置管理規範

### 1. 常數定義位置
所有平台 DBID、基地 GUID、作戰參數必須定義在 `src/core/constants.lua`：

```lua
-- 按陣營組織配置
config.c.platformDBID = {
    J20 = 4403,
    J16 = 4362,
    -- ...
}

config.t.bases = {
    TAIPEI_SONGSHAN = "Base-123456",
    -- ...
}
```

### 2. 配置存取模式
```lua
-- 使用結構化命名空間
local chinaConfig = config.c.air.landBased
local taiwanBases = config.t.bases
local sharedSettings = config.s.operational
```

## 軍事模擬開發規範

### 1. 單位與編隊管理
使用編隊常數確保一致性：

```lua
-- 使用預定義編隊常數
local formation = {
    angles = FORMATION.ANGLES.LEFT,  -- 實際存在的常數
    distances = FORMATION.DISTANCES.CLOSE
}

-- 實作清理函式防止重複
local function cleanupExistingGroup(groupName, sideName)
    -- 清理邏輯 (unitGenerator.lua 中實際存在)
end
```

### 2. 任務數據配置
```lua
-- 基於 saveData.lua 中的實際結構
local packageConfig = {
    striker = { startTime = "2027-06-09 14:30:00" },
    escort = { startTime = "2027-06-09 14:10:00" },
    wildWeasel = { startTime = "2027-06-09 14:10:00" }
}
```

### 3. API 重試機制
`gameApi.lua` 內建重試邏輯處理 CMO API 時序問題：

```lua
-- gameApi.lua 中已實現重試邏輯
local unit = GameApi.ScenEdit_AddUnit(unitConfig)
if not unit then
    -- 內建重試已執行，記錄失敗
    Logger.error("單位創建失敗")
    return nil
end
```

## 測試開發規範

### 1. 基本測試設置
目前專案使用 Busted 測試框架：

```lua
-- test/modules/dynamicFireSupportPlan_spec.lua (實際存在的測試文件)
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")

describe("DynamicFireSupportPlan", function()
    local mockConfig, mockSaveData, mockContacts
    
    before_each(function()
        -- 設定模擬環境
    end)
    
    -- 測試案例
end)
```

### 2. 測試執行
```bash
# 執行測試
cd test && busted
```

## 建構與部署

### 1. 開發建構
```bash
# 處理模組並產生部署版本
python tools/build_lua_scenario.py
```

### 2. 部署前檢查清單
- [ ] 所有測試通過: `busted`
- [ ] 配置驗證完成
- [ ] 新功能已建立對應測試
- [ ] 型別標註完整
- [ ] 軍事邏輯驗證正確

## 最佳實踐

### 1. 模組化設計
- 保持模組單一職責
- 避免循環依賴
- 使用依賴注入模式

### 2. 效能考量
- 基本的配置快取 (如 SIGINT 模組的 `sideConfigCache`)
- 避免不必要的 API 呼叫
- 使用 `gameApi.lua` 統一處理 API 重試

### 3. 可維護性
- 遵循現有程式碼約定
- 保持軍事術語一致性
- 優先修改現有檔案而非建立新檔案

### 4. 安全性
- 永不記錄敏感資訊 (金鑰、密碼)
- 永不將機密資料提交到版本庫
- 遵循最佳安全實踐

## 除錯與故障排除

### 1. 常見問題
- **API 時序問題**: 使用重試邏輯
- **單位重複建立**: 實作清理函式
- **配置錯誤**: 檢查 constants.lua 設定

### 2. 除錯工具
- 開發模式控制台日誌
- 單元測試隔離問題
- API 包裝器錯誤追蹤

遵循這些指南將確保程式碼品質、可維護性，並與專案的軍事模擬專業標準保持一致。