# heliWave — 直升機機波

> 原始碼：`src/modules/landingOps/heliWave.lua`

**職責**：從母艦手動放飛運輸直升機與攻擊直升機，沿左右翼進內陸，卸貨後返航，一波結束才放下一波

---

## 概述

一波 = 最多 `waveSize`（8）架運輸直升機 + `escortSize`（4）架攻擊直升機。每區各自一組波次，所有區的大小相同。

直升機**不指派 CMO 任務**：`Launch` 之後直接設 `course`，到點呼叫 `ScenEdit_UnloadCargo`。波數不設上限，直到沒有載貨的運輸機為止。

---

## 流程

```
BOAT_ASSAULT 開始  → schedule：估衝鋒舟到岸時間 T，倒推第一波放飛時間 launchAt
每 tick            → update：推進當前這一波；這一波結束且到時間 → 放下一波
```

### 第一波放飛時間

`launchAt = max(現在, T − 飛行時間)`。

- **T**：最遠的衝鋒舟母艦航到就位帶外緣（`launchStationFarNm`），再加衝鋒舟從那裡跑到岸邊（`shoreStandoffM`）的時間。
- **飛行時間**：第一艘母艦沿左右翼較長者的航線長度 ÷ `cruiseSpeedKt`。
- 沒有配對衝鋒舟時，`T = 現在`，立刻放。

`GameUtils.isAfterStartTime(launchAt)` 判斷是否到了。第二波起不看時間，只看上一波是否結束。

### 挑選

- 候選：本區 `mothership` 內 Type 075/076/071 上、`readytime_v == 0` 的直升機。
- 運輸直升機：DBID 相符且機上有 cargo。攻擊直升機：DBID 相符。
- 隨機挑，不足照飛。沒有任何有貨的運輸直升機時等下個 tick（貨由 `transferRemainingCargos` 補）。

### 航線

放飛後即分左右翼（依序輪流分配），沒有共同航線。每個點由 lane frame 的「縱向／橫向」座標算出：

1. 原地橫移到翼（橫向 ±`wingOffsetM`）
2. 沿翼飛到內陸 `inlandEntryM`
3. 轉向翼自己的降落點（降落區中心，橫向再偏 ±`landingSpreadM`）

### 每架的階段

| 角色 | 階段 |
|---|---|
| 運輸 | `enroute` → 距降落點 < `arrivalNm` 時 `UnloadCargo` → `unloading` → 卸完 `RTB(true)` → `returning` |
| 攻擊 | `enroute` → 到點 `loitering` → 同波運輸全部卸完或被擊殺 → `RTB(true)` → `returning` |

- 卸完：`unit.condition == "Underway"`（且不是 `"Transfering Cargo"`）。字串是暫定，見 `constants.UNIT_CONDITIONS`，需對遊戲日誌校正。
- 被擊殺：`ScenEdit_GetUnit(guid)` 回 `nil`。

### 一波結束與逾時

每一架都是 `returning` 或已被擊殺，這一波就結束。放飛後超過 `waveTimeoutSec` 仍未結束，剩下的全部 `RTB`，視為結束並記 WARN。波次表放完且最後一波結束，`isFinished = true`。

---

## 狀態

`zoneState.heliWave`（`SBJ__HeliWaveState`）：只存當前這一波，下一波放飛時整個換掉。欄位見 `schema.lua`。

---

## 設定

`config.red.amphibOps.tuning.heliWave`：

| 欄位 | 用途 |
|---|---|
| `waveSize`、`escortSize` | 每波運輸／攻擊直升機架數（左右翼各半） |
| `waveTimeoutSec` | 一波的逾時 |
| `arrivalNm` | 到降落點的判定距離 |
| `cruiseSpeedKt` | 倒推放飛時間用的巡航速度 |
| `wingOffsetM`、`inlandEntryM`、`landingSpreadM` | 翼航線幾何 |

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `schedule(tickCtx, zone, zoneState)` | `BOAT_ASSAULT` 開始時建立 `zoneState.heliWave`，算 `launchAt` |
| `update(tickCtx, zone, zoneState)` | 每 tick 推進；計畫尚未建立時什麼都不做 |

---

## 已知限制

- 不處理降落點的敵方威脅。
- 航線沒有設高度，使用單位的準則高度。
- 攻擊直升機到點後是否會在原地盤旋，取決於 CMO 對航線終點的行為，需實測。

---

## 相關模組

- [coordinator](coordinator.md) — 呼叫 `schedule`、`update`
- [amphibiousLogistics](amphibiousLogistics.md) — 裝貨與補運
- [laneGeometry](laneGeometry.md) — 座標轉換
- [assaultTimeline](assaultTimeline.md)
