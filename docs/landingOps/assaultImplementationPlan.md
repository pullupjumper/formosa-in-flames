# 反水雷、衝鋒舟、岸上破障、兩棲車分波、氣墊船航線 實作計畫

## Context

`docs/landingOps/assaultTimeline.md` 第二部分設計了新流程：獵雷艦（Type 529）開通道 → 衝鋒舟上岸 → 岸上破障 → 兩棲車分波泛水 → 氣墊船運重裝備。
現在 `coordinator.lua` 在 `WAITING_ASSAULT` 一到就同時放直升機、氣墊船、LST 前進；兩棲車到區就放，沒有上限、沒有走通道。

已確認的決定：
- 水雷：開場 script 用 `ScenEdit_AddMinefield` 在近海佈（藍方、範圍用參考點、數量放 config）。灘岸雷區以後再做。
- 掃雷：CMO 內建掃雷任務。**先設 `course`，再 assign 任務**。
- 衝鋒舟、氣墊船：照 `strikePlanner/recon.lua:56` 用 `unit:Launch(true)`，但**先設 `course` 再 Launch**。
- 氣墊船：**不在等待區 assign 任務**。Launch 前先給航線，航線走完才 assign cargo 任務。
- **所有 assign 任務的地方（529 掃雷任務、氣墊船 cargo 任務）只留 `-- TODO:` 註解，使用者自己寫。** course、Launch、狀態記錄照做。
- 兩棲車分波：照文件「7. 兩棲車泛水與分波」做。
- 障礙範圍、通道中心：用 `.scen` 參考點，放 `constants.AREAS`。水雷用 `constants.WEAPONS.SEA_MINE`。
- 衝擊上陸（兩棲車、氣墊船泛水編波）和行政下卸（駁船搭橋、RORO 下卸大量戰甲車）是兩個不同階段。行政下卸要在灘頭堡建立後、絕對安全時才做。

## 新階段

```
WAITING_ASSAULT → MINE_CLEARING → BOAT_ASSAULT → OBSTACLE_CLEARING → ASSAULT_LANDING → WAITING_ADMIN_UNLOADING → COMPLETED
```

`WAITING_SECOND_WAVE` 改名為 `WAITING_ADMIN_UNLOADING`（等待行政下卸）。`secondWaveUnloading.lua` 模組名稱先不動。

| 階段 | 做什麼 | 換下一階段 |
|---|---|---|
| `WAITING_ASSAULT`（改） | 原條件成立 → 直升機任務開始時間（只 `transportHelicopter`、`attackHelicopter`）、算通道、派 529 | 派完 |
| `MINE_CLEARING` | 529 走到最後航點（或被摧毀）→ `RTB()` | 全部完成 → LST 前進（`moveToLaunchStations`，排除 529） |
| `BOAT_ASSAULT` | 072A/072III 進 `zone.landing.acv.area` 就放衝鋒舟 | 衝鋒舟全部到終點或被摧毀 → 記 `obstacleStartedAt` |
| `OBSTACLE_CLEARING` | 計時 | 超過 `obstacle.clearSec` → 方塊標 `cleared` |
| `ASSAULT_LANDING`（新） | 衝擊上陸：兩棲車分波放行、氣墊船走通道 | 灘頭堡建立（先沿用現有 `hasBeachhead`：`casArea` 內 ZBD-05 ≥ 1，加 `-- TODO:` 之後換成更嚴格的條件） |
| `WAITING_ADMIN_UNLOADING`（改名） | 等絕對安全 → `SecondWaveUnloading.startSecondWaveUnloading` | 啟動成功 → `COMPLETED` |

- 兩棲車分波、氣墊船在 `ASSAULT_LANDING` 開始。後面的階段（含 `COMPLETED`）也繼續跑，直到放完。
- `WAITING_ADMIN_UNLOADING` 的「絕對安全」條件先留 `-- TODO:`，暫時直接放行（等於現在的行為）。
- 改名會讓舊存檔裡的 `"WAITING_SECOND_WAVE"` 對不上。開發中，新開局就好。

