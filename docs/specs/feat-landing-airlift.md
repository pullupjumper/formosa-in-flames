# feat/landing-airlift

## 目標

固定翼運輸機（目前只有 Penghu 的 IL-76）改成跟運輸直升機一樣：手動放飛、走左右翼航線、到降落點 `UnloadCargo`、卸完 RTB。邏輯與機波共用（`heliWave.lua`），不另寫模組。運輸機要比直升機**晚**到。

## 要做到的行為

### 共用邏輯

- 運輸機用機波的 `buildWingCourse`、`updateTransport`（`enroute` → `unloading` → `returning`）、`moveHome`。
- 卸貨、RTB、被擊殺、放下一批、逾時，全部對齊運輸直升機，不另訂規則。
- 降落點、卸貨判斷（`GameUtils.isCargoUnloaded`）都不變。
- 新角色 `ROLE.AIRLIFT = "airlift"`（`SBJ__HeliRoleType` 加值）。狀態表另存（`airlift.units`），不跟直升機的 `units` 混在一起：運輸機的下一批只看運輸機自己，直升機的下一波只看直升機自己。

### 候選

- 從 `zone.air.transportAircraft.guid`（機場）的 `embarkedUnits` 裡挑：dbid 相同、`readytime_v == 0`、機上有 cargo。隨機挑，最多 `airlift.size`（暫定 3）架。
- 區沒有 `transportAircraft` 就不排運輸機。
- 沒有候選：記 log 一次（同機波的 `isWaitingLogged`），下個 tick 再試。

### 時間

- 運輸機抵達降落點的時間 = T + `airlift.delaySec`。T 是衝鋒舟到坐灘線的時間（機波用的同一個 T）。
- 運輸機放飛時間 = T + `delaySec` − 運輸機飛行時間。飛行時間 = 從機場出發、取左右翼較長者的航線長度 ÷ `airlift.cruiseSpeedKt`。
- 在 `HeliWave.schedule` 一起算，存進 `zoneState.heliWave.airlift.launchAt`。算出來已過期就立刻放。
- 這是第一批。第二批起：上一批每一架都是「已 RTB」或「已被擊殺」就放，不看時間，同直升機第二波。

### 放飛與航線

- `Launch(true)`、給 `course`、`throttle = MILITARY`、關 `automatic_evasion`，同 `launchHeli`。
- 高度、速度、到達距離用 `airlift` 自己的值，不用直升機的。
- 航線：直升機左右翼 course 去掉第 1 點（母艦旁的橫移點），剩 2 個點：進內陸轉向點 → 降落點。整條賦值給運輸機（`aircraft.course = course`）。
- 實作時把 `buildWingCourse` 拆開，讓運輸機不需要起點位置（不再依賴母艦或機場座標）。
- 左右翼輪流分配（同 `launchGroup`：第 1 架左、第 2 架右……）。
- 航點偏移量沿用 `wingOffsetM`、`inlandEntryM`、`landingSpreadM`。大型機轉彎半徑大，若轉不過去，再另設 `airlift` 專屬偏移（遊戲內驗證後決定）。
- 飛行時間 = 機場 → course 第 1 點的直線距離 + course 本身長度，取左右翼較長者，÷ `airlift.cruiseSpeedKt`。

### 卸貨與返航

- 距離小於 `airlift.arrivalNm` 就 `UnloadCargo`，卸完 `RTB(true)`。
- 逾時：放飛後超過 `waveTimeoutSec`，還在空中的運輸機一併 RTB，並放下一批（同機波）。
- `GetUnit` 回 `nil` 視為被擊殺。

### 補貨

- 下一批要有貨才飛。`processRemainingCargoTransfer` 觸發時，除了 `transferRemainingCargos`，也對 `zone.air.transportAircraft` 呼叫 `transferTransportAircraftCargo`，把貨補到已回機場的運輸機上（同直升機補貨的節奏 `remainingCargoTransferSec`）。
- `transferTransportAircraftCargo` 本身不改，只多一個呼叫點。

### 設定

放進 `config.red.amphibOps.tuning.heliWave.airlift`：

| 欄位 | 用途 |
|---|---|
| `size = 3` | 運輸機每批架數（暫定） |
| `delaySec` | 比 T 晚多久到降落點 |
| `cruiseSpeedKt` | 倒推放飛時間用 |
| `cruiseAltitudeM` | 放飛後高度 |
| `arrivalNm` | 到降落點的判定距離 |

型別補進 `schema.lua`：`SBJ__HeliWaveConfig.airlift`、`SBJ__HeliWaveState.airlift`、`SBJ__HeliRoleType`。

## 不做

- 不給運輸機護航。
- 不處理降落點的敵方威脅。
- 不改 `transferTransportAircraftCargo` 的裝貨邏輯；初次轉貨的時機（離開 `WAITING_ARRIVAL`）不變。

## 待確認

1. 機場的貨物庫存夠不夠補第二批以後（跟船上補貨一樣吃庫存）。

## 驗收

- `busted --lua=luajit spec` 全過。
- `heliWave_spec` 新增：
  - 從機場挑機：只挑有 cargo 且 ready 的、最多 `size` 架、沒有候選等下個 tick。
  - 放飛時間 = T + `delaySec` − 運輸機飛行時間；比直升機第一波的抵達時間晚。
  - 區沒有 `transportAircraft` 時不排。
  - 到達 → `UnloadCargo` → 卸完才 RTB；被擊殺算結束；逾時也 RTB。
  - 運輸機不影響直升機「放下一波」的判斷，反之亦然。
  - 第二批：上一批全部 RTB 或被擊殺才放；逾時也放。
  - `processRemainingCargoTransfer` 有 `transportAircraft` 的區會補運輸機貨（`coordinator_spec`）。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 同步更新 `docs/landingOps/heliWave.md`。
