# atoBuilder — 動態 ATO Wave 生成

> 原始碼：`src/modules/strikePlanner/atoBuilder.lua`

**職責**：消費偵察觸發的 `air` operation，評估目標與機隊資源，產生可由 `airTaskingOrder` 執行的動態 ATO Wave。

---

## 概述

`atoBuilder` 是 Strike Planner 的動態空中打擊生成層。它不直接建立 CMO mission，也不直接派遣飛機，而是從 `saveData.c.dynamicOperations.reconTriggeredOperationBatches` 找出尚未執行且已到觸發時間的 `air` operation，將其中的 `SBJ__WaveTemplate` 轉成執行態 `SBJ__Wave`，再寫入 `saveData.c.air.airTaskingOrder`。

模組的主要流程分成三段：先透過 [targetingProcess](targetingProcess.md) 依每個 package 的 target template 取得可打擊目標；再檢查各角色基地是否有足夠且未被任務占用的指定 DBID 飛機，並支援 `baseGUIDCandidates` 跨基地 fallback；最後依支援角色飛行時間、striker 武器射程與 `strikeInterval` 產生所有角色的 `startTime` / `endTime`。

插入 Wave 後，模組會透過 [dynamicState](dynamicState.md) 登記 generated operation，避免後續 tick 產生同名任務。若沒有有效 package，operation 會被標記為已處理但不插入 Wave；若 operation 缺少 template，則保留未執行狀態並輸出錯誤，讓後續仍可追蹤問題。

---

## 主要機制

### 動態 ATO 生成流程

```mermaid
flowchart TD
    ENTRY["process(config, saveData, contacts)"]
    ENABLED{"dynamicOperations enabled?"}
    EVAL_TIME["lastEvaluationTime = ScenEdit_CurrentTime()"]
    HAS_BATCH{"reconTriggeredOperationBatches 存在且非空?"}
    FILTER["filterOperationsByType(..., air)"]
    HAS_AIR{"有未執行 air operation?"}
    LOOP["逐一處理 air operation"]
    TRIGGER{"operationBatch time + delay 已到?"}
    TEMPLATE{"operation.template 存在?"}
    TARGETS["evaluateTargetsFromTemplate<br/>TargetingProcess.processTargets()"]
    HAS_TARGETS{"至少一個 package 目標足夠?"}
    BUILD_PKGS["buildExecutablePackages<br/>機隊驗證 + 時序計算"]
    HAS_PACKAGE{"validPackages > 0?"}
    ATO_READY{"airTaskingOrder 已初始化?"}
    NAME["generateUniqueAirOperationName"]
    BUILD_WAVE["buildATOWave + collectWaveTimingResults"]
    INSERT["寫入 airTaskingOrder<br/>registerGeneratedOperation"]
    MARK["markOperationExecuted<br/>missing_template 以外皆標記"]
    LOGS["operations.emit() + timing.emit()"]
    END_FALSE["return false"]
    END_RESULT["return hasExecutedAny"]

    ENTRY --> ENABLED
    ENABLED -->|否| END_FALSE
    ENABLED -->|是| EVAL_TIME --> HAS_BATCH
    HAS_BATCH -->|否| END_FALSE
    HAS_BATCH -->|是| FILTER --> HAS_AIR
    HAS_AIR -->|否| END_FALSE
    HAS_AIR -->|是| LOOP --> TRIGGER
    TRIGGER -->|否| LOOP
    TRIGGER -->|是| TEMPLATE
    TEMPLATE -->|否| MARK
    TEMPLATE -->|是| TARGETS --> HAS_TARGETS
    HAS_TARGETS -->|否| MARK
    HAS_TARGETS -->|是| BUILD_PKGS --> HAS_PACKAGE
    HAS_PACKAGE -->|否| MARK
    HAS_PACKAGE -->|是| ATO_READY
    ATO_READY -->|否| MARK
    ATO_READY -->|是| NAME --> BUILD_WAVE --> INSERT --> MARK
    MARK --> LOOP
    LOOP --> LOGS --> END_RESULT
```

### 目標評估與 package 篩選

`evaluateTargetsFromTemplate()` 會依 `waveTemplate.packages` 順序處理每個 package，呼叫 `TargetingProcess.processTargets(config, saveData, contacts, packageData.target, waveTemplate.isFirstWave)` 取得候選目標。若目標數達到 `packageData.target.minTargetCount`，該 package index 會被記錄在 `targetsByPackageIndex`；若沒有設定 `minTargetCount`，預設需求為 1 個目標。