## 共用：航線計算 `routePlanner.lua`

三種單位（衝鋒舟、兩棲車、氣墊船）都用它。輸入是 `zoneState.lanes`（掃雷時算好、存起來）。

1. **選通道**：`chooseWaterLane(launchPos, lanes, loads)`
   依離艦位置到各水際通道入口 `L_i` 的距離選最近的；距離差在 `laneTieNm` 內就選負載少的（平均分散）。
2. **選灘際通道**：該水際通道底下的 4 條灘際通道，只能選 `cleared` 的（衝鋒舟除外，它是去開通道的）。輪流分配。
3. **橫隊轉縱隊（排隊）**：每條水際通道一個排隊計數器 `k`。入口點 = `L_i` 往外海退 `(k mod queueDepth) × columnSpacingM`。同時放出的單位在不同點進通道，自然排成一列。
4. **縱隊轉橫隊**：到衝擊發起線 `A_i` 後，散到各自的灘際通道起點 `A_lane`。
5. **終點排隊（在通道裡，一個接一個）**：
   - 每條灘際通道往內陸延伸，穿過障礙範圍，終點叫 `E_lane`（通道盡頭）。
   - 通道上切出一格一格的「停車位」：第 1 格在 `E_lane`，第 2 格往回退 `queueSpacingM`，第 3 格再退……都在通道中心線上，不會跑出安全通道。
   - 單位依序拿「第一個空格」當終點。空格 = 沒人佔，或佔的單位已經被摧毀。
   - 格子用完就退到 `A_lane` 為止；再滿就換下一條灘際通道。
   - 狀態存 `zoneState.laneSlots[laneId][slot] = guid`。兩棲車和氣墊船各用一套，互不搶位。
6. 輸出完整 `course`：`[入口點, L_i, A_i, A_lane, (S_lane), 自己的停車位]`。
7. 安全檢查：用 `isRouteClear(route, cells)` 確認不會碰到 `intact` 方塊。

## 新檔案（`src/modules/landingOps/`，package 內部直接 require，不經 `init.lua`）

### `laneGeometry.lua`（純函式）
- 經緯度 ↔ 以通道中心為原點的平面公尺座標（小範圍近似）。
- `buildLanes(params)`：通道中心、朝岸方向 `laneBearing`、529 數量 n → 每艘 529 的
  - 水際通道：展開線點 → 泛水出發線點 `L_i` → 衝擊發起線點 `A_i`
  - 4 條灘際通道（偏移 -180/-60/+60/+180 m），各有 `A_lane`、`S_lane`（離岸 `shoreStandoffM`）
  - 弓字型航線：`A(-180)→S(-180)→S(-60)→A(-60)→A(+60)→S(+60)→S(+180)→A(+180)`
  - 掃雷任務區域長方形 4 角
  - 529 之間 750 m，以中心點對稱。
- `segmentsIntersect`（含相切）、`buildObstacleCells(polygon, cellSizeM)`、`isRouteClear(route, cells)`。

### `mineClearing.lua`
- `layMinefields(amphibOpsConfig)`：開場每區 `GameApi.ScenEdit_AddMinefield({ side = BLUE, dbid, number, delay, area })`。
- `startMineClearing(...)`：算通道存 `zoneState.lanes` → 529 依橫向排序配水際通道 → 每艘：`unit.course = 水際 + 弓字型` → 掃雷任務區域的 4 個角存進 `zoneState.minesweepers[guid].missionArea` → `-- TODO: 建掃雷任務並 assign（使用者自己寫）`。
- `updateMineClearing(zoneState)`：到最後航點（`Tool_Range` < `arrivalNm`）或摧毀 → `RTB()`；回傳是否全部完成。

