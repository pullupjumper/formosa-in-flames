# 命名規範（`src/`）

本文整理 `src/` 現有 Lua 程式碼的實際命名慣例，作為新增與修改程式碼時的依據。
`htmls-app/` 前端另見 `htmls-app/CLAUDE-FRONTEND.md`。

## 1. 檔名

- 一律 camelCase：`gnssJamming.lua`、`scheduledReloadHideCheck.lua`。
- 縮寫詞在檔名中亦按 camelCase 處理，不全大寫：`addGnssJammers.lua`（非 `addGNSSJammers.lua`）。
- 事件腳本改名時，需同步更新 `src/core/init.lua` 中註冊的路徑。

## 2. 模組 table

- PascalCase，與檔名對應：`local StrikePlanner = {}` ↔ `strikePlanner/init.lua`，`local FsemBuilder = {}` ↔ `fsemBuilder.lua`。
- 不使用 `local M = {}`。
- 公開函式掛在模組 table 上：`function Module.doSomething(...)`。

## 3. 函式

- camelCase，動詞開頭：`GameUtils.calculateDistance`、`Recon.processQueue`。
- 動詞只用下表 20 個。新函式先從表裡挑，挑不到才用領域動詞（見表後說明）。

| 動詞 | 意思 | 取代掉的舊字（附實際函式） |
|---|---|---|
| `is` / `has` / `can` | 回布林，無副作用 | `check`（`checkOperationBatchCompleted`）、`matches`（`matchesTemplate`）、`intersects`（`intersectsRadarCircle`） |
| `get` | 讀已存在的值，找不到視為錯誤 | `read`（`readBaseFreeAircraft`，讀遊戲狀態回數字） |
| `find` | 搜尋，可能回 `nil` 或空陣列 | `scan`（`scanTargets`）、`match`（`matchAirfieldTarget`，找到回物件）、`select`（`selectTargetGUIDsByBaseAndSubtype`） |
| `filter` | 從集合挑出子集合 | `select`（`selectAvailableFiringUnits`） |
| `count` | 數個數或加總 | `sum`（`sumFiringUnits`） |
| `calculate` | 算數值 | `calc`（`calcPercentage`）、`estimate`（`estimateStrikerFlightTime`）、`infer`（`inferStrikerTimeOnTarget`，算時間）、`haversine` |
| `build` | 在記憶體組出 table 或字串，不碰遊戲 | `generate`（`generateLocations`、`generateUniqueOperationName`）、`collect`（`collectUniqueAreas`）、`initialize`（`initializeLocationMap`，回一個 map）、`execute`（`AtoBuilder.execute`，builder 的 execute 就是 build） |
| `create` | 透過 CMO API 建出遊戲物件 | `spawn`（`spawnSingleACV`）、`new`（`GameUtils.newArea`，建 zone）、`add`（建物件時） |
| `add` / `remove` | 集合成員增減 | `insert`（`Recon.insertEntry`）、`append`（`appendCommandResult`）、`register`（`registerGeneratedOperation`，加進 tracker）、`delete`（`deleteJammerUnit`）、`cleanup`（`cleanupZoneResources`） |
| `set` / `update` | 改既有物件的屬性 | `apply`（`applyRoleTiming`）、`mark`（`markOperationExecuted`）、`populate`（`populateTargetList`）、`sync`（`syncWeaponReloads`） |
| `resolve` | 把 key、名稱、參照換成實際物件或類別 | `extract`（`extractUnitType`）、`classify`（`classifyUnitType`，名稱換類別） |
| `normalize` | 把輸入整理成標準形，形狀可能改變 | `convert`（`convertToRPArray`）、`transform`（`transformData`） |
| `format` | 轉成字串或程式碼 | `serialize`（`serializeWaypoint`）、`render`（`renderSection`）、`emit`（`emitFiringUnitsBlock`）、`abbreviate`（`abbreviateReconSource`）、`generate`（`generateConfigCode`，產生程式碼字串） |
| `parse` | 字串轉物件 | |
| `validate` | 驗證，回 `SBJ__LogResult` | |
| `ensure` | 沒有就建，有就不動 | （`ensureLoadoutStartTime`、`ensureGeneratedOperations` 已是此意，保留） |
| `process` | 子系統每輪的主入口或狀態分支 | `handle`（`handleMoveToPositionEvent`、`handleFiringPoint`） |
| `start` | 立刻啟動一段流程，不等排程 | `trigger`（`triggerReloadMovement`）、`initiate`（`initiateLoadoutForPackage`）、`run`（`runLaunchPhase`） |
| `init` | 一次性初始化 | `setup` |
| `schedule` | 排未來事件 | |

