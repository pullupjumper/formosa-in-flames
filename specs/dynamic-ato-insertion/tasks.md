# 動態ATO插入模組 - 開發任務清單

## 開發階段規劃

### 階段一：基礎架構建立
- [ ] 創建主模組檔案 `src/modules/strikePlanner/dynamicATOInsertion.lua`
- [ ] 建立基本模組結構和對外接口
- [ ] 實現saveData.c.air.dynamicATO數據結構初始化
- [ ] 建立基本的Logger和錯誤處理機制

### 階段二：偵察時程監控
- [ ] 實現processReconSchedule函數
- [ ] 整合GameApi.ScenEdit_CurrentTime()時間檢查機制
- [ ] 建立reconSchedule遍歷和觸發邏輯
- [ ] 實現執行狀態標記(executed)更新機制

### 階段三：目標評估整合
- [ ] 實現processATOTemplate函數（參考processFST）
- [ ] 整合TargetingProcess.selectTargetsByQueryParams（固定目標模式）
- [ ] 整合TargetingProcess.assessTargetsDamage（BDA評估）
- [ ] 整合動態目標篩選函數：
  - [ ] TargetingProcess.analyzeEmissions
  - [ ] TargetingProcess.findRadioDirection  
  - [ ] TargetingProcess.findNavalTargets
  - [ ] TargetingProcess.findAirborne

### 階段四：ATO套件生成
- [ ] 實現ATO wave/package結構創建
- [ ] 建立動態wave命名機制（DYN/類型/序號）
- [ ] 實現striker/escort/wildWeasel等角色配置
- [ ] 支援loadoutStatus狀態管理
- [ ] 建立package模板系統

### 階段五：資源衝突管理
- [ ] 實現collectAssignedAircraft函數（參考collectAssignedBatteries）
- [ ] 建立飛機資源可用性檢查
- [ ] 實現基地容量和時間衝突檢查
- [ ] 建立智慧排程和延遲執行機制

### 階段六：數據插入整合
- [ ] 實現insertATOWave函數
- [ ] 確保saveData.c.air.ATO數據結構完整性
- [ ] 建立generatedWaves追蹤機制
- [ ] 實現與現有ATO系統的無縫整合

## 測試和驗證任務

### 基本功能測試
- [ ] 偵察時程觸發邏輯驗證
- [ ] 目標評估功能測試（固定和動態模式）
- [ ] ATO生成和插入功能測試
- [ ] 與現有ATO系統兼容性驗證

### 實戰場景測試
- [ ] 衛星偵察觸發完整流程測試
- [ ] 偵察機情報觸發完整流程測試
- [ ] 資源衝突場景處理驗證

## 配置和文檔任務

### 配置結構
- [ ] 在saveData.lua中添加dynamicATO初始化配置
- [ ] 建立reconSchedule範例配置
- [ ] 創建不同目標類型的packageTemplate範例

### 技術文檔
- [ ] 完善函數級註釋和LuaLS類型標註
- [ ] 編寫使用指南和配置說明
- [ ] 更新專案CLAUDE.md說明

### 基本整合檢查
- [ ] 實現基本錯誤處理和日誌記錄
- [ ] 確保與現有launcher模組兼容性
- [ ] 驗證與strikePackageProcessor協作

## 部署和維護任務

### 部署準備
- [ ] 建立build_lua_scenario.py整合測試
- [ ] 驗證開發模式和生產模式運行

### 維護支援
- [ ] 建立基本日誌和監控機制
- [ ] 創建使用文檔和故障排除指南

## 優先級說明

**高優先級**：階段一到三（基礎架構、偵察監控、目標評估）
**中優先級**：階段四到五（ATO生成、資源管理）
**低優先級**：測試驗證和文檔任務