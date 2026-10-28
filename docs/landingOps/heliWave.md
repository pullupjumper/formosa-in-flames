# heliWave — 直升機機波

> 原始碼：`src/modules/landingOps/heliWave.lua`

**職責**：從母艦手動放飛運輸直升機與攻擊直升機，沿左右翼進內陸。運輸直升機卸貨後返航；攻擊直升機走到門檻就指派進本區的 CAS 任務，之後交給 CMO

---

## 概述

一波 = 最多 `waveSize`（8）架運輸直升機，加上補到 `escortSize`（4）架為止的攻擊直升機。每區各自一組波次，所有區的大小相同。

運輸直升機**不指派 CMO 任務**：`Launch` 之後直接設 `course`，到點呼叫 `ScenEdit_UnloadCargo`。波數不設上限，直到沒有載貨的運輸機為止。

攻擊直升機同樣先走自己的航線，距降落點 `casAssignNm` 時指派進 CAS 任務。指派後腳本不再管它：不下 `RTB`，也不拿掉任務。

---

## 流程

```
BOAT_ASSAULT 開始  → schedule：建立本區 CAS 任務；估衝鋒舟到岸時間 T，倒推第一波放飛時間 launchAt
每 tick            → update：推進攻擊直升機與當前這一波運輸機；運輸機結束且到時間 → 放下一波
```

### 第一波放飛時間

`launchAt = max(現在, T − 飛行時間)`。

- **T**：最遠的衝鋒舟母艦航到就位帶外緣（`launchStationFarNm`），再加衝鋒舟從那裡跑到岸邊（`shoreStandoffM`）的時間。
- **飛行時間**：第一艘母艦沿左右翼較長者的航線長度 ÷ `cruiseSpeedKt`。
- 沒有配對衝鋒舟時，`T = 現在`，立刻放。

`GameUtils.isAfterStartTime(launchAt)` 判斷是否到了。第二波起不看時間，只看上一波是否結束。

### CAS 任務

`schedule` 建立 `CAS/HELI/<區名>`，類型 `patrol`、`type = "land"`，區域用 `air.attackHelicopter.zone`。類型是否等同想要的 CAS 尚待在 CMO 確認。

### 挑選

- 候選：本區 `mothership` 內 Type 075/076/071 上、`readytime_v == 0` 的直升機。
- 運輸直升機：DBID 相符且機上有 cargo。攻擊直升機：DBID 相符。
- 隨機挑，不足照飛。攻擊直升機只挑「`escortSize` 減去本區已記錄的架數」那麼多，已滿就不放。沒有任何有貨的運輸直升機時等下個 tick（貨由 `transferRemainingCargos` 補）。

### 航線

放飛後即分左右翼（依序輪流分配），沒有共同航線。每個點由 lane frame 的「縱向／橫向」座標算出：

1. 原地橫移到翼（橫向 ±`wingOffsetM`）
2. 沿翼飛到內陸 `inlandEntryM`
3. 轉向翼自己的降落點（降落區中心，橫向再偏 ±`landingSpreadM`）

### 每架的階段

| 角色 | 階段 |
|---|---|
| 運輸 | `enroute` → 距降落點 < `arrivalNm` 時 `UnloadCargo` → `unloading` → 卸完 `RTB(true)` → `returning` |
| 攻擊 | `enroute` → 距降落點 < `casAssignNm` 時指派進 CAS 任務 → `cas`（之後不再處理） |

- 卸完：`unit.condition == "Underway"`（且不是 `"Transfering Cargo"`）。字串是暫定，見 `constants.UNIT_CONDITIONS`，需對遊戲日誌校正。
- 被擊殺：`ScenEdit_GetUnit(guid)` 回 `nil`。

### 一波結束與逾時

這一波的運輸機每一架都是 `returning` 或已被擊殺，這一波就結束。攻擊直升機不算在內，不會卡住下一波。放飛後超過 `waveTimeoutSec` 仍未結束，剩下的運輸機全部 `RTB`，視為結束並記 WARN。

---

## 狀態

`zoneState.heliWave`（`SBJ__HeliWaveState`）：`units` 只存當前這一波的運輸機，下一波放飛時整個換掉；`attackers` 存本區的攻擊直升機，跨波保留。`attackers` 的筆數就是已算進 `escortSize` 的架數，不去查 CMO 任務。攻擊直升機被擊毀時，`destroyUnits.lua` 呼叫 `LandingOps.removeDestroyedAttackHelicopter` 依 GUID 移除。欄位見 `schema.lua`。

---

## 設定

`config.red.amphibOps.tuning.heliWave`：

| 欄位 | 用途 |
|---|---|
| `waveSize` | 每波運輸直升機架數（左右翼各半） |
| `escortSize` | 每區攻擊直升機總數（已進 CAS 的加飛往中的） |
| `waveTimeoutSec` | 一波的逾時 |
| `arrivalNm` | 運輸直升機到降落點的判定距離 |
| `casAssignNm` | 攻擊直升機離降落點多近就指派進 CAS 任務 |
| `cruiseSpeedKt` | 倒推放飛時間用的巡航速度 |
| `wingOffsetM`、`inlandEntryM`、`landingSpreadM` | 翼航線幾何 |

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `schedule(tickCtx, zone, zoneState)` | `BOAT_ASSAULT` 開始時建立 CAS 任務與 `zoneState.heliWave`，算 `launchAt` |
| `update(tickCtx, zone, zoneState)` | 每 tick 推進；計畫尚未建立時什麼都不做 |
| `removeAttacker(zoneState, guid)` | 移除被擊毀的攻擊直升機紀錄，回傳是否有移除 |

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
