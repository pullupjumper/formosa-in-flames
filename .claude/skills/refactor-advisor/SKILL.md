---
name: refactor-advisor
description: 提供重構建議
disable-model-invocation: true
---

遵循以下程式碼風格規範來給予重構 Lua 模組$ARGUMENTS的建議，並且模組功能保持一致：

  ### 模組結構
  - 頂部集中 require 宣告
  - 建立模組表 `local ModuleName = {}`
  - 用 `-- ====...====` 分隔線將 local 函式按職責分組，每個區段有標題
  - 最後一個區段為 `Public API`，包含唯一或少量公開函式
  - 檔案結尾 `return ModuleName`

  ### 函式設計
  - 每個函式單一職責，名稱即意圖（動詞開頭）
  - 公開 API 函式作為流程編排器（orchestrator），串接 local 函式，不含底層細節
  - 分層設計：底層純資料操作 → 中層業務驗證 → 高層流程編排 → 公開 API
  - 函式參數控制在合理數量，超過 4 個時考慮拆分或使用 opts table

  ### 回傳值語義
  - 驗證函式回傳 `(status, message)` — status 為列舉字串，message 為人類可讀描述
  - 流程函式回傳 `(success, reason, extraInfo)` — success 為 boolean，reason 為失敗原因碼
  - 公開 API 回傳簡單的 boolean 或有意義的單一結果

  ### 列舉與常數
  - 使用模組級 local table 定義列舉，避免 magic string
  - 列舉表的 key 與 value 用大寫/小寫區分：key 為 `UPPER_CASE`，value 為 `lower_case`
  - 搭配 status counter 模式進行彙總統計

  ### 日誌策略
  - 日誌集中原則：所有內部函式（local function）不得直接呼叫 Logger，僅回傳結構化資料；由 Public API 函式在末尾組合成單一多行報告，一次 `Logger.log` 輸出
  - 迴圈中收集結果到陣列，由呼叫端逐層往上傳遞至 Public API
  - 使用語義標籤區分結果類型：`[OK]`, `[SKIP]`, `[FAIL]`, `[ERROR]`
  - 正常/跳過結果用 `Logger.log`，錯誤用 `Logger.error`，分開輸出

  ### 錯誤處理
  - 流程入口使用 early return guard 處理停用/空值情境
  - 驗證函式逐層檢查，每步失敗回傳明確 status code
  - 不使用 pcall/assert，透過回傳值傳遞失敗
  - 所有 CMO API 呼叫透過 GameApi 封裝層

  ### LuaLS 型別標註
  - 每個函式必須有 `---@param` 和 `---@return` 標註
  - 函式描述最多兩行，首字母大寫
  - 單一回傳值用 `---@return type # Description`
  - 多回傳值用 `---@return type varName Description`（varName 為語義化名稱）
  - 建構複合物件用 `---@type TypeName` 標註

  ### 測試
  - 使用 Test Data Factory 模式建立測試資料，接受 overrides 參數提供差異值
  - Stub 管理：trackStub + activeStubs 陣列，after_each 統一 revert
  - 測試按邏輯分組，用相同的區段分隔線劃分
  - 測試命名以 `should` 開頭，描述條件與預期行為
  - 測試驗證重點：early exit 條件、成功路徑、各類失敗路徑、邊界情況、多項目混合結果、日誌輸出