`buildExecutablePackages()` 只會處理已通過目標門檻的 package。它會從 `operation.template` 的 deep copy 建立執行態 package，將 `package.target.list` 改成實際目標清單，並在機隊驗證成功後委派 [packageTiming](packageTiming.md) 的 `createPackageWithTiming()` 補齊 timing 與 `loadoutStatus`。時序串接使用「前一個有效 package」作為基準，因此即使原始第 1 個 package 被跳過，第 1 個成功建立的 package 仍會被視為第一個有效 package。

驗證摘要會以 `packages=<有效>/<總數>` 與 `targets` 形式寫入 operation log 行。若 package 因機隊或加油機設定驗證失敗，該筆失敗會成為 operation 行底下縮排一層的 `[SKIP]` detail 行，列出 package、role、需求數、最佳候選基地的可用機數與嘗試過的基地數。detail 行跟隨父行進同一個 sink，但不計入 header 的 `total`，因此 `total` 恆等於本次處理的 operation 數。這能在 CMO console 或測試輸出直接辨識無有效 package 的原因，而不是只看到插入流程未執行。

### 機隊資源驗證

機隊驗證依 `PACKAGE_ROLES` 固定順序檢查：

```text
striker -> escort -> wildWeasel -> jammer -> tanker
```

`validateAircraftRole()` 會把 `roleData.baseGUID` 與 `roleData.baseGUIDCandidates` 串成候選基地清單，依序尋找可用飛機。可用飛機由 `getBaseAircraftCapacity()` 計算，條件是基地 `embarkedUnits.Aircraft` 中的 aircraft `dbid` 符合 `roleData.unitDBID`，且 `aircraft.mission == ""` 或 `nil`。

```text
可用餘額 free = getBaseAircraftCapacity(baseGUID, unitDBID) - assignedAircraft[baseGUID]

接受條件： free >= roleData.unitCount / 2
預訂量：   free >= roleData.unitCount -> 預訂 roleData.unitCount
           free <  roleData.unitCount -> 預訂 free
```

當某候選基地通過半戰力門檻，模組會把 `roleData.baseGUID` 改寫為實際選定基地，並先把預訂量累加到 package 專用的暫存表。只有所有已設定角色都通過驗證時，暫存預約才會提交至 `assignedAircraft`；任一角色失敗時會丟棄整包暫存預約，避免未執行的 package 占用後續 package 的飛機。`roleData.unitCount` 不會因半戰力通過而改寫；實際派遣數仍由下游 [airTaskingOrder](airTaskingOrder.md) 依可用飛機處理。

`collectAssignedAircraft()` 也會掃描既有 `saveData.c.air.airTaskingOrder`，統計所有 `isActivated == true`、`hasLaunched ~= true` 且 package 尚未 launched 的 role `unitCount`，避免動態插入時和既有 active Wave 重複占用機隊。

若 tanker 的 `missionCreationParams` 使用陣列，建立 Wave 前會額外驗證陣列非空、任務名稱有效且不重複，以及 `unitCount` 可被任務數整除。機隊容量與預訂量仍使用 tanker 的總 `unitCount`，不會因任務拆分而重複計算。

### 飛行時間與任務時序

機隊驗證通過後，`buildExecutablePackages()` 會逐一委派 [packageTiming](packageTiming.md) 的 `createPackageWithTiming()`，以前一個有效 package 為時序基準計算各角色的 `startTime` / `timeOnStation` / `endTime`。飛行時間估算、支援角色戰術提前量、加油機受油協調，以及依 `timeToReady` 與 `strikeInterval` 的整組平移約束，皆封裝於該模組；本模組僅負責串接前後 package 並提供 `strikeInterval`。詳細時序演算法請參閱 [packageTiming](packageTiming.md)。

### 結果分類與 log

`processAirOperation()` 回傳 `SBJ__AirOperationProcessResult`，內含 `success`、`reason`、`tag`、`fields`、`details` 與 `timing`。`success` 與 `reason` 供 `AtoBuilder.process()` 判斷是否 `markOperationExecuted` 與模組回傳值；`reason` 的字串同時是控制流程的判斷值與 log 的 `reason=` 內容，log 行可以直接反查到產生它的分支。

