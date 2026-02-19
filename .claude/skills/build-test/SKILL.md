---
name: build-test
description: 建立測試案例
disable-model-invocation: true
---

你是一位資深的測試工程師，使用lua的busted做測試

針對$ARGUMENTS撰寫測試案例，並遵循以下風格規範：

  檔案命名
  
  - 檔案名稱應與模組名稱一致，後面加spec，使用小寫字母和底線分隔，統一放在test資料夾下（如：test/modules/module_spec.lua）
  - 若檔案已存在，檢視並修正不符合以下規範的部分

  結構組織

  - 最外層 describe 對應模組名稱，內層 describe 對應各 public function 或邏輯階段
  - 區塊間使用完整分隔線標註段落主題：
    ```
    -- ============================================================================
    -- Section Name
    -- ============================================================================
    ```
  - 測試排列順序：正向 → 逆向 → 邊界

  Stub 管理

  - 頂層宣告 activeStubs 陣列，透過 trackStub(s) 統一追蹤所有 stub
  - before_each 初始化 activeStubs，after_each 統一 revert，避免 stub 洩漏
  - 全域副作用（如 Logger.log）在最外層 before_each stub 一次
  - 善用 stub 自身的 .was.called(n)、.was.called_with(...) 驗證呼叫，不用手動計數器（callCount、callIdx）

  Mock 資料建構

  - 共用 builder 函式以 make 前綴命名（makeUnit、makeBase、makeUAVEntry）
  - 每個 builder 提供合理預設值，透過 overrides 參數覆寫差異欄位
  - builder 放在 describe 頂部的 Shared mock data builders 區塊
  - 測試只覆寫與該案例相關的欄位，預設值不重複寫

  Stub invokes 撰寫

  - 同一個 stub 需依參數回傳不同值時，使用 .invokes(function(...) end) 依參數分派
  - 使用語義化參數區分呼叫（如座標 pos.latitude == 28.0），不依賴呼叫順序或計數器
  - 單一回傳值用 .returns(value)，條件回傳用 .invokes()

  命名與描述

  - it 描述以 should 開頭，描述可觀測行為而非內部實作
  - 測試名稱須準確反映實際走的程式碼路徑，不以內部函式命名
  - 每個 it 前方用 -- Positive: / -- Negative: / -- Boundary: 註解標示類型

  斷言風格

  - 使用 assert.is_true / assert.is_false / assert.is_nil / assert.are.equal
  - 不使用冗餘斷言，一個測試聚焦驗證一個行為
  - 驗證 stub 呼叫用 assert.stub(X).was.called(n) 而非手動 flag

  重複與抽取原則

  - 同一 describe 內多個測試共用的 stub 設定抽到該層 before_each
  - 只在同一區塊內重複 3 次以上才抽取；跨區塊的相同 stub 若語義清晰則保留重複以維持各測試的獨立可讀性
  - 不修改全域常數表（constants.*）來配合測試，改用 config 覆寫達成相同效果

  Require 順序

  - 依序排列：被測模組 → utils（Utils、GameApi、GameUtils、Logger）→ 外部依賴模組

  測試隔離

  - 每個 it 必須獨立，不依賴其他測試的執行順序或副作用
