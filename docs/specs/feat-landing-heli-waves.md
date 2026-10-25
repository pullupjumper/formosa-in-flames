# feat/landing-heli-waves

## 目標

運輸直升機改成「機波」：每區一波 8 架，從 Type 075/071 上挑已載貨的直升機，手動 launch、給航線，到空降區卸貨。整波卸完並返航（或被擊殺）後，才放下一波。攻擊直升機 4 架同波起飛護航。

現在的做法：`zone.air.transportHelicopter.missions` 預先建好 4 個任務，到時間各自起飛，不管前一波結果。`missions` 設定**保留**，但不再靠 CMO 任務起飛，改由機波邏輯手動放飛。

## 要做到的行為

### 機波

- 一波 = 該區最多 8 架運輸直升機 + 4 架攻擊直升機。可用的不足時，有幾架飛幾架，仍算一波。
- 第一波：程式依航程倒推算出放飛時間（見「時間基準 T」），用 `GameUtils.isAfterStartTime` 判斷到了就放。
- 第二波起：上一波全部結束（見「放下一波」）就放，不看 `startTime`。
- `zone.air.transportHelicopter.missions` 的每一筆 = 一個波次，提供 `loadoutId` 等資料；不再呼叫 `setMissionStartTime`，CMO 任務不會自動起飛。`missions[n].startTime` 不再使用。
- 所有作戰區用同樣的波次大小（8 運輸 + 4 攻擊）。
- 候選：該區 Type 075/076/071 上、機上有 cargo 的運輸直升機，隨機挑。
- 每波起飛時記錄這波的 GUID 清單到 `zoneState`（新欄位，型別補進 `schema.lua` 的 `SBJ__ZoneState`）。
- 沒有候選直升機時，記 log，下個 tick 再試（貨會由 `transferRemainingCargos` 補上，見「補貨」）。
- 全部 `missions` 的波次都放完，機波就結束。

### 補貨

- 沿用既有 `AmphibiousLogistics.transferRemainingCargos`（每隔 `remainingCargoTransferSec` 由 `processRemainingCargoTransfer` 觸發，補貨不重新指派任務）。機波不另外裝貨，只在放飛時挑「當下機上有 cargo」的直升機。

### 航線

- 不經過水際／灘際通道，不管水雷。
- 一起飛就分成左右兩翼，沒有共同航線。
- 每翼：4 架運輸直升機 + 2 架攻擊直升機，走同一條翼航線。
- 翼航線沿船團外側飛，進內陸後，左右兩翼各自畫一條航線到登陸點（空降區 `zone.air.landingZone`）。
- 左右翼的航點由設定決定（見「設定」）。

### 卸貨與返航

- 到降落點（距離小於 `arrivalNm`）就呼叫 `GameApi.ScenEdit_UnloadCargo(guid)`，不指派任何 mission。
- 判斷「卸完」：`unit.condition ~= "Transfering Cargo"` 且 `unit.condition == "Underway"`（遊戲內已確認可用；實作簡化成只判 `== "Underway"`，兩者等價）。
- 卸完就 `unit:RTB(true)`，在 `zoneState` 記下已返航。
- `ScenEdit_GetUnit(guid)` 回 `nil` 視為被擊殺。

### 放下一波

下一波起飛的條件：上一波每一架都是「已下 RTB」或「已被擊殺」。

逾時保護：上一波放飛後超過 `waveTimeoutSec`，剩下的直升機視同已結束，放下一波，並記 log。逾時時，仍在卸貨的運輸機也一併 `RTB`，避免卡住後續波次。

### 攻擊直升機

- 與每一波運輸直升機一起起飛，每波 4 架（左右翼各 2 架），護航。
- 跟運輸直升機同一條航線，不飛 CAS 待命。
- 到降落點上空後**不卸貨、不 RTB**，留在上空待命（loiter）。
- 同一波的運輸直升機全部「卸完或被擊殺」後，攻擊直升機才 `RTB(true)`。逾時時一併 RTB。

### 時間基準 T

- 在 `BOAT_ASSAULT` 開始時估算 T 與第一波放飛時間，存進 `zoneState.heliWave.launchAt`。算出來已過期就立刻放飛。
- T = 衝鋒舟到達坐灘線的時間。
- 直升機抵達降落點也要在 T，才能護航衝鋒舟登陸。
- 第一波放飛時間 = T − 飛行時間。飛行時間 = 翼航線總長 ÷ 巡航速度（取左右翼較長者）。T 取衝鋒舟抵達坐灘線的預計時間。

### 設定

放進 `config.red.amphibOps.tuning.heliWave`，不寫死在邏輯裡：

| 欄位 | 用途 |
|---|---|
| `waveSize = 8` | 運輸直升機每波架數 |
| `escortSize = 4` | 攻擊直升機每波架數 |
| `waveTimeoutSec` | 逾時放行 |
| `arrivalNm` | 到降落點的判定距離 |
| `wingOffsetM`、`inlandEntryM`、`landingSpreadM` | 左右翼航點的偏移量；航點由程式用 `LaneGeometry` 算出，不直接寫在設定裡 |
| `cruiseAltitudeM` | 放飛後的巡航高度 |
| 巡航速度 | 倒推飛行時間用（Z-18 約 130 kt） |
| 每翼架數 | 不另設欄位；依序輪流分到左右翼，各得 `waveSize`、`escortSize` 的一半 |