| reason | tag | 條件 | 後續處理 |
|---|---|---|---|
| `missing_wave_template` | `ERROR` | operation 缺少 `template` | 不標記 executed |
| `no_valid_packages` | `SKIP` | 目標不足或機隊驗證後沒有有效 package | 標記 executed |
| `insertion_failed` | `FAIL` | `airTaskingOrder` 未初始化 | 標記 executed |
| `nil` | `OK` | Wave 成功插入 | 標記 executed，另外輸出 timing report |

tag 由產生分支直接寫入結果，不再經過 reason → tag 對照表。`AtoBuilder.process()` 只把 operation 識別欄位與 `outcome.fields` 合併後交給 `LogFormat.report`，格式化、info／error 分流與空輸出抑制全部由 report 負責。

log 分成 `dynamicAirOperations` 與 `dynamicAirTiming` 兩個 report，tag 使用 `constants.TAGS.DYNAMIC_OPERATIONS`。package 驗證失敗會成為 operation 行底下縮排一層的 detail 行，因此歸屬清楚，且不計入 header 的 `total`（`total` 代表本次處理的 operation 數）：

```text
[DYNAMIC_OPERATIONS] dynamicAirOperations: Process operations | total=2 ok=1 skip=1
  [OK]   operation=AIR/STRIKE/AB/1 wave=DYNAMIC/SATELLITE/STRIKE/AB/1/1 batch="satellite@2026-02-14 00:00:00" packages=2/3 targets=8
    [SKIP] package=3 role=striker available=1 bases=2 required=4 reason=insufficient_aircraft
  [SKIP] operation=AIR/STRIKE/CD/1 batch="uav@2026-02-14 03:00:00" packages=0/2 targets=0 reason=no_valid_packages
    [SKIP] package=1 role=striker available=1 bases=3 required=4 reason=insufficient_aircraft
```

---

## saveData 結構

```text
saveData.c
├── dynamicOperations
│   ├── enabled: boolean
│   ├── lastEvaluationTime?: number
│   ├── generatedOperations
│   │   ├── air: table<string, boolean>
│   │   └── ground: table<string, boolean>
│   └── reconTriggeredOperationBatches: SBJ__ReconTriggeredOperationBatch[]
│       └── ReconTriggeredOperationBatch
│           ├── time: string
│           ├── type: string
│           ├── delay: number
│           ├── executed: boolean
│           └── operations: SBJ__Operation[]
│               ├── type: "air"
│               ├── executed: boolean
│               ├── executionResult?: boolean
│               └── template: SBJ__WaveTemplate
└── air
    └── airTaskingOrder: table<string, SBJ__Wave>
        └── generated Wave
            ├── name: string
            ├── isActivated = true
            ├── isFirstWave: boolean
            ├── hasLaunched = false
            ├── strikeInterval: number
            └── packages: SBJ__Package[]
                ├── timeToReady: number
                ├── loadoutStatus: SBJ__LoadoutStatus
                ├── hasLaunched = false
                ├── striker / escort / wildWeasel / jammer / tanker
                └── target.list: string[]
```

### 寫入與副作用

| 路徑或 API | 行為 |
|---|---|
| `saveData.c.dynamicOperations.lastEvaluationTime` | 每次 `process()` 通過 enabled 檢查後寫入目前 CMO 時間。 |
| `saveData.c.air.airTaskingOrder[wave.name]` | 成功建立 Wave 時寫入新的 `SBJ__Wave`。 |
| `saveData.c.dynamicOperations.generatedOperations.air[wave.name]` | 透過 `DynamicState.registerGeneratedOperation("air", wave.name, saveData)` 登記。 |
| `operation.executed` / `operation.executionResult` | 透過 `markOperationExecuted()` 標記，`missing_template` 例外。 |
| `operationBatch.executed` | 當 batch 內所有 operation 都完成時由 `DynamicState.checkOperationBatchCompleted()` 更新。 |

---

## local constants