### `assaultBoat.lua`
- `launchBoats(...)`：已進 `zone.landing.acv.area` 的 072A/072III，從 `embarkedUnits[constants.PLATFORM_TYPES.BOATS]` 拿 `ASSAULT_BOAT`、`readytime_v == 0` 的艇。
  - 配對只算一次（存 `zoneState.boats`）：每艘 LST 先出 1 艘，不夠再出第 2 艘；艇不夠時，同一側最外側的通道丟掉（Sishu 12 艇配 16 條）。
  - 航線用 `routePlanner`（灘際通道一對一，不看 `cleared`）。
  - `boat.course = route` → `boat.manualSpeed = 30` → `boat:Launch(true)`。
- `updateBoats(zoneState)`：全部到 `S_lane` 或被摧毀 → true。

### `obstacleClearing.lua`
- `startObstacleClearing(...)`：讀 `constants.AREAS.OBSTACLE_*`，切 50 m 方塊存 `zoneState.obstacle.cells`。
- `updateObstacleClearing(...)`：超過 `clearSec` → 有活著衝鋒舟的灘際通道，往內陸延長線碰到的方塊設 `cleared`，通道標記為可通行。

### `acvWave.lua`（兩棲車分波，照文件）
- `zoneState.acvGuids`、`acvPausedAt`；存活數 = GUID 還拿得到的數量。
- `getQuota(zoneState, config, currentTime)`：每車種上限 112（`acvWave.capacity`）− 存活數。額度用完就暫停；戰損低於 `(1 − lossRatio)` 或超過 `holdSec` 才補下一波。
- 同一 tick 多艘船共用額度（存在 zoneState，先處理的先拿）。

### `hovercraft.lua`
- `launchHovercraft(...)`：`ASSAULT_LANDING` 起，075/071 的 `embarkedUnits[BOATS]` 裡 `TYPE_726A`、已裝貨、`readytime_v == 0` 的氣墊船 → `routePlanner` 算航線（從母艦選最近的水際通道，走 `cleared` 灘際通道）→ `course` → `Launch(true)` → 記 `zoneState.hovercraft[guid] = { missionName, finalPoint }`。
- `updateHovercraft(...)`：到終點 → 標 `arrived = true` → `-- TODO: assign cargo 任務（使用者自己寫）`。

## 要改的舊 code

| 檔案 | 改什麼 |
|---|---|
| `src/core/constants.lua` | `AMPHIBIOUS_PHASES` 加 `MINE_CLEARING`、`BOAT_ASSAULT`、`OBSTACLE_CLEARING`、`ASSAULT_LANDING`，`WAITING_SECOND_WAVE` 改名 `WAITING_ADMIN_UNLOADING`（全專案替換，含 spec）；`AREAS` 加每區 `LANE_CENTER_*`、`OBSTACLE_*`、`MINEFIELD_*`；水雷用現有 `constants.WEAPONS.SEA_MINE` |
| `src/core/config.lua` | 新增 `amphibOps.mineClearing`、`assaultBoat`、`obstacle`、`minefields`、`route`（`columnSpacingM`、`queueDepth`、`queueSpacingM`、`laneTieNm`）、`acvWave`（`capacity`、`lossRatio`、`holdSec`）；operationalZones 加 `laneCenter`、`laneBearing`、`obstacleArea` |
| `src/core/schema.lua` | `SBJ__ZoneState` 加 `lanes`、`minesweepers`、`boats`、`obstacle`、`obstacleStartedAt`、`acvGuids`、`acvPausedAt`、`acvQuotaUsed`、`queueCounters`、`hovercraft`；新 config 型別 |
| `landingOps/coordinator.lua` | `processZone` 加 4 段 phase、拆開衝擊上陸和行政下卸；每 tick 跑氣墊船；`ARRIVED_PHASES` 加新 phase |
| `landingOps/amphibiousAssault.lua` | `FERRY_OR_LST_DBIDS` 拿掉 `TYPE_529`；`moveZoneLSTsToLaunchStations` 排除 529；`setLandingMissionStartTime` 加 `categories`（不再設 `boat`）；`launchACV` 收 `quota` 與 `routes`，回傳分開「暫停」和「艙內空」；`removeCargoByPriority` 依各車種額度 |
| `landingOps/amphibiousLogistics.lua` | `SHIP_TRANSFER_SPECS` 的 `assignments` 拿掉 `BOATS`（只裝貨不 assign）；`AMPHIBIOUS_SHIP_DBIDS` 的 529 確認是否影響 `isUnitMoving` 判斷（529 掃雷時會一直動，但那時已過 `WAITING_ARRIVAL`，不影響） |
| `landingOps/init.lua` | `init` 呼叫 `layMinefields`；`launchACV(config, saveData, ship)`：phase 未到 `ASSAULT_LANDING` → 不動作；額度 0 → 暫停不 RTB；艙內空 → 照舊 RTB |
| `src/scripts/china/amphibiousOps/launchACV.lua` | 用 `PersistentState.update` 傳 state |
| `docs/landingOps/assaultTimeline.md` | 更新：掃雷用 CMO 任務、佈雷、航線規則、氣墊船流程、參考點清單、phase 圖 |

