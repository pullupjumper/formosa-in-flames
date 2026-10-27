# 功能盤點 features

本文件盤點 `src/modules/` 與 `src/scripts/` 已實作的功能，以及已知的缺口。

圖例：✅ 已完成　⚠️ 已實作但有落差　❌ 未完成

---

## 一、strikePlanner — 從偵察到打擊的完整流程（PLA AI）

### 偵察執行（recon.lua）

- ✅ UAV偵查
- ✅ 衛星偵查、分析SIGINT
- ✅ 分配已完成偵察任務的最鄰近的UAV追蹤打擊目標，提供飛彈導引，形成擊殺鏈
- ✅ 實作H-6N 空中發射 WZ-8超音速無人機的模擬
- ✅ 衛星與衛星之間再訪空窗期，分配UAV偵查

### 目標處理（targetingProcess.lua）

- ✅ 固定目標清單初始化，分類成 Airfield／Port／ISR／SAM／ASM／C2
- ✅ 打擊目標filter，分別有地面機動目標、空中預警機、SAM電磁輻射源、C2節點、水面目標、無線電波源
- ✅ 戰損評估為`Heavy damage` 或者是過時的目標，則不再列入打擊清單
- ✅ 與偵察聯動，水面目標派 WZ-8、無線電源測向目標派 BZK-005等

### 作戰排程（operationScheduler.lua）

- ✅ 偵察完成就排定後續的 air／ground operation
- ✅ Operation波次自動推進，解析名稱結尾的 `.../N` 遞增成 `N+1`；找不到下一波次template就沿用當前波次
- ✅ 當PLA航艦打擊群進入台灣東南海域，啟動水面艦、潛艦、艦載機對佳山、志航基地打擊
- ✅ 火力支援保留機制，兩棲登陸前需要保留一半短程彈道飛彈庫存，以應用於火力壓制敵軍、掩護登陸兵力

### 空中打擊（atoBuilder / packageTiming / airTaskingOrder）

- ✅ 基地戰機任務分配可用性檢查 — 以（基地, 機種 DBID）為鍵，避免同一批戰機被兩個 Wave 重複徵用
- ✅ 打擊包TOT/TOS計算 — 以skriker的預計到達目標時間為基準，往前推算escort、jammer、tanker的起飛與到位時間
- ✅ 完整打擊包流程 — 彈藥掛載 → 建立任務（tanker先建）→ 分配打擊目標 → 指派單位 → 套用任務TOT/TOS時間
- ✅ 打擊後進行BDA，安排UAV進行偵查

### 地面火力支援（fsemBuilder / fireSupportPlan）

- ✅ 所有missile battery是否可分配任務的檢查，正在執行任務／單位不存在／不在 HIDE 狀態／彈藥不足
- ✅ 所有已被分配打擊任務的missile battery的射擊時間點計算
- ✅ 執行打擊任務中的missile battery，若時間超過`observationWindowSec`，則該FSEM強制isFinished，並機動至HA進行掩蔽
- ✅ 若執行該task的missile battery都被摧毀，則該task標記為isFinished，FSEM則照常執行
- ❌ TOT功能實作

### 戰損連動（airbaseAttrition / frontlineRedirect）

- ✅ 機場戰損統計，依 `aircraft.base.guid` 歸到所屬基地；基地被毀則該聯隊戰力歸零
- ✅ **前線機場轉到內陸機場**，前線基地群損失率達50%時，打擊包改由「後方基地起飛 + 空中加油」執行

---

## 二、missileSystem — TEL 全生命週期

