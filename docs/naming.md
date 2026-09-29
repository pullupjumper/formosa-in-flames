# 命名規範（`src/`）

`src/` 下 Lua 程式碼的命名規則。新增或修改程式碼時照這份寫。
`htmls-app/` 前端另見 `htmls-app/CLAUDE-FRONTEND.md`。

## 1. 檔名

- camelCase：`gnssJamming.lua`、`scheduledReloadHideCheck.lua`。
- 縮寫詞也照 camelCase：`addGnssJammers.lua`，不是 `addGNSSJammers.lua`。
- 事件腳本改名時，同步改 `src/core/init.lua` 裡註冊的路徑。

## 2. 模組 table

- PascalCase，對應檔名：`local StrikePlanner = {}` ↔ `strikePlanner/init.lua`。
- 不用 `local M = {}`。
- 公開函式掛在模組 table 上：`function Module.doSomething(...)`。
- 私有函式用 `local function name(...)`，不加 `_` 前綴。

## 3. 函式

camelCase，動詞開頭。動詞先從下表挑，挑不到才用領域動詞。

| 動詞 | 用在 | 例 |
|---|---|---|
| `is` / `has` / `can` / `should` | 回布林，無副作用 | `isInArea`、`hasFailure` |
| `get` | 讀已存在的值，找不到視為錯誤 | `getBaseFreeAircraft` |
| `find` | 搜尋，可能回 `nil` 或空陣列 | `findTargets`、`findAirfieldTarget` |
| `filter` | 從集合挑出子集合 | `filterAvailableFiringUnits` |
| `count` | 數個數或加總 | `countFiringUnits` |
| `calculate` | 算數值 | `calculateDistance`、`calculateStrikerFlightTime` |
| `evaluate` | 看狀況算出結論或狀態 | `evaluateTarget`、`evaluateObservationWindow` |
| `roll` | 機率擲骰 | `rollDetection`、`rollJammingResistance` |
| `build` | 在記憶體組出 table ���字串，不碰遊戲 | `buildLocations`、`AtoBuilder.build` |
| `create` | 透過 CMO API 建出遊戲物件 | `createSingleACV`、`createArea` |
| `add` / `remove` | 集合成員增減 | `addEntry`、`removeJammerUnit` |
| `set` / `update` | 改既有物件的屬性 | `setRoleTiming`、`updateTargetList` |
| `resolve` | 把 key、名稱、參照換成實際物件或類別 | `resolveUnitType` |
| `normalize` | 把輸入整理成標準形，形狀可能改變 | `normalizeToRPArray` |
| `format` | 轉成字串或程式碼 | `formatWaypoint`、`formatConfigCode` |
| `parse` | 字串轉物件 | `parseDatetimeToTimestamp` |
| `validate` | 驗證，回 `SBJ__LogResult` | |
| `ensure` | 沒有就建，有就不動 | `ensureLoadoutStartTime` |
| `process` | 子系統每輪的主入口或狀態分支 | `processMoveToPositionEvent`、`MissileSystem.process` |
| `start` | 立刻啟動一段流程，不等排程 | `startReloadMovement`、`startLaunchPhase` |
| `init` / `initSide` | 一次性初始化。`init(config, saveData)` 給全域，`initSide(config, saveData, sideName)` 每陣營跑一次；不要寫成 `initXxxContext` | `init`、`initSide`、`initQueue` |
| `schedule` | 排未來事件 | `schedule` |
| `log` | 寫 log | `logSchedule`、`logBox` |
| `try` | `pcall` 包裝 | `tryAddUnit`、`tryCall` |

- **領域動詞**：直接對應軍事或遊戲動作的字可以用，因為換成通用字反而看不懂。現有：`move`、`launch`、`attack`、`assign`、`transfer`、`retransfer`、`offload`、`load`、`reload`、`repair`、`hide`、`stow`、`retire`、`abort`、`abandon`、`deploy`、`drop`（CMO 的 drop contact）、`collect`（只限 `collectSigint`）、`recover`、`activate`、`disable`、`neutralize`、`strike`、`track`、`pair`、`strip`、`complete`、`settle`。一個動作只用一個字，不要 `launch` 和 `create` 混用。
- **工具類保留**：`deepCopy`、`compareFieldKeys`、`forEach*`、`deg` / `rad` / `atan`、`LogFormat.line` / `fields` / `merge` / `report`、`Logger.log` / `error` / `warn`。
- `check*` 只給「有副作用又回報結果」的函式，並在註解寫清楚回傳值。純布林用 `is` / `has`。
- `validate*` 一律回 `SBJ__LogResult`（`{ tag, fields }`），不混用 `boolean` 或 `ok, err`。
- 每個函式都要有 LuaLS 註解（`---@param`、`---@return`）。

## 4. 變數

