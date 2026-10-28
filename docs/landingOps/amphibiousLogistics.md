# amphibiousLogistics — 兩棲後勤裝載

> 原始碼：`src/modules/landingOps/amphibiousLogistics.lua`

**職責**：偵測艦隊是否到位、把貨物轉進搭載的載具

---

## 概述

艦隊到達等待區後，系統依艦型把貨物（車輛、步兵、裝備）從母艦轉到搭載的直升機與氣墊船。

分派是**資料驅動**的：`SHIP_TRANSFER_RULES` 以艦型 DBID 描述「轉哪些貨到哪些載具」，不為每型艦寫硬編碼。新增艦型只要加一筆 spec，貨物清單本身在各區 `config` 的 `transferManifest`。

| 艦型 | manifestKey | 轉貨目標 |
|---|---|---|
| 075、076 | `type075` | 氣墊船（loadout 1）、運輸直升機（loadout 1、2） |
| 071 | `type071` | 氣墊船（loadout 1）、運輸直升機（loadout 1） |

### 為什麼這裡不指派任務？

這個模組只轉貨，不指派任何任務，陸基運輸機也一樣。氣墊船由 [hovercraft](hovercraft.md) 走通道、到停車位卸貨；直升機由 [heliWave](heliWave.md) 手動放飛、給航線、卸貨；攻擊直升機到門檻後由 heliWave 指派進 CAS 任務。

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
| `transfer(zone, unitsInHoldingAreas)` | 只處理在 `mothership` 內的艦：轉貨 |
| `transferTransportAircraftCargo(transportAircraft)` | 單一陸基運輸機轉貨 |
| `transferRemainingCargos(zone, units)` | 補運：重新轉貨 |
| `removeCargo(fromUnit, cargoItem)` | 從單位刪除貨物，回傳實際刪除數；ACV 釋放使用 |

---

## 設定

| 路徑 | 用途 |
|---|---|
| `config.red.amphibOps.zones[].landing.hovercraft` | 氣墊船 DBID、`transferManifest` |
| `config.red.amphibOps.zones[].air.transportHelicopter`、`attackHelicopter` | 直升機 DBID、`transferManifest`；攻擊直升機另有 `zone`（CAS 區） |
| `config.red.amphibOps.zones[].movement.holdingAreas` | `mothership`、`deployLine` |
| `zone.air.transportAircraft` | 陸基運輸機清單 |

---

## 相關模組

- [shipMovement](shipMovement.md) — 前置：艦隊移動
- [amphibiousAssault](amphibiousAssault.md) — `launchACV` 呼叫 `removeCargo`
- [hovercraft](hovercraft.md) — 氣墊船走通道與卸貨
- [系統架構](README.md)
