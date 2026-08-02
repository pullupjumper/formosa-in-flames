# movement.lua

機動車組機動與狀態轉換模組。

> Source: `src/modules/missileSystem/movement.lua`

責任摘要：統一封裝到 FP/HA/RL/AHA 的移動命令與狀態切換。

---

## 概觀

`movement.lua` 把路徑移動與武器管制設定集中處理，避免各流程重複拼接 `ScenEdit_SetUnit` / Doctrine 參數。所有移動最終都透過 `moveUnitToPosition` 執行。

當狀態改變時，會同步更新 `unitCtx.state` 與 `reloadStartTime`，確保 `cycle.lua` 可用同一套條件運算。

在玩家控制流程下，`isRepositioning` 會直接回傳 true，讓事件流程更寬鬆地接受玩家操作。

---

## 主要機制

- 隨機挑選 `operationalArea` 中某個陣地並賦予 course。
- `setReloadStartTime` 進入 `RELOAD` 並鎖定 `WCS.HOLD`。
- `setWCSToFree` 進入 `STATIC` 並切換 `WCS.FREE`。
- `setStateToHide` 進入 `HIDE`。

```mermaid
flowchart LR
    MOVE[moveUnitToPosition] --> RL[moveToReloadPoint]
    MOVE --> HA[moveToHideArea]
    MOVE --> FP[moveToFiringPoint]
    MOVE --> AHA[moveToAmmoHoldingArea]

    RL --> S1[state=REPOSITIONING]
    HA --> S1
    FP --> S1
    AHA --> S1

    X1[setReloadStartTime] --> S2[state=RELOAD]
    X2[setWCSToFree] --> S3[state=STATIC]
    X3[setStateToHide] --> S4[state=HIDE]
```

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `moveUnitToPosition` | `opts` | `boolean, table?` | 共用移動執行器 |
| `moveToReloadPoint` | `unitCtx, unit` | `boolean, table?` | 移動至 RL |
| `moveToHideArea` | `firingUnitCtx, firingUnit` | `boolean, table?` | 移動至 HA |
| `moveToAmmoHoldingArea` | `resupplyUnitCtx, resupplyUnit` | `boolean, table?` | 移動至 AHA |
| `moveResupplyUnitToReloadPoint` | `resupplyUnitCtx, resupplyUnit` | `boolean, table?` | 彈藥補給車回 RL |
| `moveToFiringPoint` | `firingUnitCtx, firingUnit` | `boolean, table?` | 移動至 FP |
| `setReloadStartTime` | `firingUnitCtx, firingUnit, isAuto` | `nil` | 設 `RELOAD` 與起始時間 |
| `setWCSToFree` | `firingUnitCtx, firingUnit, isAuto` | `nil` | 設 `STATIC` + `WCS.FREE` |
| `setStateToHide` | `firingUnitCtx, firingUnit, isAuto` | `nil` | 設 `HIDE` + `WCS.HOLD` |
| `setStateToStatic` | `systemCtx, firingUnit, isAuto` | `nil` | 清空 reload timer 並設 `STATIC` |
| `isRepositioning` | `firingUnitCtx, isAuto` | `boolean` | 判斷事件是否可接受 |

移動失敗時第二個回傳值是 log 欄位表而非散文訊息，呼叫端直接併進自己的 row：

| `reason` | 附帶欄位 | 情境 |
|---|---|---|
| `no_positions_available` | `position`、`area` | 該陣地類型未設定任何位置 |
| `invalid_position_data` | `position`、`index`、`area` | 抽中的位置缺少 `course` |
| `no_ha_defined` | `area` | `operationalArea.HA` 未定義 |

欄位不含 `unit`：六個呼叫端都已自行標上 `unit=`，識別欄位歸呼叫端、失敗原因歸 producer。

---

## 相關模組

- [shared](shared.md)
- [init](init.md)
- [cycle](cycle.md)