- **領域動詞**：`move`、`launch`、`attack`、`assign`、`transfer`、`offload`、`reload`、`repair`、`hide`、`stow`、`retire`、`abort`、`deploy`（`deployTaskFiringUnits`）、`drop`（`dropUnitContact`，CMO 的 drop contact）、`collect`（只限 `Sigint.collectSigint`，蒐集情報）這類直接對應軍事或遊戲動作的字可以用，因為換成通用字反而看不懂。條件：一個動作只用一個字，不要 `launch` 和 `spawn` 混用。
- `log` 前綴給寫 log 的函式：`emitScheduleLog` 應是 `logSchedule`。
- `try` 前綴保留給 `pcall` 包裝：`GameUtils.tryAddUnit`。
- 私有函式用 `local function name(...)`，不加 `_` 前綴。
- 回傳布林值的函式以 `is` / `has` / `can` / `should` 開頭：`GameUtils.isInArea`、`LogFormat.hasFailure`。
  - 不用 `check*` 作為布林函式名。`check*` 僅保留給「有副作用且會回報結果」的流程，並在註解說明回傳值。
- 驗證函式 `validate*` 統一回傳 `SBJ__LogResult`（`{ tag, fields }`），不混用 `boolean` 與 `ok, err`。
- 每個函式都要有 LuaLS 註解（`---@param`、`---@return`），現況覆蓋率約 98%。

## 4. 變數

- 一般變數 camelCase。
- 模組層常數 UPPER_SNAKE：`ACV_TYPES`、`COMMS_JAMMING_MODE`。
- 函式內的區域變數不用 PascalCase 或 UPPER_SNAKE：`htmlTemplate`（非 `HTMLTemplate`）、`acvLocations`（非 `ACVlocations`）。
- 縮寫詞在 camelCase 中保持全大寫，且放在字尾或字中：`weaponDBID`、`baseGUID`、`reconUAV`、`aircraftRTB`。
  - 若縮寫詞在開頭則全小寫：`uavDBID`、`wpnDBID`。
- 集合型變數用名字講出形狀：
  - 陣列（`X[]`）：純複數。`units`、`contacts`、`targets`。不加 `List`。
  - 以 key 查詢（`table<K, V>`）：`xxxMap`。`unitMap`、`zoneStateMap`、`opAreaMap`。
  - 集合（`table<K, true>`）：`xxxSet`。`weaponDBIDSet`。
  - 一句話：可以 `ipairs` 的用複數，要用 key 查的加 `Map`。
- 字串變數加 `Str`：`jsonStr`、`datetimeStr`。
- 單字母變數只允許在：
  - `for` 迴圈變數 `i`、`j`、`k`、`v`
  - 數學公式（Haversine 等）中的 `a`、`c`、`x`、`y`、`z`
  - 其他情境要寫全名：`mission`（非 `m`）。

## 5. 參數

固定慣用名，同一概念在整個專案使用同一個字：

| 概念 | 參數名 |
|---|---|
| 陣營名稱 | `sideName` |
| 存檔資料 | `saveData` |
| 全域設定 | `config` |
| 選項 table | `opts` |
| 單位 wrapper | `unit` |
| 區域 | `zone` / `area` |
| 目前時間（秒） | `currentTime` |
| 布林旗標 | `isXxx`（`isAuto`） |
| context 物件 | `xxxCtx`（見下） |