- ✅ Missile battery由飛彈發射車、彈藥裝填車、彈藥轉發點組成
- ✅ Missile battery、event、trigger、zone（FP／HA／RL／AHA/MASK）bunker初始化
- ✅ 狀態機 — STATIC → REPOSITIONING → HIDE → RELOAD，由「進入陣地」事件推動
- ✅ 當missile battery被分配打擊任務時，飛彈發射車會從bunker出來，機動至FP
- ✅ 當飛彈發射車射擊完畢，彈藥量低於門檻，然後機動至RL進行再裝填
- ✅ 當飛彈發射車待在FP時，彈藥量沒有低於門檻，且超過`observationWindowSec`，然後機動至HA進行掩蔽
- ✅ 當飛彈發射車機動至RL準備進行再裝填時，彈藥裝填車則會從bunker出來，機動至RL，然後兩者交會進行再裝填
- ✅ 當飛彈發射車裝填完畢則機動至HA進行掩蔽，而彈藥裝填車若彈藥量低於門檻則機動至AHA進行再裝填，否則進行掩蔽
- ✅ 當飛彈發射車裝填完畢時，若是SAM則優先機動至FP展開防空任務，否則機動至HA進行掩蔽
- ✅ 進入陣地就清除contact資訊，模擬進到掩蔽處後敵軍失去目標資訊
- ✅ 戰損結算，彈藥儲存點被毀彈藥數歸零、彈藥裝填車被毀多少輛，則彈藥數就減少多少
- ✅ 利用掩體(bunker)的load cargo功能模擬車輛進入掩體掩蔽，RL以及HA達一定條件會觸發事件執行此功能
- ✅ 當機動發射車準備從FP機動至其他陣地時，會觸發stow window模擬飛彈發射車撤收過程，撤收完畢才機動
- X 機動雷達車定時轉移陣地模擬


---

## 三、landingOps — 兩棲登陸

- ✅ 狀態機 — MOVING → WAITING_ARRIVAL → WAITING_ASSAULT → MINE_CLEARING → BOAT_ASSAULT → OBSTACLE_CLEARING → ASSAULT_LANDING → WAITING_ADMIN_OFFLOADING → COMPLETED，各作戰區各自推進
- ✅ 反水雷（Type 529 走水際通道 + 弓字型）、衝鋒舟上岸、岸上破障、兩棲車分波、氣墊船走通道（掃雷任務、氣墊船 cargo 任務待補）
- ✅ 兩棲作戰編隊初始化以及計算座標起始位置、航線
- ✅ 兩棲作戰編隊海上航渡至指定區域，LPD、LHA乘載區(距岸20-30浬)，LST展開線(距岸11-16浬)
- ✅ LPD、LHA於乘載區展開直升機、氣墊登陸艇換乘作業
- ✅ LHA會分派GJ-11無人機進行登陸目標區偵查，依偵查結果執行戰機打擊登陸目標區的直接火力準備
- ✅ 當機降目標區目標數低於門檻，或等待超時，LST作戰編隊開始戰術展開、SAG展開掩護，航渡至泛水出發線(距岸2-4浬)
- ✅ LST作戰編隊抵達泛水出發線後，兩棲裝甲戰鬥車泛水離艦，SAG則進行直接火力準備，打擊機降及登陸目標區
- ✅ LPD、LHA的直升機及氣墊登陸艇則依作戰編組照預定時間離艦
- ⚠️ 當兩棲裝甲戰鬥車、氣墊登陸艇以及直升機抵達衝擊出發線(距岸1-3浬)後，展開衝擊上陸(flag流程控制沒有做)
- ✅ 當登陸至目標區的數量為營級規模以上，則視為成功建立灘頭堡，然後在展開線停泊的RORO、barge作戰編隊則作為第二梯隊開始向海灘航渡
- ✅ RORO、barge兩棲作戰編隊抵達至目標區後，展開浮橋架設，開始卸載重型合成營部隊
- ✅ 桃園、台南、澎湖多點登陸
- X 掃雷艦隊先進入登陸區域海域進行掃雷，建立安全航道標示，LST作戰編隊、兩棲裝甲車、氣墊登陸艇則沿著安全航道航渡
- ❌ 桃園、宜蘭登陸
- ❌ All in 桃園登陸
- X All in 台南登陸
- X 大量PLA漁船、海警船掩護 (performance issue)
- X 海底生物、民船 (performance issue)
- X 沿岸水雷部署任務 (performance issue)
- X 大量自殺無人艇 (performance issue)
---

## 四、電子戰 EW

### 通訊干擾（commsJamming，PLA AI）

