# amphibiousLogistics — 兩棲後勤裝載與任務指派

> 原始碼：`src/modules/landingOps/amphibiousLogistics.lua`

**職責**：偵測艦隊是否到位、建立貨運任務、把貨物轉進搭載的載具並指派直升機任務

---

## 概述

艦隊到達等待區後，系統依艦型把貨物（車輛、步兵、裝備）從母艦轉到搭載的直升機與氣墊船，同時建立 Cargo 任務。

分派是**資料驅動**的：`SHIP_TRANSFER_SPECS` 以艦型 DBID 描述「轉哪些貨到哪些載具」與「指派哪些載具進任務」，不為每型艦寫硬編碼。新增艦型只要加一筆 spec，貨物清單本身在各區 `config` 的 `transferManifest`。

| 艦型 | manifestKey | 轉貨目標 | 指派任務 |
|---|---|---|---|
| 075、076 | `type075` | 氣墊船（loadout 1）、運輸直升機（loadout 1、2） | 運輸直升機、攻擊直升機 |
| 071 | `type071` | 氣墊船（loadout 1）、運輸直升機（loadout 1） | 運輸直升機 |

### 為什麼氣墊船只裝貨、不指派任務？

氣墊船要先走掃出來的通道到停車位，才能開始運貨。所以這裡只轉貨（`transfers`），`assignments` 刻意不含氣墊船；通道走完後由 [hovercraft](hovercraft.md) 設定其任務。對應地，貨運任務在這裡只為氣墊船與運輸直升機建立（`CARGO_MISSION_PLATFORMS`），攻擊直升機的任務（如 `CAS/E`）不在這裡建立，這裡只指派載具，開始時間由 [amphibiousAssault](amphibiousAssault.md) 設定。

---

## 轉貨機制

私有函式 `transferCargo` 把母艦貨物分給符合條件的搭載載具：

1. 讀母艦的 `embarkedUnits[platformType]`
2. 以 DBID（航空器再加 `loadoutdbid`）篩出目標載具
3. 對每個目標呼叫 `transferCargoItem`：從母艦刪除貨物，在載具上建立同數量的貨物
4. 貨物清單可以共用，也可以依載具序號分配

### 為什麼載具序號超過清單長度時退回第一組？

`transferCargo` 用 `cargoItems[idx] or cargoItems[1]`。若 075 有第 4 艘氣墊船而 manifest 只有 3 組，第 4 艘會再拿到第 1 組的貨，不是空手。這是行為而非保護，排兵力時要注意，推算見 [hovercraftCapacity](hovercraftCapacity.md)。

---

## 到位偵測

`getUnitsInHoldingAreas(zone, filteredUnits)` 回傳 `{ units, isUnitMoving }`，供 [coordinator](coordinator.md) 判斷是否離開 `WAITING_ARRIVAL`。

- 只看 `AMPHIBIOUS_SHIP_DBIDS` 內的兩棲艦
- 艦在本區等待區**或**本區集結區，且 `unitstate ~= "Unassigned"`，就判定仍在移動並立刻中止掃描
- 只有在等待區內且已停妥的艦才進 `units`

### 為什麼集結區的艦也要算「還在動」？

`filteredUnits` 涵蓋全部三個區的艦。若只看等待區，其他區的艦或本區尚未出發的艦不會擋住到位判定，貨物會在艦隊沒到齊時就裝載。反過來只有「本區等待區或集結區」的艦才有資格延遲本區，避免別區拖累本區。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `getUnitsInHoldingAreas(zone, filteredUnits)` | 到位偵測 |
| `createCargoMissions(zone)` | 建立貨運任務，遇到第一個失敗即停止 |
| `transferAndAssign(zone, unitsInHoldingAreas)` | 只處理在 `mothership` 內的艦：轉貨並指派 |
| `transferAndAssignTransportAircraft(transportAircraft)` | 陸基運輸機轉貨並指派 |
| `transferRemainingCargos(zone, units)` | 補運：重新轉貨，**不重新指派**任務 |
| `removeCargo(fromUnit, cargoItem)` | 從單位刪除貨物，回傳實際刪除數；ACV 釋放使用 |

`createCargoMissions` 的失敗帶 `reason`：`add_mission_failed`、`set_mission_failed`、`set_doctrine_failed`；已建立的任務留在 info log，失敗行走 error sink。

---

## 設定

| 路徑 | 用途 |
|---|---|
| `config.red.amphibOps.zones[].landing.hovercraft` | 氣墊船 DBID、貨運任務清單、`transferManifest` |
| `config.red.amphibOps.zones[].air.transportHelicopter`、`attackHelicopter` | 直升機 DBID、任務、`transferManifest` |
| `config.red.amphibOps.zones[].movement.holdingAreas` | `mothership`、`deployLine` |
| `config.red.amphibOps.transportAircraft` | 陸基運輸機清單 |

---

## 相關模組

- [shipMovement](shipMovement.md) — 前置：艦隊移動
- [amphibiousAssault](amphibiousAssault.md) — `launchACV` 呼叫 `removeCargo`
- [hovercraft](hovercraft.md) — 接手氣墊船的任務
- `assignMission` — `AssignMission.assignEmbarkedUnitsToMissions`，見 [assignMission](../assignMission.md)
- [系統架構](README.md)