- `params` 與 `opts` 的分別：
  - `params`：必填輸入包成的 table，欄位大多沒有預設值，缺了函式無法執行。型別用 `SBJ__XxxParams`。例：`GameUtils.generateLocations(params)`。
  - `opts`：選填設定包成的 table，欄位大多有預設值，整個傳 `nil` 也能跑。型別用 `SBJ__XxxOpts`。例：`GameUtils.createMission(side, name, type, opts, emcon)`。
  - 參數名與型別後綴要一致：`opts` 配 `Opts`，`params` 配 `Params`。
- context 參數統一用 `Ctx` 後綴：`systemCtx`、`firingUnitCtx`、`resupplyUnitCtx`。
  - 不使用 `xxxContext` 全名。
- 未使用的參數不加 `_` 前綴，直接保留原名以利閱讀 API 簽名。

## 6. 型別（LuaLS）

- 專案自定型別：`SBJ__PascalCase`。
- CMO 遊戲 API 型別：`CMO__*`。這些是引用外部的型別定義，不是專案自訂，名稱照原樣保留，不套用本文件的規則（含底線、後綴語義皆不檢查）。
- 所有 `---@class` 與 `---@alias` 都必須帶上述前綴之一。
- `SBJ__` 前綴之後只用 PascalCase，不再出現底線：`SBJ__GenerateMissilePathsParams`（非 `SBJ__GenerateMissilePaths_Params`）。
- `Params` / `Opts` 後綴依欄位是否必填決定（見第 5 節），不是依「感覺像設定」決定。判斷方法：函式內有沒有對該欄位做 nil 檢查或給預設值。
- 後綴只用下表 10 個。現況有 50 種，逐步收斂。
- **判斷後綴看資料住在哪，不看現在叫什麼**：
  - 住在 `config.lua`，開局後不變 → `Config`
  - 住在 `saveData`，會隨遊戲改變 → `State`
  - 當函式參數傳進去 → `Params` / `Opts`
  - 函式算出來回傳 → `Result`

| 後綴 | 意思 | 例 | 取代掉的舊字 |
|---|---|---|---|
| `Config` | `config.lua` 裡的設定區塊 | `SBJ__ReconConfig` | `Settings`（`AmphibiousFormationSettings`）、`Defaults`（`AircraftCommsDefaults`）、`Constants`（`SIGINTFormulaConstants`）、`DisplayData`（`SIGINTDisplayData`，內容是 RGB 與字型）、`Patterns`（`AirfieldPatterns` 等六個，是 Lua pattern 字串常數，不會被實例化）、`Composition`（`FleetComposition`，是各型船數量） |
| `Descriptor` | config 裡「描述要建什麼」的一筆資料 | `SBJ__SAGDescriptor` | `Spec`（`ShipFormationSpec`，描述要建的船） |
| `Template` | config 裡可被實例化的樣板 | `SBJ__PackageTemplate` | |
| `Context` | 執行期傳遞的 context 物件 | `SBJ__ReconContext` | |
| `State` | 存進 `saveData`、會被改寫的狀態 | `SBJ__ReconRunState` | `Plan`（`ReconUAVPlan`，有 `hasLaunched` 旗標）、`Batch`（`ReconTriggeredOperationBatch`，有 `executed` 旗標）、`Tracker`（`GeneratedOperationsTracker`）、`Status`（`LoadoutStatus`、`UnitStatus`、`WeaponStatus`，都是會變的計數與時間戳） |
| `Params` | 必填輸入 table | `SBJ__LinearPlacementParams` | |
| `Opts` | 選填輸入 table | `SBJ__FilterOpts` | `Mode`（`AreaMode`，是 `newArea` 的參數）、`Behavior`（`MoveToPositionBehavior`，是腳本傳入的開關） |
| `Result` | 函式回傳結果 | `SBJ__LogResult` | `Summary`（`AirbaseAttritionSummary`，有 `@return`）、`Report`（`AmmoInventoryReport`，有 `@return`）、`Counter`（`FiringUnitStatusCounter`，是計數結果） |
| `Entry` | 清單或結果裡的一筆 | `SBJ__RunwayEntry` | `Detail`（`AirbaseAttritionDetail`，是 Summary 裡每架機型一筆）、`Subtotal`（`AmmoSubtotal`，是 Report 裡每類一筆）、`Param`（`TargetQueryParam`，是 config 目標清單裡一筆，不是函式參數） |
| `Type` | 字串列舉的 `---@alias` | `SBJ__OperationType`（`"air"\|"ground"`） | |