| 名稱 | 內容 | 用途 |
|---|---|---|
| `PACKAGE_ROLES` | `striker`、`escort`、`wildWeasel`、`jammer`、`tanker` | 機隊驗證與既有任務占用量統計。 |
| `ALL_ROLES` | `PACKAGE_ROLES` 加上 `reconUAV` | timing log 收集。 |
| `PROCESS_REASON` | `missing_wave_template`、`no_valid_packages`、`insertion_failed` | operation 處理失敗或略過原因，同時作為 log 的 `reason=` 值。 |
| `LOG_SCOPE`／`LOG_ACTION` | `dynamicAirOperations`／`Process operations` | operation report 的 scope 與 action。 |
| `TIMING_LOG_SCOPE`／`TIMING_LOG_ACTION` | `dynamicAirTiming`／`Build ATO wave timing` | timing report 的 scope 與 action。 |

---

## config 與 constants 參考

| 類型 | 路徑 | 使用方式 |
|---|---|---|
| `config` | `config.c.air.timing` | 由 [packageTiming](packageTiming.md) 消費，計算支援角色戰術提前量、tanker 就位時間、巡航速度、無法解析航程時的 fallback、任務持續時間與安全裕度。 |
| `config` | `config.c.packageTemplates` | 上游 [operationScheduler](operationScheduler.md) 的 air operation template 來源，動態 operation 最終會攜帶 `SBJ__WaveTemplate` 進入本模組。 |
| `config` | `config.readytime` | Package template 必填的 `timeToReady` 來源，runtime 以秒為單位；本模組不提供 fallback。 |
| `constants` | `constants.SIDES.ENEMY` | 讀取支援角色任務區 reference point。 |
| `constants` | `constants.TAGS.DYNAMIC_OPERATIONS` | 輸出 dynamic ATO 處理結果與 timing log。 |

---

## 相依模組

| 模組 | 用途 |
|---|---|
| `src.modules.strikePlanner.targetingProcess` | 依 target template、contacts 與 BDA 條件產生可打擊目標清單。 |
| `src.modules.strikePlanner.dynamicState` | 篩選 air operations、產生唯一 Wave 名稱、登記 generated operation、標記 operation 執行狀態。 |
| `src.modules.strikePlanner.packageTiming` | 機隊驗證後計算 package 內各角色時序、加油機受油協調與整組平移。 |
| `src.modules.strikePlanner.tankerMission` | 正規化 tanker `missionCreationParams`，驗證多任務加油機設定。 |
| `src.utils.gameApi` | 取得目前時間、基地/飛機/reference point、weapon DB 查詢與距離計算。 |
| `src.utils.gameUtils` | 判斷 recon-triggered operation 是否已到觸發時間。 |
| `src.utils.utils` | deep copy 與 UTC datetime 字串轉 timestamp。 |
| `src.utils.logger` | 輸出動態空中作戰結果與錯誤。 |
| `src.utils.logFormat` | 產生一致的 key/value log entry 與 summary。 |
| `src.core.constants` | 提供 side name 與 log tag。 |

---

## Public API

| 函數 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `AtoBuilder.process(config, saveData, contacts)` | `SBJ__Config`, `SBJ__SaveData`, `CMO__Contact[]` | `boolean` | 處理所有已到觸發時間的未執行 air operations；若至少成功插入一個 ATO Wave，回傳 `true`。 |

### 呼叫者與觸發方式

| 呼叫者 | 觸發 |
|---|---|
| `StrikePlanner.processDynamicAirOperations(config, saveData, contacts)` | Strike Planner facade，轉呼叫本模組 public API。 |
| `src/scripts/china/scheduledStrikePlanner.lua` | 定時腳本在 `saveData.c.dynamicOperations.enabled` 為 true 時呼叫 `StrikePlanner.processDynamicAirOperations()`。 |
| [airTaskingOrder](airTaskingOrder.md) | 不呼叫本模組；它在後續 tick 執行本模組插入的 active Wave。 |

---

## 相關模組

- [airTaskingOrder](airTaskingOrder.md) — 執行本模組插入的 ATO Wave。
- [packageTiming](packageTiming.md) — 機隊驗證後計算 package 各角色時序與加油機受油協調。
- [targetingProcess](targetingProcess.md) — 動態目標評估與 BDA 過濾。
- [dynamicState](dynamicState.md) — recon-triggered operation 狀態、命名與 generated operation 追蹤。
- [operationScheduler](operationScheduler.md) — 偵察完成後建立 air operation template。
- [fsemBuilder](fsemBuilder.md) — 對應的動態地面 FSEM 生成流程。
- [系統架構](README.md)