## 你要在 CMO `.scen` 做的事
`src/core/constants.lua` 的 `constants.AREAS` 已建好空欄位（標 `-- TODO`）。每區（Taoyuan、Sishu、Penghu）在 `.scen` 建參考點後，把名稱填進去即可：
1. `LANE_CENTER_*`：通道中心點（岸邊 1 點）
2. `OBSTACLE_*`：障礙範圍（多邊形）
3. `MINEFIELD_*`：近海雷區（多邊形）

欄位是空的時候，code 要記 log 並跳過該區，不能 crash。

## 留給你自己寫的 TODO
- `mineClearing.lua`：建掃雷任務 + assign（區域角點已存在 state）。
- `hovercraft.lua`：到點後 assign cargo 任務。
- `coordinator.lua`：`ASSAULT_LANDING` 的灘頭堡條件、`WAITING_ADMIN_UNLOADING` 的絕對安全條件。

## 不做（以後再說）
- 灘岸雷區、control panel 畫障礙範圍。

## 實作順序（每步可單獨 commit，先開 branch）
1. `laneGeometry` + `routePlanner` + 測試
2. 佈雷 + 掃雷 phase
3. 衝鋒舟 phase
4. 破障 phase
5. 兩棲車分波 + 走通道
6. 氣墊船
7. 更新文件

## 驗證
1. 單元測試（`spec/modules/landingOps/`，照 `build-test` skill 風格）：
   - `laneGeometry_spec`：n=4 → 4 水際 16 灘際、n=1 → 1/4；間距 750 / 120 m；弓字型順序；相交含相切；方塊鋪滿。
   - `routePlanner_spec`：選最近通道、平手選負載少的；排隊入口點錯開；停車位依序往回排、都在通道中心線上、死掉的單位空出位子；只走 `cleared`。
   - `mineClearing_spec`：course 正確、任務區域存進 state；到終點 RTB。
   - `assaultBoat_spec` / `hovercraft_spec`：先 course 後 `Launch`；Sishu 丟外側 4 條；氣墊船到點標 `arrived`。
   - `acvWave_spec`：上限 112/112 各算；戰損 / 逾時才補；同 tick 共用額度。
   - `coordinator_spec`：phase 依序推進（到 `ASSAULT_LANDING` → `WAITING_ADMIN_UNLOADING` → `COMPLETED`）；529 不被 `moveToLaunchStations` 帶走。
   - `amphibiousAssault_spec` / `init_spec`：529 不是 `isFerryOrLST`；暫停時不 RTB。
2. `busted --lua=luajit spec` 全過（含 `spec/moduleBoundary_spec.lua`）。
3. `bash bin/build.sh -t`，CMO 開 `isTesting` 跑：雷有佈、529 走完弓字型 RTB、衝鋒舟排隊上岸、破障後兩棲車分波出、氣墊船走完通道停在自己的位子（任務等你補 TODO）。
