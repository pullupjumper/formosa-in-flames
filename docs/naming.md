# 命名規範（`src/`）

`src/` 下 Lua 程式碼的命名規則。新增或修改程式碼時照這份寫。
`htmls-app/` 前端另見 `docs/frontend.md`。

## 1. 檔名

- camelCase：`gnssJamming.lua`、`scheduledReloadHideCheck.lua`。
- 縮寫詞也照 camelCase：`addGnssJammers.lua`，不是 `addGNSSJammers.lua`。
- 事件腳本改名時，同步改 `src/core/init.lua` 裡註冊的路徑。

## 2. 模組 table

- PascalCase，對應檔名：`local StrikePlanner = {}` ↔ `strikePlanner/init.lua`。
- 不用 `local M = {}`。
- 模組專門管某個存檔 `xxxState` 的建立與更新時，名字加 `Store` 後綴（`GroundStateStore`），避免跟同名的 `SBJ__GroundState` 型別和 `groundState` 變數混淆。
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
| `build` | 在記憶體組出 table、字串、位置或順序，不碰遊戲 | `buildLocations`、`AtoBuilder.build` |
| `create` | 透過 CMO API 建出遊戲物件 | `createSingleACV`、`createArea` |
| `add` / `remove` | 集合成員增減。拿掉過期、已毀、多餘的項目也用 `remove` | `addEntry`、`removeJammerUnit` |
| `set` | 把給定的值或旗標直接寫進既有物件 | `setRoleTiming` |
| `update` | 依現況重算，再寫回既有物件 | `updateTargetList` |
| `resolve` | 只用在把 key、名稱、參照換成實際物件。算數值用 `calculate`，做判斷用 `evaluate`，拆字串用 `parse` | `resolveUnit`、`resolvePair` |
| `normalize` | 把輸入整理成標準形，形狀可能改變 | `normalizeToRPArray` |
| `convert` | 換座標系或單位，純數學，不碰遊戲 | `convertToLocalXY`、`convertToGeo` |
| `project` | 把位置投影到另一個座標軸 | `projectPoint` |
| `format` | 轉成字串或程式碼 | `formatWaypoint`、`formatConfigCode` |
| `parse` | 字串轉物件 | `parseDatetimeToTimestamp` |
| `validate` | 驗證，回 `SBJ__LogResult` | |
| `ensure` | 沒有就建，有就不動 | `ensureLoadoutStartTime` |
| `process` | 子系統每輪的主入口或狀態分支 | `processMoveToPositionEvent`、`MissileSystem.processSide` |
| `start` | 立刻啟動一段流程，不等排程 | `startReloadMovement`、`startLaunchPhase` |
| `init` / `initSide` | 一次性初始化。`init(config, saveData)` 給全域，`initSide(config, saveData, sideName)` 每陣營跑一次；不要寫成 `initXxxContext` | `init`、`initSide`、`initQueue` |
| `schedule` | 排未來事件 | `schedule` |
| `log` | 寫 log | `logSchedule`、`logBox` |
| `try` | `pcall` 包裝 | `tryAddUnit`、`tryCall` |
| `select` | 照規則從候選挑出幾個 | `selectBeachLanes`、`selectBoats` |
| `sort` | 排序 | `sortWaterLanes` |
| `step` | 一輪裡的一個階段，吃 `tickCtx` | `stepMoving`、`stepHovercraft` |
| `advance` | 把一段跨多輪的進度往前推一輪：更新現況，必要時收尾 | `advanceAirWave` |