`zone.air.transportHelicopter.missions` **保留**，作為波次表（見「機波」）；`missionStartTime.transportHelicopter` 不再使用，移除。`attackHelicopter.missions` 同樣保留，跟著波次放飛，不再設 CMO 任務開始時間。

### 狀態（`zoneState.heliWave`）

型別補進 `schema.lua`，`SBJ__ZoneState` 加 `heliWave?`。只存目前這一波，下一波放飛時整個換掉。被擊殺不記，`GetUnit` 回 `nil` 即是。

```lua
---@class SBJ__HeliWaveState: table
---@field waveIndex integer 已放飛的波數（0 = 還沒放）
---@field launchAt? number 第一波預計放飛時間
---@field waveLaunchedAt? number 目前這一波放飛時間，逾時判斷用
---@field units table<string, SBJ__HeliState> 目前這一波的直升機，key 是 GUID
---@field isFinished boolean 波次表放完且最後一波已結束

---@class SBJ__HeliState: table
---@field role string "transport" 或 "attack"
---@field wing string "left" 或 "right"
---@field phase string "enroute" | "unloading" | "loitering" | "returning"
---@field landingPoint CMO__Location 這架的降落點
```

- 運輸：`enroute` → 到點呼叫 `UnloadCargo` → `unloading` → 卸完 `RTB` → `returning`。
- 攻擊：`enroute` → 到點 `loitering` → 同波運輸全部卸完或死光 → `RTB` → `returning`。

### Coordinator

- `HELICOPTER_MISSION_CATEGORIES` 不再交給 `setLandingMissionStartTime` 設 CMO 開始時間（該函式仍負責記下 `airlandingMissionStartTime`）；改為每 tick 呼叫機波更新（建議在 `ASSAULT` 相關階段持續執行，與氣墊船一樣不隨階段結束而停）。
- 機波狀態存進 `zoneState`，需可存檔還原。

### 實作時追加（為了避免 CMO 任務與手動放飛互相干擾）

- `AmphibiousLogistics`：移除直升機的 CMO 貨運任務建立與 `assignments` 指派；只剩氣墊船任務，直升機仍轉貨。
- `AmphibiousAssault.setLandingMissionStartTime` 改名 `recordLandingStartTime(zoneState)`，只記 `airlandingMissionStartTime`（補運計時用）。
- `HeliWave.schedule(tickCtx, zone, zoneState)`、`HeliWave.update(tickCtx, zone, zoneState)`：沿用 `SBJ__LandingTickContext`。
- 氣墊船、衝鋒舟、掃雷艦為了「卸貨判斷」與 fast-forward 一致，一併調整（見下，這些是必要的連動，不是新功能）：
  - `GameUtils.isCargoUnloaded(unit)`：氣墊船與直升機共用卸貨完成判斷。
  - `Hovercraft`：到停泊點改成呼叫 `UnloadCargo`，卸完 `RTB`；狀態 `arrived` 改成 `phase`（`enroute`／`unloading`／`returning`）。原本「指派貨運任務」的 TODO 移除。
  - `AssaultBoat`：fast-forward 的 teleport 從放艇時移到每 tick 更新時，並清掉航線。`init.lua` 的 ACV 航線 router 在 teleport 時回 `nil`。
  - `MineClearing`：fast-forward 判斷改用 `zoneState.phase`，移除已完成的 TODO。
  - `constants`：新增 `WEAPONS.AT_MINE`、`THROTTLES.STOP`、`THROTTLES.MILITARY`、`UNIT_CONDITIONS`。
- 第一波放飛時間 = max(現在, T − 飛行時間)；T 與飛行時間的算法見 `docs/landingOps/heliWave.md`。

## 不做

- 不處理降落點的敵方威脅（卸貨時被打就被打）。
- 不改氣墊船、衝鋒舟、兩棲車的任務目標與路線；只動上面列出的卸貨判斷與 fast-forward 連動。
- 不改 `transferAndAssign`、`transferRemainingCargos` 的轉貨邏輯。
- 不做多降落點。

## 待確認

1. **卸貨判斷**：已在遊戲內確認 `"Underway"` 可正常判斷卸完。
2. **降落失敗**（一直卡在 `Transfering Cargo`）靠 `waveTimeoutSec` 處理。

## 驗收

- `busted --lua=luajit spec` 全過。
- 新增機波模組的測試：
  - 挑選：只挑有 cargo 的、最多 8 架、不足照飛、沒有候選就等下一個 tick。
  - 第一波未到倒推時間不放飛；後面波次等上一波結束；波次表放完機波結束。
  - 分翼：4 運輸 + 2 攻擊一翼，另一翼同樣；各自航線到登陸點。
  - 到達降落點呼叫 `UnloadCargo`；卸完才 RTB；被擊殺（`GetUnit` 回 `nil`）算結束。
  - 整波結束才放下一波；逾時也放。
  - 攻擊直升機每波 4 架同時起飛。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 新增 `docs/landingOps/heliWave.md`；同步更新 `coordinator.md`、`assaultTimeline.md`、`amphibiousLogistics.md`（直升機改手動放飛的部分）。
