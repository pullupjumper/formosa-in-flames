# shipMovement — 登陸艦隊移動與佈陣

> 原始碼：`src/modules/landingOps/shipMovement.lua`

**職責**：計算各型登陸艦的等待位置並驅動艦隊從集結區移動至預定陣位

---

## 概述

shipMovement 負責登陸作戰的第一階段——艦隊展開。系統將各型登陸艦（LHD/LPD/LST/渡輪/駁船/RORO）從集結區（Staging Area）移動至等待區（Holding Areas：登陸母艦乘載區、登陸艦艇展開線），每型艦船在等待區中佔據不同的列位置，形成分層編隊。

位置計算分為兩步：首先透過 `planHoldingPositions` 預算所有等待位置，結果儲存至 `saveData.red.amphibOps.calculationResult`；接著 `moveToHoldingAreas` 在每次觸發時依序將集結區內的艦船分配至下一個可用位置。

SAG（水面行動群）護航編隊則獨立處理，以驅逐艦為中心、護衛艦左右翼展開陣型。

---

## 艦型分層佈局

等待區的艦船佈局以兩個基準點為起始，其餘艦型依垂直距離依序排列：

```
                       ← 水平方向（horizontalDistance）→

  登陸母艦乘載區 (mothership):
  Type 075 起始點 ──→  [075] [075] [075] ...
  Type 071 起始點 ──→  [071] [071] [071] ...
  Type 076          →  [076] [076] ...
                        ↕ deployLineSetback
  登陸艦艇展開線 (deployLine):
  Barge             →  [Barge] [Barge] ...
  RORO              →  [RORO] [RORO] ...
  Type 072A         →  [072A] [072A] ...
  Type 072III       →  [072III] [072III] ...
  Ferry             →  [Ferry] [Ferry] ...
  Type 071 (溢出)   →  [071] ...
  Type 073A         →  [073A] [073A] ...
```

### 列排列順序

| 順序 | 艦型 key | 基準來源 | 距離參數 |
|:-:|---|---|---|
| 1 | `type075` | 參考點 `startingPoints.type075` | — |
| 2 | `type071` | 參考點 `startingPoints.type071` | — |
| 3 | `type076` | 相對 `type071` | `verticalDistance` |
| 4 | `barge` | 相對 `type075` | `deployLineSetback` |
| 5 | `roro` | 相對 `barge` | `verticalDistance` |
| 6 | `type072a` | 相對 `roro` | `verticalDistance` |
| 7 | `type072iii` | 相對 `type072a` | `verticalDistance` |
| 8 | `ferry` | 相對 `type072iii` | `verticalDistance` |
| 9 | `type071OnDeployLine` | 相對 `ferry` | `verticalDistance` |
| 10 | `type073a` | 相對 `type071OnDeployLine` | `verticalDistance` |

---

## 位置計算流程

```mermaid
flowchart TD
    START["planHoldingPositions()"]
    ITER_OP["遍歷 operations"]
    ITER_AREA["遍歷 zone.fleet.groups"]
    INIT["initOperationResult<br>初始化結果結構"]
    CALC_SP["calculateStartingPoints<br>取得兩基準參考點<br>依 SHIP_ROW_LAYOUT 推算各列起始點"]
    GEN_LOC["buildAllShipLocations<br>對每列依水平間距生成 N 個位置"]
    STORE["儲存至 calculationResult"]

    START --> ITER_OP --> ITER_AREA --> INIT --> CALC_SP --> GEN_LOC --> STORE
    STORE -.-> ITER_AREA
```

---

## 艦船匹配與移動

`moveToHoldingAreas` 透過 `moveMatchingShip` 進行艦型匹配：

1. **DBID 匹配**：依 `SHIP_TYPE_DBIDS` 表比對艦船 DBID
2. **名稱匹配**：若 DBID 未命中，依 `NAME_TO_KEY` 表比對艦名（Ferry/RORO/Barge）
3. **Type 071 特殊處理**：當乘載區位置用盡時，溢出至展開線的 `type071OnDeployLine`

```mermaid
flowchart TD
    UNIT["艦船單元"]
    DBID_CHECK{DBID 匹配?}
    IS_071{是 Type 071?}
    NAME_CHECK{名稱匹配?}
    MOVE_071["moveType071<br>（含溢出邏輯）"]
    MOVE_NORMAL["moveShipToNextLocation"]
    MOVE_NAME["moveShipToNextLocation<br>（依名稱 key）"]
    SKIP["SKIP: 未匹配"]

    UNIT --> DBID_CHECK
    DBID_CHECK -->|是| IS_071
    IS_071 -->|是| MOVE_071
    IS_071 -->|否| MOVE_NORMAL
    DBID_CHECK -->|否| NAME_CHECK
    NAME_CHECK -->|是| MOVE_NAME
    NAME_CHECK -->|否| SKIP
```

---

## SAG 護航編隊

`processSAG` 將 SAG 編隊移動至等待區，測試模式下以精確陣位佈置：

| 艦型 | 位置 | 說明 |
|---|---|---|
| Type 052D（第一艘） | 等待區終點 | 編隊中心 |
| Type 052D（第二艘） | 終點後方 1.5nm | 縱列跟隨 |
| Type 054A（第一艘） | 左翼 -45° × 1.5nm | 左翼護衛 |
| Type 054A（第二艘） | 右翼 +45° × 1.5nm | 右翼護衛 |

---

## 公開 API

| 函數 | 說明 |
|---|---|
| `planHoldingPositions(zones, formationSettings, calculationResult)` | 計算所有作戰區域的艦船等待位置 |
| `moveToHoldingAreas(zone, calculationResult, filteredUnits, amphibOps)` | 驅動艦隊從集結區移動至等待位置（單一作戰區） |

---

## 日誌輸出

`moveToHoldingAreas` 用單一 `LogFormat.report` 收集艦船與 SAG 兩段結果，回傳值由 `containsFailure(results)` 從 row 推導，不另外維護旗標。

```
[shipMovement] operation=Taoyuan Landing: Move to holding areas | total=4 ok=3 skip=1
  [OK]   ship="Type 075 #1" dbid=3556 index=1 dest=type075
  [OK]   area=LPD ship="Type 071 #2" dbid=2340 index=2 dest=type071
  [SKIP] ship=Tugboat dbid=1044 reason=unmatched
  [OK]   sag="SAG Alpha" action=course_set positioned=3 skipped=0
```

`planHoldingPositions` 的前置計算失敗屬於單筆事件而非批次，走 `LogFormat.line` 直接送 error sink。

---

## 相關模組

- [amphibiousLogistics](amphibiousLogistics.md) — 艦隊到達後的貨物裝載與任務建立
- [amphibiousAssault](amphibiousAssault.md) — LST 航至泛水編波區的航向設定
- [系統架構](README.md)
