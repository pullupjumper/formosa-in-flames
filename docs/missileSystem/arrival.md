# arrival.lua

機動車組進入 FP / HA / RL / AHA 陣地時的反應。

> Source: `src/modules/missileSystem/arrival.lua`

責任摘要：解析 `UnitEntersArea` 的 trigger，依陣地類型分派 handler，記錄狀態並輸出一份批次日誌。

---

## 概觀

外部只經 [init](init.md) 的 `processUnitEntersArea` 進來；它依觸發單位陣營組出 `moveCtx`（`isAuto`、`hideOnEnterHA`、`hideResupplyOnRLNoMeeting`、`firingUnitLookupSide`），再呼叫 `Arrival.processMoveToPositionEvent`。

模組內將觸發流程拆成多個局部 handler：`processFiringPoint`、`processHideArea`、`processReloadPoint`、`processAmmoHoldingArea`，再透過 `forEachEnabledSystem` 套用到啟用中的類別（`mlrs/srbm/...`）。狀態寫入一律呼叫 [transitions](transitions.md)。

`moveCtx` 允許不同陣營自訂流程，例如電腦控制陣營可在進入 HA 時自動 `hideUnit`（前提為彈藥充足），玩家控制陣營或低彈藥量單位則不做動作，以便接續前往 RL 補給。

---

## 主要機制

1. 由 `resolvePositionType(event)` 從 trigger description（`Arrive in (FP|HA|RL|AHA) ` 前綴）解析位置代碼。
2. 非 FP 事件會先 `dropUnitContact`，降低非必要接觸資訊。
3. 依陣地類型分派至對應 handler。
4. HA 流程僅在 `moveCtx.hideOnEnterHA` 啟用 **且** 機動發射車彈藥充足時，才會 `Transitions.hide` 並執行 `hideUnit`；低彈單位保持原狀以便觸發後續補給流程。
5. RL/AHA 流程會先做 `Meeting` 判斷，成功才進入 `RELOAD` 計時；RL 無會合時 `Transitions.settle` 一律以手動模式（`isAuto=false`）呼叫，避免短暫經過 RL 的機動發射車（例如重定位中途）被卡停。若 `moveCtx.hideResupplyOnRLNoMeeting` 啟用且對應機動發射車彈藥充足，會將彈藥車隱蔽。

```mermaid
flowchart TD
    A[processMoveToPositionEvent] --> B{resolvePositionType}
    B -->|FP| C[processFiringPoint]
    B -->|HA| D[processHideArea]
    B -->|RL| E[processReloadPoint]
    B -->|AHA| F[processAmmoHoldingArea]

    D --> M{hideOnEnterHA<br/>且彈藥充足?}
    M -->|Yes| N[Transitions.hide + hideUnit]
    M -->|No| O[不動作]

    E --> G{hasMetResupplyUnit}
    G -->|Yes| H[Transitions.beginReload]
    G -->|No| I[Transitions.settle]

    F --> J{hasMetAmmoDepot}
    J -->|Yes| K[Transitions.beginReload]
    J -->|No| L[Transitions.settle]
```

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `processMoveToPositionEvent` | `params: SBJ__MoveToPositionEventParams` | `nil` | 解析位置、分派 handler、輸出日誌；只由 `init.lua` 的 `processUnitEntersArea` 呼叫 |

---

## 日誌輸出

`position` 來自 event trigger，整批相同，因此放在 header 而非每一行：

```
[missileSystem] side=China: Position event mode=auto position=RL | total=2 ok=1 warn=1
  [OK]   system=SRBM unit=SRBM-FU-1 state=RELOAD action=reload_started startedAt=3600 triggerUnit=SRBM-RU-1
  [WARN] system=SRBM unit=SRBM-RU-2 action=resupply_concealment_failed pairedFiringUnit=SRBM-FU-2
         area=OPAREA-1 reason=no_buildings_in_mask
```

**行為變更：**此函式原本只要批次中出現任何 `WARN`／`FAIL`／`ERROR`，就把**整份** summary（含成功行）送 `Logger.warn`。改成 per-row 之後三個 WARN（`concealment_failed`／`resupply_concealment_failed`／`reload_not_started`）落在 info log，因此受 `config.logging.modules[missileSystem].verbose` 管控（目前為 `true`）。

---

## 相關模組

- [init](init.md)
- [transitions](transitions.md)
- [meeting](meeting.md)
- [ammo](ammo.md)
- [concealment](concealment.md)
