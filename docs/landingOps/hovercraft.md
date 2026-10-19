# hovercraft — 氣墊船走通道

> 原始碼：`src/modules/landingOps/hovercraft.lua`

**職責**：把母艦上已裝貨的 Type 726A 氣墊船送進 cleared 通道，到停車位後指定貨運任務

---

## 概述

氣墊船從 075、076、071（`MOTHERSHIP_DBIDS`，須在 `holdingAreas.mothership` 內）放出，載重裝備到灘頭。它**只走一次通道**，到了停車位就交給貨運任務。

```mermaid
flowchart TD
    GATE["第一波車已放滿"] --> LAUNCH["launchHovercraft"] --> UPDATE["updateHovercraft"]
```

[coordinator](coordinator.md) 的 `stepHovercraft` 在 `ASSAULT_LANDING` 起的每個 tick 執行：`launchHovercraft` 受 [acvWave](acvWave.md) 的 `isFirstWaveFull` 把關，`updateHovercraft` 每 tick 都跑。

---

## 放出

`launchHovercraft` 對每艘母艦找「可放」的氣墊船（`findReadyHovercraft`）：還沒登記在 `zoneState.hovercraft`、DBID 是 `TYPE_726A`、`readytime_v == 0`、艙內有貨。

對每艘：

1. `RoutePlanner.buildRoute(..., { isFromDeployLine = true })` 算航線並預約停車位（氣墊船自己一套 `laneSlots.hovercraft`）
2. 成功：設 `course`、`manualSpeed`，再 `Launch(true)`（**先 course 再 Launch**），登記 `zoneState.hovercraft[guid] = { missionName, finalPoint, arrived = false }`
3. 沒有可用通道或停車位：記 SKIP（`no_cleared_lane_slot`）。這艘不會登記，**下個 tick 再試**

沒有 `zoneState.lanes` 時整個函式直接返回。

### 貨運任務怎麼分配？

`findMissionName` 依 `zone.landing.hovercraft.missions` 的順序，找第一個已登記氣墊船數未達 `unitCount` 的任務；全滿就用最後一個。分配在**放出時**決定，不是到達時。

### 為什麼等待區不指派氣墊船任務？

氣墊船必須先走 cleared 通道到停車位，才能開始運貨。所以 [amphibiousLogistics](amphibiousLogistics.md) 只替氣墊船裝貨，通道走完才在這裡設任務；`boat` 類別的任務開始時間也不再設定。

---

## 到達

`updateHovercraft` 對每艘未到達的氣墊船檢查離 `finalPoint` 的距離，小於 `tuning.route.arrivalNm` 就標 `arrived = true` 並設 `unit.mission = entry.missionName`。程式碼內仍留有 TODO，指出貨運任務的細部指派（依 `unitCount` 分配）預期由使用者補完。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `launchHovercraft(amphibOps, zone, zoneState, ships)` | 放出可放的氣墊船 |
| `updateHovercraft(amphibOps, zoneState)` | 追蹤到達並設任務 |

---

## 設定

| 路徑 | 用途 |
|---|---|
| `zones[].landing.hovercraft` | `speed`、`missions[]`（`name`、`unitCount`） |
| `tuning.route.arrivalNm` | 到達判斷 |
| `tuning.acvWave.hovercraftWaitSec` | 等第一波的上限，見 [acvWave](acvWave.md) |

運量與航行時間推算見 [hovercraftCapacity](hovercraftCapacity.md)。

---

## 相關模組

- [routePlanner](routePlanner.md) — 航線與停車位
- [amphibiousLogistics](amphibiousLogistics.md) — 裝貨
- [debugFlow](debugFlow.md) — `teleportLanding` 時直接瞬移到停車位
- [系統架構](README.md)
