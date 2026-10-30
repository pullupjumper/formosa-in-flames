# sagFireSupport — SAG 壓制空/機降區

> 原始碼：`src/modules/landingOps/sagFireSupport.lua`

**職責**：052D 所屬的水面行動群（SAG）對空/機降區內的可移動設施開火

---

## 概述

事件腳本 `attackAirlandingZone.lua` 經門面 `LandingOps.attackAirlandingZone` 呼叫 `SagFireSupport.attackAirlandingZone(amphibOps, ship)`。門面只解析設定與狀態再轉交。

流程（任一步不成立就回 `false`，不開火）：

1. `ship` 要有編組，且 `dbid` 是 `TYPE_052D`
2. 用編組名稱在所有作戰區的 `sags` 裡找 SAG 描述（私有函式 `findSAG`）
3. 取紅方 `ScenEdit_GetContacts`，留下在 SAG `area` 內、`typed` 為 `FACILITY_MOBILE` 的接觸
4. 沒有符合的接觸就結束
5. 把該編組的對地武器管制設為 `FREE`，再用 `AttackManager.attackContacts` 以 `HPJ_38` 射擊

每個目標的射擊彈數是 `airlandingFireQty` 除以目標數（無條件捨去），也就是全部目標合計的彈數。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `attackAirlandingZone(amphibOps, ship)` | 開火回 `true`；不符條件或無目標回 `false` |

---

## 設定

| 設定 | 說明 |
|---|---|
| `config.red.amphibOps.airlandingFireQty` | 全部目標合計的射擊彈數 |
| `zone.sags[]` | SAG 描述：`groupName`、`area` |