- **領域名詞不加後綴**：`SBJ__Unit`、`SBJ__Task`、`SBJ__Wave`、`SBJ__Package`、`SBJ__Target`、`SBJ__Position`、`SBJ__Waypoint`、`SBJ__Operation`、`SBJ__Loadout` 這類直接對應一個實體的型別，不套上表。`Rule`（`StrikeMappingRewriteRule`）、`Mapping`（`ReconStrikeMapping`）、`Timing`（`RoleTiming`）、`Manifest`（`LoadoutCargoManifest`，貨物艙單是軍事用語）、`Paths`（`MovementPaths`）、`Areas`（`TacticalAreas`）、`Point`（`DeparturePoint`）、`Heading`（`FormationHeading`）也算領域名詞，保留。
- **`SBJ__LogReport` 不是 Result**：它有 `add`、`addAll`、`emit` 方法，是收集 log 的物件。保留原名。
- **例外**：`SBJ__SaveData` 及 `ChinaSaveData`、`TaiwanSaveData`、`USSaveData` 是存檔根物件，`saveData` 參數名全專案通用，不改成 `State`。
- 型別名用全名 `Context`；參數名用縮寫 `Ctx`。這是刻意區分。

## 7. `config.lua` 與 `constants.lua` 的 key

- `config.lua`：camelCase 為主。
  - UPPER_SNAKE 只用在「人為指定的代號」：任務模板 `AIR_STRIKE_AB_W_1`、偵察範本 `WZ8_RECON_ISLAND`、目標分類 `FIXED_SITE_TARGETING`。
  - 陣營命名空間固定為 `.c`（中國）、`.t`（台灣）、`.u`（美國）、`.s`（評分）。
- `constants.lua`：UPPER_SNAKE 為主。
  - 頂層與識別碼類 key 用 UPPER_SNAKE：`constants.AREAS.RELOAD_POINT_AMG`、`constants.SIDES.ENEMY`。
  - 描述物件內的欄位用 camelCase：`mask`、`shelterPoints`。

## 8. Log tag 與字串常值

- Log tag 與 `action` 欄位用 snake_case 字串：`"unit_not_found"`、`"course_set"`、`"schedule_next"`。
- 這是資料，不是識別字，所以與程式碼的 camelCase 不同。
- 結果 tag 用 UPPER：`"OK"`、`"FAIL"`。

## 9. 例外

- `src/core/gKH_State_Standalone.lua` 為第三方程式碼，保留原本的 snake_case 與 PascalCase，不套用本規範。
- CMO API 回傳的欄位名（`unit.readytime_v`、`mount.wpn_dbid`）照 CMO 原樣使用，不改名。
- `src/utils/gameApi.lua` 中的 `realApi.ScenEdit_*` 等 wrapper 名稱刻意與 CMO API 同名。

## 10. 刻意保留的例外

以下項目看起來不合規範，但經檢視後保留：

| 位置 | 現況 | 理由 |
|---|---|---|
| `src/modules/strikePlanner/dynamicState.lua` `checkOperationBatchCompleted` | 回布林但前綴是 `check` | 它會把 `operationBatch.executed` 設為 `true`，有副作用，符合第 3 節 `check*` 的定義；註解已說明回傳值 |
| `config.lua` / `saveData` 內型別為 `table<K, V>` 的 key（`firingUnits`、`zoneStates` 等） | 未加 `Map` 後綴 | 改 key 會動到存檔與 config 形狀；`Map` 後綴規則只套用在區域變數與參數 |
