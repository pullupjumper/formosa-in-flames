# cargoRun

`src/modules/landingOps/cargoRun.lua`

## 概述

管一趟「載運」：運輸載具在母艦或機場上待命、帶貨出發、到卸貨點卸貨、卸完返航。

使用者：

| 模組 | 載具 | 卸貨點 |
|---|---|---|
| [heliWave](heliWave.md) | 運輸直升機、運輸機（airlift） | `landingPoint` |
| [hovercraft](hovercraft.md) | Type 726A 氣墊船 | `finalPoint`（停車位） |

航線、放飛、分波、逾時都由使用者自己管；這裡只管「找誰能出發」和「每個 tick 推進階段」。

## 階段

| phase | 動作 | 下一個 phase |
|---|---|---|
| `enroute` | 離卸貨點小於 `arrivalNm` 時 `ScenEdit_UnloadCargo` | `unloading` |
| `unloading` | 卸完（`condition` 是 `UNDERWAY` 且 `cargo == nil`）時 `RTB(true)` | `returning` |
| `returning` | 不再處理 | — |

## 公開 API

| 函式 | 說明 |
|---|---|
| `PHASE` | 三個階段的字串 |
| `findReady(host, platformType, dbid, skipMap?)` | `host.embarkedUnits[platformType]` 裡 DBID 相符、`readytime_v == 0`、有貨的載具；`skipMap` 裡的 GUID 跳過 |
| `step(unit, run, dropPoint, arrivalNm)` | 照上表推進一步 |
| `returnToBase(unit, run)` | `RTB(true)` 並設為 `returning`（heliWave 逾時返航也用） |
