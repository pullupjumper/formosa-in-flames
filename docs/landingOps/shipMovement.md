# shipMovement — 登陸艦隊移動與佈陣

> 原始碼：`src/modules/landingOps/shipMovement.lua`

**職責**：預算各型登陸艦的等待位置，並驅動艦隊與 SAG 從集結區移動到陣位

---

## 概述

shipMovement 是登陸作戰的第一階段。登陸艦從集結區（`fleet.stagingArea`）移動到等待區（`movement.holdingAreas`：登陸母艦乘載區 `mothership`、登陸艦艇展開線 `deployLine`），每型艦占一列，形成分層編隊。

位置分兩步算：

1. 開局由門面 `LandingOps.init` 呼叫 `buildHoldingPositions`，把每區每列的位置陣列寫入 `calculationResult`（型別 `SBJ__OperationZoneCalculationState`，見 `schema.lua`）
2. 每次 `moveToHoldingAreas` 把集結區內的艦依序派到所屬列的下一個位置，並推進該列的 `locationIndex`

SAG（水面行動群）護航編隊另外處理，以驅逐艦為中心、護衛艦在左右翼。

---

## 艦型分層佈局

以 Type 075 的參考點（`fleet.groups[].to.startingPoint`）為起點，其餘列依 `SHIP_ROW_LAYOUT` 逐列往海岸方向推算。一列內的艦沿 `heading - rowBearingOffset` 排開，間距 `horizontalDistanceNm`。

```
 登陸母艦乘載區（mothership）
   type075  → [075] [075] ...
   type071  → [071] [071] ...
   type076  → [076] [076] ...
        ↕ deployLineSetbackNm
 登陸艦艇展開線（deployLine）
   barge → roro → ferry → type072a → type072iii → type073a → type082
```

只有 `barge` 相對 `type075` 用 `deployLineSetbackNm`，其餘列相對前一列用 `verticalDistanceNm`。列的順序以程式碼的 `SHIP_ROW_LAYOUT` 為準。

### 為什麼要比對兩次（DBID、再名稱）？

Ferry、RORO、Barge 三者在 `SHIP_ROWS` 裡有的共用同一個 DBID（Ferry 與 RORO 都是 `PLATFORMS.FERRY`），只能靠單位名稱分辨。`findShipRowKey` 先找沒有 `name` 欄位的列（DBID 比對），沒中再找有 `name` 的列，所以名稱列不會搶走一般艦的 DBID。都沒中就 SKIP（`reason=unmatched`），例如拖船。

---

## SAG 護航編隊

`moveSag` 讓 SAG 群組沿 `to.holdingArea` 航行。快轉模式（見 [debugFlow](debugFlow.md)）時改成直接瞬移並排好陣型，由 `teleportSagToFormation` 完成；[amphibiousAssault](amphibiousAssault.md) 的 SAG 就位也共用它。

| 艦型 | 位置 |
|---|---|
| 052D 第一艘 | 等待區終點（編隊中心） |
| 052D 其餘 | 中心後方（`heading - 180`）1.5 nm |
| 054A 第一艘／第二艘 | 左翼／右翼，偏離 45°、距中心 1.5 nm |

---

## 日誌與回傳值

`moveToHoldingAreas` 用單一 `LogFormat.report` 收集艦船與 SAG 兩段結果，回傳值由 `LogFormat.hasFailure(results)` 從結果推導，不另外維護旗標。回傳 `true` 表示命令全部發出，不代表艦已到位；到位判斷在 [amphibiousLogistics](amphibiousLogistics.md) 的 `getUnitsInHoldingAreas`。

```
[shipMovement] operation=Taoyuan: Move to holding areas | total=4 ok=3 skip=1
  [OK]   ship="Type 075 #1" dbid=3556 dest=type075 index=1
  [SKIP] ship=Tugboat dbid=1044 reason=unmatched
  [OK]   sag="SAG Alpha" action=course_set positioned=3 skipped=0
```

`buildHoldingPositions` 的前置計算失敗屬於單筆事件，走 `LogFormat.line` 直接送 error sink，並回傳 `false`。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `buildHoldingPositions(zones, formation, calculationResult)` | 預算所有作戰區的等待位置 |
| `moveToHoldingAreas(zone, calculationResult, filteredUnits, amphibOps)` | 單一作戰區的艦隊與 SAG 移動 |
| `teleportSagToFormation(sagUnit, holdingPoint, heading)` | SAG 瞬移並排陣型（快轉專用，與 amphibiousAssault 共用） |

---

## 設定

| 路徑 | 用途 |
|---|---|
| `config.red.amphibOps.formation` | `deployLineSetbackNm`、`horizontalDistanceNm`、`verticalDistanceNm`、`rowBearingOffset`、`shipSpeed` |
| `config.red.amphibOps.zones[].fleet` | `stagingArea`、`groups[]`（起點與各型艦數 `shipCounts`） |
| `config.red.amphibOps.zones[].sags[]` | SAG 群組名稱與 `to.holdingArea` |

---

## 相關模組

- [amphibiousLogistics](amphibiousLogistics.md) — 艦隊到位後的貨物裝載
- [amphibiousAssault](amphibiousAssault.md) — 下一步：LST 前進到泛水出發線
- [debugFlow](debugFlow.md) — 快轉時改為瞬移
- [系統架構](README.md)
