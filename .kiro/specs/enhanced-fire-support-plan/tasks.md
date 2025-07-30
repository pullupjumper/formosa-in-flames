# Implementation Plan

- [x] 1. 建立動態火力支援計畫模組基礎架構
  - 創建 `src/modules/strikePlanner/dynamicFireSupportPlan.lua` 模組檔案
  - 定義主要模組結構和公開介面 `execute(config, saveData, contacts)`
  - 實作基本的模組初始化和配置載入功能
  - _Requirements: 5.1, 5.2_

- [x] 2. 實作偵察時程處理功能
  - 實作主要 `execute` 函式，包含 for 循環處理整個偵察時程表
  - 新增偵察時間點檢查和延遲觸發邏輯
  - 實作從偵察時程表獲取 FSEM 模板的功能
  - 確保正確使用傳入的 contacts 參數，避免重複 API 呼叫
  - 撰寫偵察時程處理的單元測試
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 3. 實作 BDA 評估引擎
  - 整合現有的 `TargetingProcess.assessTargetsDamage` 函式
  - 實作 BDA 評估任務結構的建立邏輯，使用傳入的 contacts 參數
  - 新增評估結果的驗證和錯誤處理機制
  - 撰寫 BDA 評估功能的單元測試
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 4. 實作打擊決策邏輯
  - 實作基於目標數量閾值的決策機制
  - 新增打擊清單數量檢查和驗證功能
  - 實作決策結果的記錄和追蹤機制
  - 撰寫打擊決策邏輯的單元測試
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 5. 實作 FSEM 創建器
  - 實作動態 FSEM 資料結構的建立邏輯
  - 新增執行時間計算和任務參數設定功能
  - 實作火力單位和武器系統的分配邏輯
  - 新增 FSEM 結構驗證和完整性檢查機制
  - 撰寫 FSEM 創建功能的單元測試
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 6. 實作 FSP 整合器
  - 實作新 FSEM 插入到現有 FSP 序列的邏輯
  - 新增與現有任務相容性檢查機制
  - 實作整體火力支援時程表的更新功能
  - 新增資源衝突檢測和處理機制
  - 撰寫 FSP 整合功能的單元測試
  - _Requirements: 4.3, 4.4, 5.1_

- [ ] 7. 實作偵察時程觸發系統
  - 創建偵察時程觸發腳本或整合到現有的 `scheduledStrikePlanner.lua`
  - 實作事件腳本中的 `checkReconSchedule` 函式
  - 確保在事件腳本中只呼叫一次 `GameApi.ScenEdit_GetContacts('China')`
  - 實作將 contacts 參數正確傳入 `DynamicFireSupportPlan.execute` 的邏輯
  - 實作偵察時程狀態追蹤和執行歷史記錄功能
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 8. 新增偵察時程表和 FSEM 模板到 constants.lua
  - 在 `config.c.ground` 中新增 `dynamicFSP` 配置區塊
  - 定義偵察時程表結構，包含衛星和偵察機時程
  - 實作 FSEM 模板結構，支援多 FST 配置
  - 新增武器系統和 weaponDBID 的配對邏輯
  - 撰寫配置參數載入和驗證的單元測試
  - _Requirements: 5.1, 5.2, 6.1, 6.2_

- [x] 9. 實作錯誤處理和日誌記錄
  - 整合現有的 `Logger` 模組進行日誌記錄
  - 實作各個組件的錯誤處理和驗證機制
  - 新增業務邏輯驗證和異常情況處理
  - 實作錯誤恢復和繼續處理其他目標的邏輯
  - **新增**: 所有日誌訊息和註釋國際化為英文
  - _Requirements: 5.3_

- [ ] 10. 撰寫整合測試
  - 建立完整流程的整合測試案例
  - 測試從偵察時程觸發到 FSEM 插入的完整流程
  - 驗證 contacts 參數傳遞的正確性和效能優化效果
  - 驗證與現有 `FireSupportPlan.strike()` 函式的相容性
  - 測試多次執行和並發執行的穩定性
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1_

- [ ] 11. 效能優化和最終整合
  - 優化大量目標處理時的效能表現
  - 驗證記憶體使用情況和資源管理
  - 確保與現有 FSP 系統的無縫整合
  - 進行最終的系統測試和驗證
  - _Requirements: 4.4, 5.2, 5.4_

- [x] 13. 代碼品質改進和重構
  - **新增**: 函式職責分離 - 將 `checkBatteryAvailability` 拆分為三個子函式
  - **新增**: `collectAssignedBatteries` - 專門收集已分配的battery資訊
  - **新增**: `validateBatteryStatus` - 驗證單個battery的狀態和可用性
  - **新增**: 錯誤處理優化 - 返回詳細錯誤原因和錯誤分類
  - **新增**: 可讀性提升 - 清晰的函式命名和完整的型別註解
  - **新增**: 可維護性增強 - 函式模組化，符合單一職責原則
  - _Requirements: Code Quality, Maintainability_

- [x] 14. 測試架構重構和優化
  - **新增**: 移除對私有函式的直接測試 - 所有內部函式都是 local function
  - **新增**: 專注於公開 API 測試 - 只測試 `execute` 函式
  - **新增**: 場景驅動測試 - 通過不同輸入場景間接測試內部邏輯
  - **新增**: 測試用例優化 - 8個核心測試場景涵蓋所有主要功能
  - **新增**: 錯誤處理驗證 - 確保失敗情況下正確的返回值和狀態
  - **新增**: 集成測試增強 - 驗證完整的 FSEM 創建和插入流程
  - **新增**: Mock 策略改進 - 精確模擬所有外部依賴
  - _Requirements: Test Coverage, API Design_

- [x] 15. 國際化完成和文檔同步
  - **新增**: 所有中文註釋轉換為英文 - dynamicFireSupportPlan.lua 和 saveData.lua
  - **新增**: Logger 輸出訊息英文化 - 統一日誌語言標準
  - **新增**: 測試文件國際化 - 所有測試註釋和描述使用英文
  - **新增**: 規格文檔同步更新 - 反映最新的架構和測試變更
  - **新增**: 資料結構文檔修正 - 區分 FST 模板和執行時物件
  - _Requirements: Internationalization, Documentation_