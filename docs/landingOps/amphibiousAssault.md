# amphibiousAssault — 兩棲突擊協調

> 原始碼：`src/modules/landingOps/amphibiousAssault.lua`

**職責**：LST 與 SAG 就位、決定哪艘船放 ACV、空/機降區威脅與登陸單位統計

---

## 概述

amphibiousAssault 是突擊階段的動作集合，本身不決定「何時」做，時機由 [coordinator](coordinator.md) 與事件腳本決定。它處理四件事：

1. **LST 就位**：`moveToLaunchStations` 把展開線上的 LST 移到離岸 2～4 nm 的就位帶，SAG 移到兩棲載具集結區
2. **ACV 釋放**：`launchACV` 決定哪艘船可以放，放出交給 [acvWave](acvWave.md)；空船回港
3. **威脅評估**：`countContactsInArea` 數空/機降區內的敵方可移動設施
4. **登陸統計**：`countUnitsInEachArea` 數各區 `air.attackHelicopter.zone` 內已登陸的紅方單位

通道與航線不在這裡處理，見 [laneGeometry](laneGeometry.md)、[routePlanner](routePlanner.md)。

---

## LST 就位

`moveToLaunchStations` 的流程：

1. 以 `landing.laneCenter` 和 `zone.heading` 建座標系
2. 找展開線上的 LST（Ship 型別、非 RORO、非 Barge、非 Type 082，見 `isLST`）
3. 保持隊形，整體沿進場方位平移，讓隊形縱深中心落在 `launchStationNearNm ~ launchStationFarNm` 的正中
4. 設航點與 `lstSettings.speed`

隊形縱深大於就位帶寬度時回 FAIL（`formation_exceeds_station_band`），**不改任何航線**，階段停在 `MINE_CLEARING`，下個 tick 重試。

### 為什麼 082 與 RORO 不跟著走？

Type 082 在反水雷階段已經 RTB，RORO 與駁船要留在展開線等 [adminOffloading](adminOffloading.md)。`isLST` 因此用名稱與 DBID 排除它們。

### 為什麼先掃雷再移 LST？

通道的橫向位置取自展開線上 LST 之間的空隙（`findDeployLineLSTLaterals`），讓通道不穿過船體。LST 一旦前進，這個參考就變了，所以順序是先算通道、掃完、再移 LST。

---

## ACV 釋放

事件腳本 `launchACV.lua` 經門面呼叫 `launchACV(amphibOps, zoneStates, ship)`。放 ACV 是衝擊上陸的一步，所以「這艘船該不該放」在這裡決定；車種、貨艙、額度、生成與航線都交給 [acvWave](acvWave.md) 的 `release`。

- 只處理渡輪或 LST（071／072／073 或名稱為 Ferry，`isFerryOrLST`），且船所在作戰區（以 `landing.acv.area` 判斷，`getShipZone`）已到 `ASSAULT_LANDING` 之後
- `release` 回 `isEmpty`（艙內沒有 ZBD/ZTD，如 071）：船掛回基地並 RTB
- `release` 回 `isPaused`（額度為 0）：船留在泛水出發線等下一波，不 RTB

`hasUnreleasedACV` 同樣分工：哪些船算數（展開線上的渡輪或 LST）在這裡判斷，船上還有沒有 ACV 問 `AcvWave.hasCargo`。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `moveToLaunchStations(amphibOps, zone, units)` | LST 與 SAG 就位；任一失敗回 `false` |
| `findDeployLineLSTLaterals(zone, frame, units)` | 展開線 LST 的橫向位置，供 [mineClearing](mineClearing.md) 排通道 |
| `launchACV(amphibOps, zoneStates, ship)` | 船觸發時放一批 ACV；空船回港 |
| `hasUnreleasedACV(zone, ships)` | 展開線上是否還有船載著 ACV |
| `countContactsInArea(contacts, area)` | 只數 `FACILITY_MOBILE` |
| `countUnitsInEachArea(zones)` | 單位類別清單在程式碼的 `LANDED_UNIT_TYPES` |

`countUnitsInEachArea` 有兩個用途：coordinator 用 ZBD-05 數量判定灘頭，`unitStatusUI` 經門面顯示。

---

## 設定

| 路徑 | 用途 |
|---|---|
| `config.red.amphibOps.tuning.route.launchStationNearNm`、`launchStationFarNm` | LST 就位帶 |
| `zones[].landing.lstSettings.speed` | LST 速度 |
| `zones[].landing.acv.area` | 判斷船所屬區 |
| `zones[].movement.baseGUID` | 空船掛回的基地 |
| `zones[].air.attackHelicopter.zone` | 登陸單位統計範圍 |
| `zones[].air.transportHelicopter.zone`、`contactThreshold` | 威脅評估範圍與門檻 |

---

## 相關模組

- [acvWave](acvWave.md) — 放出 ACV、額度與分波
- [shipMovement](shipMovement.md) — `teleportSagToFormation`
- [adminOffloading](adminOffloading.md) — 後續階段
- [系統架構](README.md)
