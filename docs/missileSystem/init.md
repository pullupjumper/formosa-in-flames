# init.lua

`missileSystem` 入口模組，提供對外 API。

> Source: `src/modules/missileSystem/init.lua`

責任摘要：封裝子模組，對外提供陣營級與飛彈連級的入口。

---

## 概觀

`init.lua` 是外部腳本唯一需要 `require` 的門面層。定時檢查腳本呼叫 `processSide`（內部轉私有的 `process`），場景事件腳本呼叫 `processUnitEntersArea`（組出 `moveCtx` 後轉給 [arrival](arrival.md)），其餘初始化與重建 API 也都由此轉發。

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `evaluateReadiness` | `groundState, missileSystem, firingUnitName, getUnit` | `missileSystemReadiness` | 判斷發射單位能不能接火力支援任務，回傳 readiness（見下方） |
| `sendToFiringPoint` | `groundState, missileSystem, firingUnitName` | `boolean, boolean` | `HIDE` 且彈量足夠時卸出隱蔽區並前往 FP（條件在 `Rules.evaluateSendToFiringPoint`）；回傳是否已在 FP（`STATIC`）與單位是否不見（實體或 runtime state 任一不存在） |
| `startStow` | `groundState, missileSystem, firingUnits, opts?` | `nil` | 啟動 stow 倒數；SAM 略過（`Rules.staysDeployed`）、已有倒數保留；`opts.onlyDeployed` 只處理 `STATIC`／`REPOSITIONING`（`Rules.shouldStow`） |
| `getAmmoInventory` | `groundState, missileSystem, sideName` | `SBJ__AmmoInventoryResult?` | 轉呼叫 `Ammo.getInventory`，系統不存在回傳 nil；供上層（例如 landingOps 火力閘門）判斷 |
| `processSide` | `config, saveData, sideName` | `nil` | 依陣營取 ground 設定、狀態與 `ground.policy.isAuto`（包成 `runCtx`）後呼叫私有的 `process`（執行循環並輸出結果日誌）；`scheduledReloadHideCheck.lua` 的入口 |
| `processUnitEntersArea` | `config, saveData, unit, event` | `nil` | 依觸發單位陣營的 `ground.policy` 組出 `moveCtx`，交給 `Arrival.processMoveToPositionEvent`；`moveToPosition.lua` 的入口 |
| `processSupplyAssetDestruction` | `unit, groundState` | `boolean` | 走訪所有系統，找到擁有該補給資產的系統後扣彈並記錄 |
| `redeployFromControlPanel` | `config, saveData, sideName, entries` | `nil` | 把 control panel 送回的 entries 轉成 layouts（`SBJ__MissileSystemLayout[]`），再由私有的 `redeploy` 依序重建 zone／trigger、單位與 context |
| `buildDeploymentSystems` | `config, saveData, sideName` | `table<string, SBJ__MissileSystemConfig>` | 產生 control panel 所需的系統設定副本（含 zone 頂點）；已在存檔裡的發射單位用存檔的作戰區 |
| `deploySide` | `config, saveData, sideName` | `nil` | 以 `Deployment.addMissileSystems` 建立單位並初始化 context；`addMissileSystems.lua` special action 的入口 |
| `buildBatteryStatuses` | `config, saveData, sideName` | `SBJ__BatteryStatus[]` | 供狀態 UI 使用，每個飛彈連（發射單位加配對的補給單位）一筆的狀態 |
| `ensureGroundState` | `config, saveData, sideName` | `nil` | 自行解析該陣營的 ground 設定與狀態後轉呼叫 `GroundStateStore.ensureGroundState` |
| `initSide` | `config, saveData, sideName` | `nil` | 自行解析該陣營的 ground 設定與狀態後轉呼叫 `GroundStateStore.initMissileSystemStates` |

`ensureGroundState` / `initSide` 取 `(config, saveData, sideName)` 而非現成的 slice，讓 `src/core/init.lua` 等外部呼叫端不需要知道「哪個 config 欄位、哪個 saveData slice 屬於哪個陣營」；[groundStateStore](groundStateStore.md) 內的同名函式仍維持 `(missileSystemConfigMap, groundState)`。

> 原本轉發 `Deployment.addMissileSystems` 的門面函式已刪除，外部改用 `deploySide`；位置事件的處理已搬到 [arrival](arrival.md)，外部只經 `processUnitEntersArea` 進入。

---

### Readiness

readiness 是「這個發射單位現在能不能接火力支援任務、不能的話為什麼」。HIDE 與彈量的判斷在 `Rules.evaluateReadiness`，彈量用 callback 傳入，只有 HIDE 的單位才會讀。外部（strikePlanner）只拿 `groundState` 當不透明把手，不讀發射單位的 `state`。`evaluateReadiness` 依序檢查，回傳第一個不通過的 `constants.MISSILE_SYSTEM_READINESS`：

| 代碼 | 值 | 意義 |
|---|---|---|
| `NO_STATE` | `context_not_found` | 該系統沒有這個單位的 runtime state（大小寫不拘） |
| `UNIT_NOT_FOUND` | `unit_not_found` | CMO 裡已無此單位 |
| `NOT_HIDDEN` | `bad_state` | 不在 `HIDE` |
| `LOW_AMMO` | `low_ammo` | 彈量不高於 `ammoThreshold` |
| `READY` | `available` | 可以派任務 |

值刻意與 FSEM 日誌的計數鍵相同。`getUnit` 由呼叫端提供，只有在單位有 runtime state 時才會被呼叫，讓 fsemBuilder 保留每趟一次的單位快取。先查單位再比對 `state` 的理由見 [fsemBuilder](../strikePlanner/fsemBuilder.md#為什麼先-getunit-再比對-state)。

---

## 日誌輸出

定時循環建立一份 `LogFormat.report`，改成 per-row 分流：`FAIL`／`ERROR` 進 error sink，`OK`／`WARN` 留在 info log。

```
[missileSystem] side=China: Reload cycle mode=auto | total=3 ok=2 warn=1
  [OK]   system=SRBM unit=SRBM-FU-1 action=missile_reload_finished loaded=6
  [OK]   system=SRBM unit=SRBM-RU-1 action=move_resupply_to_reload_point
  [WARN] system=MRBM unit=MRBM-RU-2 action=move_resupply_to_reload_point reason=unit_not_found
```
```
（error sink）side=China: Reload cycle mode=auto | total=1 fail=1
  [FAIL] system=MLRS area=Fujian unit=MLRS-FU-3 action=move_to_hide_area reason=no_ha_defined
```

位置事件的日誌見 [arrival](arrival.md#日誌輸出)。

`sendToFiringPoint` 的移動失敗與 `processSupplyAssetDestruction` 是單筆事件而非批次，走 `LogFormat.line` 並在呼叫端自行選 sink。

---

## 相關模組

- [rules](rules.md)
- [arrival](arrival.md)
- [cycle](cycle.md)
- [movement](movement.md)
- [meeting](meeting.md)
- [ammo](ammo.md)
- [concealment](concealment.md)
- [deployment](deployment.md)
- [groundStateStore](groundStateStore.md)
- [triggers](triggers.md)