- **領域動詞**：直接對應軍事或遊戲動作的字可以用，因為換成通用字反而看不懂。現有：`move`（開過去，要花時間）、`teleport`（瞬移，立刻到位）、`recall`（返航，呼叫 CMO 的 `RTB`。不用 `return`，因為讀起來像回傳值）、`launch`、`attack`、`assign`、`transfer`、`offload`、`load`、`reload`、`repair`、`hide`、`abort`、`deploy`、`drop`（CMO 的 drop contact）、`collect`（只限 `collectSigint`）、`recover`、`activate`、`disable`、`strike`、`track`、`pair`、`complete`。一個動作只用一個字，不要 `launch` 和 `create` 混用。
- **工具類保留**：`deepCopy`、`compareFieldKeys`、`forEach*`、`deg` / `rad` / `atan`、`LogFormat.line` / `fields` / `merge` / `report`、`Logger.log` / `error` / `warn`。
- **測試例外**：`spec/` 內的測試工具字 `stub`、`track`（`trackStub`、`stubUnits`）不受動詞表限制。測試資料 builder 一樣用 `build` 前綴，不用 `make`。
- **用字原則（借 ASD-STE100 的精神，不用它的字典）：** 字只從上表和領域動詞選，不另外找字。一個字一個意思，一個意思一個字。要新增動詞，先加進上表再用。
- **近義字只留一個。** 下列字不再用於新函式，改用右邊的字：
  - `plan`、`rotate` → `build`
  - `apply`、`mark`、`lock` → `set`
  - `prune`、`retire`、`strip` → `remove`
  - `settle` → `complete`
  - `abandon` → `abort`
  - `neutralize` → `attack`
  - `send` → `move`
  - `return`、`moveHome`、`sendHome`、`head home`、`go home` → `recall`
  - `due`（`isXxxDue`）→ `can` 開頭，講出能做什麼（`canLaunchNextWave`）
  - `place` → `teleport`
  - `lay` → `create`
  - `choose` → `select`
  - `retransfer`、`redeploy`、`reassign` → `transfer`、`deploy`、`assign`
  - 只出現一次的雜字（`take`、`run`、`dump`、`print`）→ 表內的字
- 現有函式名保留，改到那個函式時順手換字。`process`（約 55 個）是子系統入口，不改。
- `check*` 只給「有副作用又回報結果」的函式，並在註解寫清楚回傳值。純布林用 `is` / `has`。新函式不要用 `check*`。
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
| 一輪內共用的 context 物件 | `xxxCtx`（型別名用全名 `SBJ__XxxContext`） |
| 存進 `saveData` 的狀態物件 | `xxxState`（型別名用全名 `SBJ__XxxState`），不用 `xxxCtx` |

### 參數數量與順序

- **最多 4 個參數。** 超過就把相關的包成 `params`（必填）或 `ctx`（一輪內共用）。
- **固定順序：** `config` → `saveData` / `state` → `sideName` → 主角（`unit`、`zone`）→ 其他輸入 → `opts`。用不到的直接省略，其他不變。
- **一輪內不變的值放進 ctx。** `isAuto`、`currentTime`、`systemCfg` 這類整輪都一樣的值，不要每層函式重傳。
- **旗標放進 `opts`。** 不要放在位置參數尾巴（`f(x, true)` 看不出 `true` 是什麼）。
- **座標傳 `pos`（`{ latitude, longitude }`）。** 不拆成 `lat, lon`。
- ctx 已經帶著的東西，不要再單獨傳一次。

- `params` 與 `opts` 怎麼分：看函式內有沒有對欄位做 nil 檢查或給預設值。有預設值的是 `opts`。
- 未使用的參數不加 `_` 前綴。

### 包裝參數命名

- 只准四種包裝名：`params`（必填）、`opts`（選填）、`ctx`（一輪共用）、`state`（會被改寫）。不准 `xxxSpec`、`xxxRef`、`xxxFields`、`xxxCfg`。
- 一個函式最多一個 `params`。第二包要換成有意義的名詞（`unit`、`target`、`pos`）。
- 只有 `ctx` 和 `state` 可以加前綴表示屬於誰（`passCtx`、`firingUnitState`）。`params`、`opts` 不加前綴。
- 不縮寫：`Cfg` 寫成 `config` 或 `systemConfig`。
- 型別名跟函式走：`SBJ__<函式名>Params`。多個函式共用才用領域名。
- `---@param` 不寫 inline `{a: x, b: y}`，超過 2 欄位就開 `---@class`。

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
| `Context` | 一輪或一次呼叫內共用、不存檔的 context 物件 | `SBJ__LandingTickContext`、`SBJ__CycleRunContext` |
| `State` | 存進 `saveData`、會被改寫（含 `saveData` 底下的子系統資料） | `SBJ__ReconState`、`SBJ__IADSState`、`SBJ__ReconRunState` |
| `Params` | 必填輸入 table | `SBJ__AreaParams` |
| `Opts` | 選填輸入 table | `SBJ__SetUnitPropertiesOpts` |
| `Result` | 函式回傳結果 | `SBJ__LogResult`、`SBJ__AirbaseAttritionResult` |
| `Entry` | 清單或結果裡的一筆 | `SBJ__RunwayEntry`、`SBJ__AmmoSubtotalEntry` |
| `Type` | 字串列舉的 `---@alias` | `SBJ__OperationType` |
| `Key` | 當 table 索引用的字串列舉 | `SBJ__SideKey`、`SBJ__RoleKey` |

