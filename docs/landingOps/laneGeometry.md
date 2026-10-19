# laneGeometry — 通道幾何

> 原始碼：`src/modules/landingOps/laneGeometry.lua`

**職責**：純函式。把登陸區的水際／灘際通道、掃雷弓字型、雷格、障礙方塊都換算成經緯度，並判斷航線是否碰到障礙

---

## 概述

laneGeometry 不呼叫任何遊戲 API，輸入輸出都是座標與 table，所以可以直接單元測試。範圍只有登陸區附近數公里，因此用平面近似（每度 111320 m，經度乘 `cos(緯度)`），不做球面計算。

所有位置都用一組 **lane 座標**表示（`SBJ__LaneFrame`：`origin` 與 `bearing`）：

- `alongM`：從原點朝岸的距離，負值是外海
- `lateralM`：朝岸方向的右側距離

`origin` 是 `landing.laneCenter`（岸邊一點），`bearing` 是 `zone.heading`。`buildPoint` 與 `projectPoint` 互為反函式。

---

## 通道結構

`buildLanes` 為每艘 Type 082 建一條**水際通道**（battalion），每條水際通道下有數條**灘際通道**：

水際通道依序經過展開線、泛水出發線、衝擊發起線；從衝擊發起線起分出數條灘際通道，各自從 A_lane 經 S_lane 到 E_lane。

| 點 | 意義 | 距岸（`tuning.route`） |
|---|---|---|
| `deployPoint` | 登陸艦艇展開線 | `deployLineNm` |
| `launchPoint`（L_i） | 泛水出發線 | `launchLineNm` |
| `assaultPoint`（A_i） | 衝擊發起線 | `assaultLineNm` |
| 灘際 `assaultPoint`（A_lane） | 灘際通道起點，橫向偏移 `beachLaneOffsetsM` | 同 A_i |
| `shorePoint`（S_lane） | 灘際通道岸端 | `shoreStandoffM` |
| `endPoint`（E_lane） | 灘際通道內陸端，超出障礙範圍 `inlandMarginM` | `calculateInlandDepthM` + margin |

每條水際通道另有：

- `sweepCourse`：展開線點 → L_i → A_i，再接**弓字型**（`buildSerpentine`：A→S、S→S、S→A、A→A…），082 照這條路線掃雷
- `missionArea`：包住整條水際通道的四角矩形，寬度為最外側灘際通道偏移加 `areaMarginM`，供使用者建立掃雷任務

灘際通道有 `isCleared` 旗標，初始為 `false`，由 [obstacleClearing](obstacleClearing.md) 在破障結束時設為 `true`。

### 水際通道的橫向位置怎麼定？

兩種方式，`buildLanes` 依 `params.laterals` 是否提供而定：

1. **艦間空隙**：`buildWaterLaneLaterals` 取展開線 LST 之間寬度至少 `waterLaneMinSpacingM` 的空隙中點為候選，選連續 `count` 個、相鄰間距在 `[waterLaneMinSpacingM, waterLaneMaxSpacingM]` 內、整體最靠近中心的一組。這樣通道不會穿過船體。
2. **均勻備援**：沒有 LST 或空隙排不出時回 `nil`，改用 `waterLaneSpacingM` 對稱於中心均勻排開。「排不出」會由 [mineClearing](mineClearing.md) 記 WARN。

---

## 雷格

`buildMineCorridors` 把每條水際通道（展開線到衝擊發起線）和灘際通道（衝擊發起線到 S_lane）切成與通道中心線對齊、一格寬的方格，相鄰通道不重疊。`findMineCell` 先比對各 corridor 邊界再直接索引方格。這只用於快轉時刪除通道內的雷（見 [debugFlow](debugFlow.md)），方格**不存檔**，需要時重建。

---

## 障礙方塊

`buildObstacleCells` 以 `cellSizeM` 邊長的方塊鋪滿障礙多邊形，保留中心點落在多邊形內的方塊，初始狀態 `intact`。多邊形由玩家在 control panel 畫在藍方，方塊只存在 state 裡，不畫在 CMO 地圖上。

航線通過判斷：

- `segmentsIntersect`：兩線段相交，**含相切**
- `isSegmentTouchingCell`：線段碰到方塊任一條邊
- `isRouteClear(route, cells)`：航線的每一段只要碰到一個非 `cleared` 的方塊就不通過；`cells` 為 `nil` 視為通過

### 為什麼相切也算碰到？

航線沿著方塊邊緣走和穿過方塊，對 CMO 的單位來說都會經過那塊障礙。保守地算碰到，寧可換下一條通道。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `buildPoint(frame, alongM, lateralM)`、`projectPoint(frame, pos)` | lane 座標與經緯度互轉 |
| `calculateDistanceM(a, b)`、`interpolate(a, b, fraction)` | 近距離距離與內插 |
| `buildWaterLaneLaterals(shipLaterals, count, routeConfig)` | 依艦間空隙排通道橫向位置 |
| `buildLanes(params)` | 建全部通道，回傳 `SBJ__LanePlanState` |
| `calculateInlandDepthM(frame, polygon)` | 多邊形朝岸最深的距離 |
| `buildMineCorridors(lanes, cellSizeM)`、`findMineCell(frame, corridors, pos)` | 雷格 |
| `buildObstacleCells(frame, polygon, cellSizeM)` | 障礙方塊 |
| `segmentsIntersect`、`isSegmentTouchingCell`、`isRouteClear` | 碰撞判斷 |

---

## 設定

通道距離參數集中在 `config.red.amphibOps.tuning.route`（型別 `SBJ__RouteConfig`），數值與單位以 `config.lua` 的行內註解為準；方塊邊長是 `tuning.obstacle.cellSizeM`。

---

## 相關模組

- [routePlanner](routePlanner.md) — 在通道上排航線
- [mineClearing](mineClearing.md) — 建立通道並派 082
- [obstacleClearing](obstacleClearing.md) — 使用障礙方塊
- [assaultTimeline](assaultTimeline.md) — 通道規格的原文依據
- [系統架構](README.md)
