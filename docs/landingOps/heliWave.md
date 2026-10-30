# heliWave — 直升機機波

> 原始碼：`src/modules/landingOps/heliWave.lua`

**職責**：從母艦手動放飛運輸直升機與攻擊直升機，沿左右翼進內陸。運輸直升機卸貨後返航；攻擊直升機走到門檻就指派進本區的 CAS 任務，之後交給 CMO

---

## 概述

一波 = 最多 `transport.waveSize`（8）架運輸直升機，加上補到 `attack.count`（4）架為止的攻擊直升機。每區各自一組波次，所有區的大小相同。

運輸直升機**不指派 CMO 任務**：`Launch` 之後直接設 `course`，到點呼叫 `ScenEdit_UnloadCargo`。波數不設上限，直到沒有載貨的運輸機為止。

攻擊直升機同樣先走自己的航線，距降落點 `attack.casAssignNm` 時指派進 CAS 任務。指派後腳本不再管它：不下 `RTB`，也不拿掉任務。

固定翼運輸機（目前只有 Penghu 的 IL-76，`air.transportAircraft`）走同一套邏輯，稱為 airlift：從機場手動放飛，走左右翼的內陸段（沒有橫移點），到降落點卸貨、返航。airlift 的批次狀態另存在 `heliWave.airlift`，與直升機機波互不影響。區沒有 `transportAircraft` 就不排。

---

## 流程

```
BOAT_ASSAULT 開始  → schedule：建立本區 CAS 任務；估衝鋒舟到岸時間 T，倒推第一波放飛時間 launchAt
每 tick            → update：推進攻擊直升機與當前這一波運輸機；運輸機結束且到時間 → 放下一波
```

### 第一波放飛時間

`launchAt = max(現在, T − 飛行時間)`。

- **T**：衝鋒舟到岸時間，由 `AssaultBoat.estimateShoreArrival` 估（規則見 [assaultBoat](assaultBoat.md)）。
- **飛行時間**：第一艘母艦沿左右翼較長者的航線長度 ÷ `cruiseSpeedKt`。
- 沒有配對衝鋒舟時，`T = 現在`，立刻放。

`GameUtils.isAfterStartTime(launchAt)` 判斷是否到了。第二波起不看時間，只看上一波是否結束。

### Airlift 放飛時間

- 抵達降落點的時間 = `T + airlift.delaySec`，比直升機第一波晚。
- 放飛時間 = 抵達時間 − 飛行時間；已過期就立刻放。飛行時間 = 機場到內陸段第 1 點的直線距離加內陸段長度，取左右翼較長者，÷ `airlift.cruiseSpeedKt`。
- 這是第一批。第二批起不看時間：上一批每一架都 `returning` 或已被擊殺就放；逾時（`waveTimeoutSec`）也放。
- 候選：機場 `embarkedUnits` 裡 DBID 相符、`readytime_v == 0`、機上有 cargo 的飛機，隨機挑最多 `airlift.batchSize` 架。沒有候選就記一次 HOLD log，下個 tick 再試。
- 補貨：`processRemainingCargoTransfer` 觸發時，除了 `transferRemainingCargos`，也對 `zone.air.transportAircraft` 呼叫 `transferTransportAircraftCargo`，補到已回機場的運輸機上。

### CAS 任務

`schedule` 建立 `CAS/HELI/<區名>`，類型 `patrol`、`type = "land"`，區域用 `air.attackHelicopter.zone`。類型是否等同想要的 CAS 尚待在 CMO 確認。

### 挑選

- 候選：本區 `mothership` 內 Type 075/076/071 上、`readytime_v == 0` 的直升機。
- 運輸直升機：DBID 相符且機上有 cargo。攻擊直升機：DBID 相符。
- 隨機挑，不足照飛。攻擊直升機只挑「`attack.count` 減去本區已記錄的架數」那麼多，已滿就不放。沒有任何有貨的運輸直升機時等下個 tick（貨由 `transferRemainingCargos` 補）。

### 航線

放飛後即分左右翼（依序輪流分配），沒有共同航線。每個點由 lane frame 的「縱向／橫向」座標算出：

1. 原地橫移到翼（橫向 ±`flightPath.wingOffsetM`）
2. 沿翼飛到內陸 `flightPath.inlandEntryM`
3. 轉向翼自己的降落點（降落區中心，橫向再偏 ±`flightPath.landingSpreadM`）

### 每架的階段

