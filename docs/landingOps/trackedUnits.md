# trackedUnits

`src/modules/landingOps/trackedUnits.lua`

## 概述

管「landingOps 追蹤的單位死掉了」這一條規則：把它的 GUID 從該區每一個登記表整筆刪掉。

登記表（都在 `zoneState`）：

| 登記表 | 主人 | 刪法 |
|---|---|---|
| `acvGuids[type]` | [acvWave](acvWave.md) | 從陣列移除 |
| `boats` | [assaultBoat](assaultBoat.md) | 刪 key |
| `hovercraft` | [hovercraft](hovercraft.md) | 刪 key |
| `minesweepers` | [mineClearing](mineClearing.md) | 刪 key |
| `heliWave.transport.currentWave`、`heliWave.attackHelis`、`heliWave.airlift.currentWave` | [heliWave](heliWave.md) | 刪 key |
| `laneSlots[beachLaneId]` | [routePlanner](routePlanner.md) | 寫 `false`，保持陣列連續 |

同一個單位可能同時在兩個登記表（例如衝鋒舟和它預約的停車位），全部都刪。新增登記表時，要在這裡加一列。

## 兩條路

- **擊殺事件**：`destroyUnits.lua` 對每個被擊殺的單位呼叫 `LandingOps.removeDestroyedUnit`，不挑 DBID。門面對每一區呼叫 `remove`。landingOps 沒有記錄的 GUID 回 `false`。
- **輪詢後備**：各模組每個 tick 第一次查登記表裡的單位時用 `findUnit`（或 `removeMissing`），查不到就呼叫 `remove`。所以事件沒趕上時，只有第一次查詢記一筆 `Unit not found` ERROR，之後任何模組都不會再查它。排路線時停車位佔位者用 `removeMissing` 判斷。heliWave 的 `findFlyingTransports` 仍直接查，但它在同一 tick 的 `updateTransports` 之後執行，查不到的已經刪掉了。

`GameApi` 只包 CMO API，所以沒有「查不到也不記 ERROR」的查詢；一筆是下限。

## 公開 API

| 函式 | 說明 |
|---|---|
| `remove(zoneState, guid)` | 從該區所有登記表刪掉該 GUID，回傳是否有刪 |
| `findUnit(zoneState, guid)` | 查單位；查不到時先 `remove` 再回 `nil` |
| `removeMissing(zoneState, guid)` | 查不到就 `remove`，回傳是否刪了 |
