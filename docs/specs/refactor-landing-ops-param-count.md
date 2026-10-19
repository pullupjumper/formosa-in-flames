# refactor/landing-ops-param-count

## 目標

`src/modules/landingOps` 內所有函式的參數不超過 4 個（`docs/naming.md` 第 5 節「參數數量與順序」）。

## 要做到的行為

目前有 7 個函式超過 4 個參數。各自的處理方式：

| 函式 | 現況 | 處理 |
|---|---|---|
| `mineClearing.buildLaterals` | 6 個（`zone, frame, ships, count, routeConfig, report`） | `zone, frame, ships` 以外的輸入包成 `params`（`SBJ__BuildLateralsParams`） |
| `amphibiousAssault.moveLSTToLaunchStation` | 5 個（`amphibOps, entry, frame, shiftM, zone`） | `frame, shiftM` 併入 `params`（`SBJ__MoveLSTToLaunchStationParams`） |
| `laneGeometry.isStepRangeValid` | 5 個（`values, first, last, minM, maxM`） | `minM, maxM` 併成 `range`，或 `first, last` 併成 `params` |
| `laneGeometry.buildMineCorridor` | 5 個（`frame, laneId, a, b, cellSizeM`） | `a, b` 併成 `strip`（兩端點） |
| `routePlanner.sortWaterLanesByLateral` | 5 個（`frame, launchPos, waterLanes, loads, laneTieM`） | `loads, laneTieM` 併入 `params` |
| `routePlanner.buildSideApproach` | 5 個（`frame, waterLane, launchPos, k, routeConfig`） | 依「固定順序」整理，`k` 併入 `params` |
| `routePlanner.buildBoatRoute` | 5 個（`lanes, beachLaneId, launchPos, queueCounters, routeConfig`） | `queueCounters` 與 `routeConfig` 的取用方式整理（併 `ctx` 或 `params`） |

實作時依下列規則決定包法，最終簽名以程式碼為準：

- 必填輸入用 `params`，選填用 `opts`，一輪共用用 `ctx`；型別名 `SBJ__<函式名>Params`。
- 每個函式最多一個 `params`。
- 參數順序遵守 `config` → `state` → `sideName` → 主角 → 其他輸入 → `opts`。
- 呼叫端與對應 spec 同步更新。

### 註解對齊（已完成）

逐行檢查 landingOps 註解後已修正：

- 第一句動詞跟函式名的動詞一致：`buildCourseForBarge`、`buildCourseForRORO`、`findCargoItems`、`processTaoyuanTemporarySetup`、`processRemainingCargoTransfer`、`offloadVehicles`、`buildMineCorridor`、`moveMatchingShip`、`isFirstWaveFull`。
- `DebugFlow.isFastForward` 的 `boolean` 說明補上 `true` 的意思。
- `removeCargoByPriority`、`findDeployLineLSTs` 的 `@return` 改用 `SBJ__AcvAllocation[]`、`SBJ__LstStation[]`。

## 不做

- 不改遊戲行為與數值。
- 不動 landingOps 以外的模組。
- 不處理 `docs/naming.md` 的其他規則。尚未改名、之後改到再順手換：`collectMatchingCargos`（`collect` 只准用於 `collectSigint`）、`toLocalXY` / `toGeo` / `projectPoint`（不在動詞表）、`laneFrame`（不是動詞開頭）、`buildRotatedClearedBeachLanes`（`rotate` 是禁用字）。

## 驗收

- `busted --lua=luajit spec` 全過。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- landingOps 內沒有超過 4 個參數的函式（用腳本掃描 `function ...(...)`）。