- 領域名詞不加後綴：`SBJ__Unit`、`SBJ__Task`、`SBJ__Wave`、`SBJ__Package`、`SBJ__Operation`、`SBJ__Waypoint`、`SBJ__Rule`、`SBJ__Mapping`、`SBJ__Timing`、`SBJ__Manifest`、`SBJ__Path`。
- 型別名一律單數，不用複數：用 `Layout`、`Set` 這類單數集合名詞，不寫 `Areas`、`Paths`。
- `SBJ__LogReport` 有 `add`、`emit` 方法，是物件不是 Result，保留。
- `SBJ__SaveData` 及各陣營 `*SaveData` 是存檔根物件，不改 `State`。

## 7. `config.lua` 與 `constants.lua` 的 key

- `config.lua`：camelCase。UPPER_SNAKE 只用在人為指定的代號：`AIR_STRIKE_AB_W_1`、`WZ8_RECON_ISLAND`。陣營命名空間 `.red`、`.blue`、`.ally`（紅軍為腳本控制方，藍軍為玩家，友軍支援藍軍；是角色，不是國名）；計分用 `config.score`。
- 裝很多個的 key 用複數（`missileSystemTypes`、`firingUnits`、`ammunitions`），單一設定區塊用單數（`policy`）；型別名一律單數。
- 層級：第一層陣營，第二層一個功能（對應 `src/modules/` 一個模組或一個發射領域），第三層只在同功能底下有多個欄位一致的變體時才開。例：`config.red.ground.missileSystemTypes.srbm`。
- 詞義：領域 `ground`、類別 `missileSystemType`（`mlrs`、`srbm`…）、具體系統 `missileSystem`（`firingUnit` 的字串欄位，如 `"DF-17"`）、部隊 `firingUnit`。
- `constants.lua`：頂層與識別碼 UPPER_SNAKE（`constants.SIDES.RED`），描述物件內欄位 camelCase（`shelterPoints`）。

## 8. Log tag 與字串常值

- Log tag 與 `action` 欄位用 snake_case：`"unit_not_found"`、`"course_set"`。這是資料，不是識別字。
- 結果 tag 用 UPPER：`"OK"`、`"FAIL"`。

## 9. 刻意的例外

- `src/core/gKH_State_Standalone.lua` 是第三方程式碼，不套本規範。
- CMO API 回傳的欄位名（`unit.readytime_v`、`mount.wpn_dbid`）照原樣。
- `src/utils/gameApi.lua` 的 `realApi.ScenEdit_*` wrapper 與 CMO API 同名。
- `config.lua` 與 `saveData` 內的 key 不加 `Map` 後綴，改 key 會動到存檔與 config 形狀。
- `SBJ__ReconTriggeredOperationBatch`、`SBJ__GeneratedOperationsTracker`、`SBJ__LoadoutStatus`、`SBJ__UnitStatus`、`SBJ__WeaponStatus` 保留原名；新型別才用 `State`。

## 10. 註解

註解用英文，依 ASD-STE100（簡化技術英語）寫。另外遵守這幾條專案規則：

- 第一句用命令句，動詞跟函式名的動詞一致（`findTargets` → `Find targets that ...`）。動詞照第 3 節的表。
- 註解的名詞跟識別字同一個字。變數叫 `aircraft`，註解就寫 `aircraft`，不寫 `plane`。
- 數值寫單位（`Seconds since scenario start`）。可能回 `nil` 的，寫出什麼情況回 `nil`。
- 寫 why，不重複 what。程式碼已經看得出的事不用寫。
- 若函式、參數、回傳值名稱夠明確，則說明（description）能省則省。
