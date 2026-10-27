# feat/landing-type529

> 補寫，行為已實作；以程式與 [assaultTimeline](../landingOps/assaultTimeline.md) 為準。

## 目標

突擊上陸改成依「通道」進行：獵雷艦先開水際通道與灘際通道，衝鋒舟（Type 529）破障，通道都開好才放兩棲車與氣墊船。取代原本的直接泛水登陸。

## 要做到的行為

- 新增 phase 順序：`WAITING_ASSAULT → MINE_CLEARING → BOAT_ASSAULT → OBSTACLE_CLEARING → ASSAULT_LANDING → WAITING_ADMIN_OFFLOADING → COMPLETED`，由事件完成度推進，不依固定時間。
- `MINE_CLEARING`：每艘 Type 082 配一條水際通道，沿途開 4 條灘際通道；走到最後航點（或被擊毀）就 `RTB()`，全部完成才進下一階段。先設 `course`，再指派掃雷任務。
- `BOAT_ASSAULT`：Type 072A / 072III 進 `zone.landing.acv.area` 就釋放衝鋒舟，一條灘際通道配一艘，走水際通道、衝擊發起線轉橫隊、走灘際通道上岸。先設 `course`，再 `Launch`。
- `OBSTACLE_CLEARING`：衝鋒舟都停好後計時，超過 `tuning.obstacle.clearSec` 就把該通道的障礙方塊標成 `cleared`；沒有衝鋒舟的通道不計入也不能走。
- `ASSAULT_LANDING`：兩棲車依 `acvWave` 分波，氣墊船走通道；航線碰到未 `cleared` 的方塊不放行。
- 開局在藍方近海佈雷（`GameApi` 包裝 `ScenEdit_AddMinefield` / 刪除）。
- 新增 Type 529 艦艇與衝鋒舟 DBID，Type 072A / 072III 各載 2 艘；登陸編隊用 Type 082 取代原 Type 529。
- `.scen` 參考點（`LANE_CENTER_*`、`OBSTACLE_*`）缺少時，該區記 log、停在 `WAITING_ASSAULT`，不報錯。
- 新增模組：`routePlanner`、`laneGeometry`、`mineClearing`、`obstacleClearing`、`assaultBoat`、`hovercraft`、`acvWave`；對應設定放 `config.red.amphibOps.tuning`，型別放 `schema.lua`。

## 不做

- 不實作 `WAITING_ADMIN_OFFLOADING` 的絕對安全條件（另有 TODO）。
- 灘頭堡條件先用暫定判斷，之後由 `feat/beachhead-brigade-condition` 取代。
- 不在 CMO 地圖上畫障礙方塊，只存在 state。

## 驗收

- `busted --lua=luajit spec` 全過；各新模組有 spec。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 各 phase 的順序、通道數（一艘 082 = 1 條水際 + 4 條灘際）與速度寫在 `docs/landingOps/assaultTimeline.md`。
