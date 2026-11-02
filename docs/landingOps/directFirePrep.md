# directFirePrep — 直接火力準備

> 原始碼：`src/modules/landingOps/directFirePrep.lua`

**職責**：突擊上陸階段對登陸區的直接火力準備。兩條路：

- **艦砲**：052D 所屬的水面行動群（SAG）對空/機降區內的可移動設施開火
- **戰機**：排一架偵察機看登陸區，找到的目標由 [strikePlanner](../strikePlanner/README.md) 派機打擊

---

## 艦砲：attackAirlandingZone

事件腳本 `attackAirlandingZone.lua` 經門面 `LandingOps.attackAirlandingZone` 呼叫 `DirectFirePrep.attackAirlandingZone(amphibOps, zoneStates, ship)`。門面只解析設定與狀態再轉交。

流程（任一步不成立就回 `false`，不開火）：

1. `ship` 要有編組，且 `dbid` 是 `TYPE_052D`
2. 用編組名稱在所有作戰區的 `sags` 裡找 SAG 描述與所屬作戰區（私有函式 `findSAG`）
3. 該區階段要在 `WAITING_ASSAULT` 到 `ASSAULT_LANDING` 之間（含掃雷、衝鋒舟、破障）
4. 取紅方 `ScenEdit_GetContacts`，留下在 SAG `area` 內、`typed` 為 `FACILITY_MOBILE` 的接觸
5. 沒有符合的接觸就結束
6. 把該編組的對地武器管制設為 `TIGHT`，再用 `AttackManager.attackContacts` 以 `HPJ_38` 射擊

每個目標的射擊彈數是 `fireSupport.airlandingShotQty` 除以目標數（無條件捨去），也就是全部目標合計的彈數。目標數多於彈數時，每個目標分到 0 發。

## 戰機：startAirRecon

[coordinator](coordinator.md) 在作戰區進入 `WAITING_ASSAULT` 時呼叫 `startAirRecon(config, reconState, zone)`。`zone.air.reconTemplate` 有值時，經 `StrikePlanner.addReconEntry` 排入偵察；之後依偵察目標的 `strikeMappings`（例如 `LANDING_SUPPORT_NORTH`）派機打擊，這段由 strikePlanner 負責。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `attackAirlandingZone(amphibOps, zoneStates, ship)` | 開火回 `true`；不符條件、階段不對或無目標回 `false` |
| `startAirRecon(config, reconState, zone)` | 該區有 `reconTemplate` 就排入偵察 |

---

## 設定

| 設定 | 說明 |
|---|---|
| `config.red.amphibOps.fireSupport.airlandingShotQty` | 全部目標合計的射擊彈數 |
| `zone.sags[]` | SAG 描述：`groupName`、`area` |
| `zone.air.reconTemplate` | `config.red.recon.templates` 的鍵 |