| 角色 | 階段 |
|---|---|
| 運輸 | `enroute` → 距降落點 < `transport.arrivalNm` 時 `UnloadCargo` → `unloading` → 卸完 `RTB(true)` → `returning` |
| 攻擊 | `enroute` → 距降落點 < `attack.casAssignNm` 時指派進 CAS 任務 → `cas`（之後不再處理） |

- 運輸的階段由 [cargoRun](cargoRun.md) 推進。
- 卸完：`isCargoUnloaded`，即 `unit.condition == "Underway"`（且不是 `"Transfering Cargo"`）且 `cargo == nil`。字串是暫定，見 `constants.UNIT_CONDITIONS`，需對遊戲日誌校正。
- 被擊殺：`TrackedUnits.findUnit` 回 `nil`，該筆已從所有登記表刪掉，之後不再查。

### 一波結束與逾時

這一波的運輸機每一架都是 `returning` 或已被擊殺，這一波就結束。攻擊直升機不算在內，不會卡住下一波。放飛後超過 `waveTimeoutSec` 仍未結束，剩下的運輸機全部 `RTB`，視為結束並記 WARN。

---

## 狀態

`zoneState.heliWave`（`SBJ__HeliWaveState`）分三塊：

- `transport`：運輸直升機的機波。
- `airlift`：運輸機的批次，區沒有運輸機就是 nil。
- `attackHelis`：本區的攻擊直升機，跨波保留。筆數就是已算進 `attack.count` 的架數，不去查 CMO 任務。

`transport` 和 `airlift` 同型（`SBJ__AirWaveState`）：`currentWave` 只存當前這一波（批）的運輸機，下一波放飛時整個換掉；另有 `waveIndex` / `launchAt` / `waveLaunchedAt`。欄位見 `schema.lua`。

攻擊直升機、運輸直升機和運輸機被擊殺時，由 [trackedUnits](trackedUnits.md) 依 GUID 從 `attackHelis`、`transport.currentWave`、`airlift.currentWave` 移除，之後輪詢不再查它（避免 `Unit not found` ERROR）。移除等同已被擊殺，一波（批）結束的判斷不變；下一波架數只看候選，不看 `currentWave`。事件沒趕上時，輪詢透過 `TrackedUnits.findUnit` 第一次查不到就刪掉。

---

## 設定

`config.red.amphibOps.heliWave`：

| 欄位 | 用途 |
|---|---|
| `waveTimeoutSec` | 一波（批）的逾時，直升機與 airlift 共用 |
| `cargoReloadSec` | 補運尚未運完的貨物的間隔，見 [coordinator](coordinator.md) |
| `flightPath.wingOffsetM`、`inlandEntryM`、`landingSpreadM` | 翼航線幾何（airlift 共用） |
| `transport.waveSize` | 每波運輸直升機架數（左右翼各半） |
| `transport.cruiseSpeedKt`、`cruiseAltitudeM` | 倒推放飛時間用的巡航速度、放飛後的巡航高度 |
| `transport.arrivalNm` | 運輸直升機到降落點的判定距離 |
| `attack.count` | 每區攻擊直升機總數（已進 CAS 的加飛往中的） |
| `attack.casAssignNm` | 攻擊直升機離降落點多近就指派進 CAS 任務 |
| `airlift.batchSize` | 每批運輸機架數 |
| `airlift.delaySec` | 比衝鋒舟到岸晚多久到降落點 |
| `airlift.cruiseSpeedKt` | 倒推放飛時間用的巡航速度 |
| `airlift.cruiseAltitudeM` | 放飛後的巡航高度 |
| `airlift.arrivalNm` | 到降落點的判定距離 |

airlift 數值暫定，待遊戲內驗證（大型機轉彎半徑大，若轉不過去再設 airlift 專屬偏移）。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `schedule(tickCtx, zone, zoneState)` | `BOAT_ASSAULT` 開始時建立 CAS 任務與 `zoneState.heliWave`，算 `launchAt` |
| `update(tickCtx, zone, zoneState)` | 每 tick 推進；計畫尚未建立時什麼都不做 |

---

## 已知限制

- 不處理降落點的敵方威脅。
- 航線沒有設高度，使用單位的準則高度。
- 攻擊直升機被 CMO 任務帶回去降落、油彈用完但沒被擊毀時，筆數不會減少，也就不會補。
- 降落中心取自 `air.transportHelicopter.zone`。

---

## 相關模組

- [coordinator](coordinator.md) — 呼叫 `schedule`、`update`
- [amphibiousLogistics](amphibiousLogistics.md) — 裝貨與補運
- [laneGeometry](laneGeometry.md) — 座標轉換
- [assaultTimeline](assaultTimeline.md)
