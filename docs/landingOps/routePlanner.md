# routePlanner — 走通道的航線

> 原始碼：`src/modules/landingOps/routePlanner.lua`

**職責**：為衝鋒舟、兩棲車、氣墊船算出穿過已掃通道的航線，並預約停車位

---

## 概述

三種載具共用同一套規則，差別在**從哪裡放出**：

| 載具 | 入口 | 函式 |
|---|---|---|
| 氣墊船 | 母艦區，離通道很遠 | `buildRoute(params, { isFromDeployLine = true })` |
| 兩棲車 | 展開線艦艇的側邊 | `buildRoute(params)` |
| 衝鋒舟 | LST 側邊，走配對好的灘際通道 | `buildBoatRoute(beachLaneId, params)` |

模組除了呼叫端傳進來的 state（`queueCounters`、`laneSlots`）之外是純的，不碰遊戲 API。通道結構見 [laneGeometry](laneGeometry.md)。

---

## 選通道與排隊

1. **選水際通道**：只考慮至少有一條 `cleared` 灘際通道的水際通道。
   - 氣墊船（`sortWaterLanes`）用離放出位置的距離；差在 `laneTieNm` 內視為平手，改選負載少的
   - 兩棲車與衝鋒舟（`sortWaterLanesByLateral`）用**橫向**距離；差在 `laneTieM` 內才平手
2. **排隊入口點**：每條水際通道一個計數器 `k`（`zoneState.queueCounters`），每呼叫一次加 1。入口往外海退 `(k mod queueDepth) × columnSpacingM`，讓同時放出的單位不疊在同一點。
3. **選灘際通道**：只選 `cleared` 的，從 `k` 開始輪流。衝鋒舟例外，直接用配對的那條。
4. **停車位**：灘際通道從 E_lane 往 A_lane 每 `queueSpacingM` 一格，拿第一個空格。空格的定義：沒人、是自己，或佔位單位已被摧毀（`isAlive` 回 `false`）。格子滿換下一條灘際通道，再滿換下一條水際通道。
5. **航線**：`[入口點, (L_i), (A_i), A_lane, (S_lane), 停車位]`；括號內的點在特定條件下省略。氣墊船最前面多加展開線點。
6. **安全檢查**：航線碰到任何非 `cleared` 的方塊就換下一條，全部失敗回 `nil`。

兩棲車與氣墊船各有一套停車位表（`zoneState.laneSlots.acv`、`.hovercraft`），互不佔位。

### 為什麼兩棲車從側邊切入？

兩棲車從展開線艦艇的側邊放出。改用橫向距離選通道，單位就會選相鄰的通道，只橫移半個艦間空隙，不會穿過別艘船所在的間隙。入口點是放出位置投影到通道上，且不會比展開線更靠外海、不會比 A_i 更靠岸；`L_i`、`A_i` 若已在入口點後方（入口點比它更靠岸）就省略，所以不回頭。

### 為什麼 S_lane 有時被省略？

停車位在 S_lane 外海側時，單位根本不需要走到 S_lane，直接從 A_lane 停進格子即可（`buildSlotCourse` 比較格子離 E_lane 的距離與 S_lane 離 E_lane 的距離）。

### 為什麼衝鋒舟不檢查障礙？

`buildBoatRoute` 刻意忽略障礙狀態：衝鋒舟就是要上岸破障的那個單位。它的航線終點是 S_lane，不預約停車位。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `buildRoute(params, opts)` | 回傳 `SBJ__RoutePlanResult`（`course`、`waterLaneId`、`beachLaneId`、`slot`）或 `nil`；成功時已預約停車位 |
| `buildBoatRoute(beachLaneId, params)` | 衝鋒舟航線；灘際通道 id 不存在回 `nil` |
| `sortWaterLanes`、`sortWaterLanesByLateral`、`selectWaterLane` | 選通道的排序 |
| `findBeachLane(lanes, id)`、`findFreeSlot(beachLane, slots, params)` | 查詢 |

---

## 設定

`config.red.amphibOps.tuning.route`：`laneTieNm`、`laneTieM`、`columnSpacingM`、`queueDepth`、`queueSpacingM`。到達判斷的 `arrivalNm` 由各呼叫端模組使用。

---

## 相關模組

- [laneGeometry](laneGeometry.md) — 通道結構與碰撞判斷
- [assaultBoat](assaultBoat.md)、[hovercraft](hovercraft.md) — 直接呼叫；兩棲車經門面 `launchACV` 的 `routeACV` 回呼間接呼叫（見 [README](README.md#為什麼-launchacv-要在門面組裝)）
- [系統架構](README.md)