- ✅ Y-9、J-15D、J-16D 干擾台軍IADS轄下的防空系統與雷達，每架依距離排序，最多處理N個目標
- ✅ 兩種干擾模式，全向（依距離冪次衰減）與指向（同時看距離與夾角）
- ✅ 四種狀態為jammed／resisted／cooldown／recovery
- ✅ 台軍戰機通訊等級模型為基礎值 + jammer影響 + AEW 加成 + ROCC 加成
- ✅ 通訊品質惡化強制返回基地，低於門檻就設為失去通聯狀態`outOfComms`

### GNSS 干擾（gnssJamming，雙陣營共用）

- ✅ 武器進入干擾區 → 抗干擾機率判定 → 判定失敗就在終端航點加上隨機偏移
- ✅ jammer、event、trigger、zone初始化
- ✅ Jammer被摧毀時，則移除zone與trigger

### SIGINT（共軍 Y-9DZ／美軍 RC-135V）

- ✅ 三段偵測機率，門檻內必定偵測、超過最大距離為 0、中間依指數衰減
- ✅ 定位誤差模擬，回報座標帶有偏移，模擬三角定位的精度限制
- ✅ 無線電訊號發射狀態判定，C2節點視為持續發射無線電訊號源；機動車輛需同時滿足「有航路 + 速度 > 0 + 已離開RL區」
- ✅ 偵測次數累積，累積到 `maxCount` 才設為 `autodetectable`，沒偵測到就往回遞減並撤銷

---

## 五、防空 IADS

- ✅ 中方誘餌，每個C2部署點生成3個「Suspected C2 Facility」，隨機挑一個當真節點
- ✅ 台方兩層架構，ROCC下轄遠程防空系統與雷達、TAAOC下轄中程防空系統
- ✅ **指揮鏈中斷擴散**，C2節點被毀時，轄下所有雷達與防空系統一併設為失去通聯狀態
- ✅ 備援雷達自動啟用，兩段優先順序（先搜索雷達，然後防空系統射控雷達），並受距離限制


---

## 六、支援模組

### attackManager

- ✅ 多目標的飛彈發射車輪替分配
- ✅ 四道發射資格檢查 — Doctrine／可用彈量／已分配上限／目標需求已滿
- ✅ 重複投射防護 — 查 `ScenEdit_WeaponAllocation` 彙總已經分配出去的量
- ✅ 不確定區改用 BOL 發射 — 目標帶有 `areaofuncertainty` 時改打最後已知座標

### runwayRepairment

- ✅ 跑道受損自動修復
- ✅ 戰備道設置

---

## 七、UI 層

### 控制面板（control-panel）

單一頁面整合原本的戰情儀表板、佈署規劃、武器管制與新增單位選單。

- ✅ OPORD 五段式軍用作戰命令書，含敵軍戰鬥序列、8 項下級部隊任務、MLCOA／MDCOA
- ✅ 遊戲機制說明
- ✅ Jammer、Missile battery 陣地部署，戰機掛載部署（地圖操作）
- ✅ SIGINT無線電訊號表 — 偵測時間戳、次數、信心度、偵測等級
- ✅ 飛彈發射車狀態 — 單位狀態、飛彈數量、再裝填進度條
- ✅ C2 節點 — SAM與雷達的失聯狀態、EMCON、是否已被摧毀
- ✅ SAM Weapons Free / Hold 切換，同步調整間歇輻射組態（`WakeWhenDetectingThreat` / `UseEmissionInterval`）
- ✅ 登陸區敵軍計算（僅共軍；遊玩模式不顯示）
- ✅ 新增單位（Add Units）— 加飛機／C2／CSG／干擾機／登陸艦／SAG／潛艦／飛彈系統（僅編輯模式）
- ✅ 編輯／遊玩模式 — `config.isEditMode = true` 無任何限制；`false`（`bash bin/build.sh -p`）隱藏 Landing Units 與 Add Units，且 Jammer／飛機／飛彈發射車部署只能提交一次，之後鎖定（`saveData.<side>.isDeploymentLocked`）

---

## 八、事件腳本層

### Special Actions

- ✅ 共軍、台軍各 1 個手動選單 — Control panel

---
