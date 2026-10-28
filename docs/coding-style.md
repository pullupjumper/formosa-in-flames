# 寫法慣例（`src/`）

同一件事只留一種寫法，review 時不用再看「這次又換了哪種」。
命名見 `docs/naming.md`；本文件管命名以外的寫法。
新程式碼一律照寫；改到舊函式時順手換成這裡的寫法。

## 1. 缺值判斷

- 預設用 `if not x`。
- 只有「要分辨 `false` 和 `nil`」，或函式要回傳「是否存在」的布林時，才寫 `== nil` / `~= nil`。

```lua
if not unit then return false end            -- 預設
return GameApi.ScenEdit_GetUnit(guid) ~= nil  -- 回傳「是否存在」
```

## 2. 空集合

- 陣列：`#t == 0`。
- 以 key 查詢的 table：`next(t) == nil`。
- `Utils.getCount` 只用在真的要「數個數」的時候，不拿來判斷空。

## 3. 函式的回傳

依函式動詞（見 `docs/naming.md` 第 3 節）決定回傳形狀：

| 函式 | 回傳 |
|---|---|
| `is` / `has` / `can` / `should` | `boolean` |
| `get` | 值；找不到視為錯誤 |
| `find` | 值或 `nil`；找集合時回空陣列 |
| 公開的動作函式（`move`、`create`、`set` …） | `boolean`，`true` 表示成功；失敗原因寫 log |
| 模組內部的步驟，結果要晚一點輸出 | `SBJ__LogResult`（多筆用 `SBJ__LogResult[]`） |
| 要回資料但可能失敗 | `值\|nil, errorFields`；`errorFields` 是 `table<string, any>` |
| `validate` | `SBJ__LogResult` |

- 同一個函式的所有分支回傳同一種形狀。不要一個分支 `return false`、另一個 `return nil`。
- 失敗時不要自己 `error()`；用上表的回傳表達。

## 4. log

- 私有函式不直接寫 `Logger`，回傳 `SBJ__LogResult`，由公開函式在末端彙總輸出。
- 一次處理多個單位、要彙總：`LogFormat.report`。
- 單一事件：`Logger.log(tag, LogFormat.line(...))`；警告和錯誤用 `Logger.warn` / `Logger.error`，一樣傳 `LogFormat.line(...)`。
- 不傳純字串：`Logger.error("contacts is nil")` 不行。

## 5. `---@return` 說明

- 單一回傳值：`---@return boolean # True if ...`。
- 多個回傳值：每個用具名寫法 `---@return integer positioned`。
- `boolean` 一定要說明 `true` 是什麼意思。型別名本身已說明的（如 `CMO__Location`）可以省略說明。

## 6. 數字常數放哪裡

- 不變的物理值或識別碼（`METERS_PER_NM`、DBID、GUID、區域定義）：`src/core/constants.lua`。
- DBID、GUID、座標不寫死在邏輯裡，一律從 `constants.*` 或 `config.*` 取。
- 可能要調整的玩法數值（等待 2 小時、總量 440、距離門檻 1 nm）：`src/core/config.lua`。
- 同一個值出現 2 次以上，不能在各檔案各自定義一次。
- 只在單一檔案用一次、不會調整的值，可以在檔頭宣告 `UPPER_SNAKE` 常數。

## 7. `require` 順序

- 先 `src.core.*`，再 `src.utils.*`，最後 `src.modules.*`。
- 組與組之間不空行；組內按完整路徑字母排序。

## 8. 區塊分隔線

- 檔案超過 150 行才用 `-- ====` 分隔線；150 行以下不加。
- 標題固定三類：`Constants`（常數）、`Public API`（對外函式，可加 `: 主題`）、其餘私有函式用主題名（沒有明顯主題時叫 `Helpers`）。
- 順序：`Constants` → 私有函式 → `Public API`。

## 9. 測試檔（`spec/`）

測試只驗行為（回傳值、錯誤、對外動作），不驗內部做法；寫法以 `spec/` 既有檔案為準。