- 一般變數 camelCase。模組層常數 UPPER_SNAKE：`ACV_TYPES`。
- 縮寫詞在字中或字尾全大寫：`weaponDBID`、`reconUAV`。在開頭則全小寫：`uavDBID`。
- 集合型變數用名字講出形狀：
  - 陣列（`X[]`）：純複數。`units`、`contacts`。不加 `List`。
  - 以 key 查詢（`table<K, V>`）：`xxxMap`。`unitMap`、`opAreaMap`。
  - 集合（`table<K, true>`）：`xxxSet`。`weaponDBIDSet`。
- 字串變數加 `Str`：`jsonStr`。
- 單字母變數只允許 `for` 迴圈的 `i`、`j`、`k`、`v`，以及數學公式裡的 `a`、`c`、`x`、`y`、`z`。其他寫全名。

## 5. 參數

同一概念全專案用同一個字：

| 概念 | 參數名 |
|---|---|
| 陣營名稱 | `sideName` |
| 存檔資料 | `saveData` |
| 全域設定 | `config` |
| 必填輸入 table | `params`（型別 `SBJ__XxxParams`） |
| 選填輸入 table | `opts`（型別 `SBJ__XxxOpts`，整個傳 `nil` 也能跑） |
| 單位 wrapper | `unit` |
| 區域 | `zone` / `area` |
| 目前時間（秒） | `currentTime` |
| 布林旗標 | `isXxx` |
| context 物件 | `xxxCtx`（型別名用全名 `SBJ__XxxContext`） |

- `params` 與 `opts` 怎麼分：看函式內有沒有對欄位做 nil 檢查或給預設值。有預設值的是 `opts`。
- 未使用的參數不加 `_` 前綴。

## 6. 型別（LuaLS）

- 專案型別 `SBJ__PascalCase`，前綴後不再有底線。
- CMO 遊戲 API 型別 `CMO__*` 是外部引用，照原樣，不套本規範。
- 所有 `---@class` 與 `---@alias` 都要帶前綴。
- 後綴看資料住在哪，只用下表：

| 後綴 | 意思 | 例 |
|---|---|---|
| `Config` | `config.lua` 裡的設定區塊，開局後不變 | `SBJ__ReconConfig`、`SBJ__AirfieldPatternConfig` |
| `Descriptor` | config 裡「描述要建什麼」的一筆 | `SBJ__SAGDescriptor`、`SBJ__ReconUAVDescriptor` |
| `Template` | config 裡可被實例化的樣板 | `SBJ__PackageTemplate` |
| `Context` | 執行期傳遞的 context 物件 | `SBJ__ReconContext` |
| `State` | 存進 `saveData`、會被改寫 | `SBJ__ReconRunState` |
| `Params` | 必填輸入 table | `SBJ__AreaParams` |
| `Opts` | 選填輸入 table | `SBJ__SetUnitPropertiesOpts` |
| `Result` | 函式回傳結果 | `SBJ__LogResult`、`SBJ__AirbaseAttritionResult` |
| `Entry` | 清單或結果裡的一筆 | `SBJ__RunwayEntry`、`SBJ__AmmoSubtotalEntry` |
| `Type` | 字串列舉的 `---@alias` | `SBJ__OperationType` |

- 領域名詞不加後綴：`SBJ__Unit`、`SBJ__Task`、`SBJ__Wave`、`SBJ__Package`、`SBJ__Operation`、`SBJ__Waypoint`、`SBJ__Rule`、`SBJ__Mapping`、`SBJ__Timing`、`SBJ__Manifest`、`SBJ__Path` 這類。
- `SBJ__LogReport` 有 `add`、`emit` 方法，是物件不是 Result，保留。
- `SBJ__SaveData` 及各陣營 `*SaveData` 是存檔根物件，不改 `State`。

## 7. `config.lua` 與 `constants.lua` 的 key

- `config.lua`：camelCase。UPPER_SNAKE 只用在人為指定的代號：`AIR_STRIKE_AB_W_1`、`WZ8_RECON_ISLAND`。陣營命名空間 `.c`、`.t`、`.u`、`.s`。
- `constants.lua`：頂層與識別碼 UPPER_SNAKE（`constants.SIDES.ENEMY`），描述物件內欄位 camelCase（`shelterPoints`）。

## 8. Log tag 與字串常值

- Log tag 與 `action` 欄位用 snake_case：`"unit_not_found"`、`"course_set"`。這是資料，不是識別字。
- 結果 tag 用 UPPER：`"OK"`、`"FAIL"`。

## 9. 刻意的例外

- `src/core/gKH_State_Standalone.lua` 是第三方程式碼，不套本規範。
- CMO API 回傳的欄位名（`unit.readytime_v`、`mount.wpn_dbid`）照原樣。
- `src/utils/gameApi.lua` 的 `realApi.ScenEdit_*` wrapper 與 CMO API 同名。
- `config.lua` 與 `saveData` 內的 key 不加 `Map` 後綴，改 key 會動到存檔與 config 形狀。
- `SBJ__ReconTriggeredOperationBatch`、`SBJ__GeneratedOperationsTracker`、`SBJ__LoadoutStatus`、`SBJ__UnitStatus`、`SBJ__WeaponStatus` 保留原名；新型別才用 `State`。
