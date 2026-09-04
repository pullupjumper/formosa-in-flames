# 功能盤點 FEATURES

本文件盤點 `src/modules/` 與 `src/scripts/` 已實作的功能，以及已知的缺口。

圖例：✅ 已完成並接線　⚠️ 已實作但有落差　❌ 未完成／未接線

---

## 一、strikePlanner — 從偵察到打擊的完整流程

### 偵察執行（recon.lua）

- ✅ UAV 起飛流程 — 時間到就從基地挑一架整備完成（`readytime_v == 0`）的機體起飛並掛上航線；起飛失敗就等下一個 tick 再試
- ✅ 被擊落判定 — 在任務結束時間（`endTime`）之前消失視為任務失敗，之後消失仍算完成
- ✅ 衛星／SIGINT 被動偵察 — 只依時間結算，不需要派出實際單位
- ✅ **目標追蹤（`Recon.trackTarget`）** — 從 1000nm 內找出最近、且沒被其他任務佔用的同型 UAV，把佇列項目改成追蹤模式並更新航點，讓偵察與打擊接成一個循環
- ✅ 重複追蹤防護（`Recon.isTargetAlreadyTracked`）— 已經有未結算任務在追的目標會直接跳過
- ✅ WZ-8 空中發射（`Recon.launchWZ8`）— 從 H-6N 生成機體、加掛雷達、設定 EMCON、母機返航；中間任一步失敗就把已生成的單位刪掉，不留半成品
- ✅ 衛星過境空檔安排（`Recon.insertEntry`）— 依航線長度與速度估算飛行時間，只有來得及在下次衛星過境前結束的任務才會排進去

### 目標處理（targetingProcess.lua）

- ✅ 固定目標清單掃描 — 一次走訪所有接觸，分類成 Airfield／Port／ISR／SAM／ASM／C2
- ✅ 依距離歸屬 — 用距離門檻把跑道、機堡、彈藥庫歸到所屬的基地或港口
- ✅ 六種動態篩選 — 地面機動、空中預警機、SAM 輻射源、C2 設施、水面目標、SIGINT 測向
- ✅ 戰損評估 — 非第一波會排除標記 `Heavy damage` 與過期的接觸；停機坪（Helipad）改用「上面還有沒有停機」來判斷
- ✅ 與偵察聯動 — 水面目標派 WZ-8、測向目標派 BZK-005，並自動接回 `trackTarget`

### 作戰排程（operationScheduler.lua）

- ✅ 偵察一完成就排定後續的 air／ground operation
- ✅ 波次自動推進 — 解析名稱結尾的 `.../N` 遞增成 `N+1`；找不到下一版 template 就沿用當前版本
- ✅ 重複排程防護 — 同一波次不會出現第二份還沒執行的副本
- ✅ LACM 前置條件檢查 — LACM 兵力還沒投入時，整條 mapping 跳過
- ✅ 火力支援保留機制 — 兩棲作戰需要保留 SRBM 存量時，跳過地面打擊

### 空中打擊（atoBuilder / packageTiming / airTaskingOrder）

- ✅ 機隊佔用紀錄 — 以（基地, 機種 DBID）為鍵，避免同一批飛機被兩個 Wave 重複徵用
- ✅ 整包成立才預約 — 任何一個角色兵力不足就整包放棄，不會出現只湊到一半的攻擊包
- ✅ 基地備援 — 依 `baseGUIDCandidates` 的順序逐一嘗試
- ✅ 時程回推 — 以主攻機的預計到達目標時間（TOT）為基準，往前推算護航機、電戰機、加油機的起飛與到位時間
- ✅ 空中加油會合時間 — 依受油機到加油空域的距離估算，再往前扣掉 `tankerSetupTime`
- ✅ 完整發射流程 — 掛載 → 建立任務（加油機先建）→ 指派目標 → 指派單位 → 套用排程
- ✅ 每個 tick 最多送出一包 — 避免單次呼叫太多 CMO API
- ✅ 打擊後偵察 — 自動安排 BDA 用的 UAV 起飛時間

### 地面火力支援（fsemBuilder / fireSupportPlan）

- ✅ 發射單元四道可用性檢查 — 已被佔用／單位不存在／不在 HIDE 狀態／彈藥不足
- ✅ 跨 FSEM 佔用紀錄 — 同一個發射旅不會被重複指派
- ✅ 開火時間預先算定 — FST 產生的當下就把每個任務的 `startTime` 算好固定住，之後不再變動
- ✅ 過期 FSEM 退役 — 超過時限自動釋放發射單元並送回隱蔽區
- ✅ **TOT 齊射規則** — matrix 內所有發射單元都就位後才允許開火
- ✅ 射後自動收隊 — 寫入 `stowStartTime`，後續撤離交給 missileSystem
- ✅ 單元陣亡清理 — 任務裡的單位被清空就直接結案，不讓 matrix 卡住

### 戰損連動（airbaseAttrition / frontlineRedirect）

- ✅ 機場戰損統計 — 依 `aircraft.base.guid` 歸到所屬基地；基地被毀則該聯隊戰力歸零
- ✅ **前線改道** — 前線基地群損失率達 50% 時，打擊映射改寫成「後方基地起飛 + 空中加油」；改過就固定下來，不會每次重算

---

## 二、missileSystem — TEL 全生命週期

- ✅ 三層部署 — 發射車、彈藥補給車、彈藥儲備點一次建好
- ✅ 動態加掛掛架、清空彈藥與重新分配
- ✅ 陣地觸發器與 zone 自動建立（FP／HA／RL／AHA）
- ✅ MASK 掩蔽區與掩體建物生成
- ✅ 狀態機 — STATIC → REPOSITIONING → HIDE → RELOAD，由「進入陣地」事件推動
- ✅ 進入陣地就清除接觸 — 非 FP 陣地會呼叫 DropContact，模擬進到掩蔽處後失去接觸
- ✅ 陣營差異開關 — 共軍 `isAuto=true` 全自動；台軍 `isAuto=false`，指揮權留給玩家
- ✅ 彈藥鏈 — 低彈量判定 → 發射車再裝填 → 儲備點向補給車轉運 → 整條鏈盤點
- ✅ SRBM 盤點結果已接給 landingOps 的火力支援檢查
- ✅ 戰損結算 — 彈藥庫被毀就歸零、補給車被毀扣掉一車的量
- ✅ 隱蔽與疏散 — 整組 TEL 收進 MASK 區建物（一棟建物只藏一組），要開火前再拉出來
- ✅ 交會判定 — 發射車與補給車在 RL 會合、補給車與儲備點在 AHA 會合，雙向配對
- ✅ 撤收倒數（stow window）— 開火完或彈量不足時先起算倒數，時間到才移動車輛
- ✅ 計時器補記 — 狀態已經是 RELOAD 但倒數沒起算時，當場補上時間

---

## 三、landingOps — 兩棲登陸

- ✅ 五階段狀態機 — MOVING → WAITING_ARRIVAL → WAITING_ASSAULT → WAITING_SECOND_WAVE → COMPLETED，各作戰區各自推進
- ✅ 錨泊佈陣 — 開局就先算好所有座標，六種登陸艦型各自排成網格
- ✅ 071 型位置不足時改用 LST 區 — LPD 區位用完後自動改排到 LST 區
- ✅ 突擊發起條件 — 登陸區敵接觸數低於門檻，或等待超時，符合其中一項即可
- ✅ SRBM 火力支援檢查 — 存量不足、且還有作戰區沒到位時，暫停地面打擊保留彈藥
- ✅ 後勤裝載 — 依艦型規格表（075／076 三筆、071 兩筆）載入氣墊船與直升機並掛進任務
- ✅ ACV 釋放 — 沿指定方位生成兩棲車輛；型別有優先順序（先 ZBD-05 再 ZTD-05），貨物不足就自動減量
- ✅ ACV 空艙返港 — 可釋放數為 0 時自動掛靠母港並 RTB
- ✅ 第二波後勤鏈 — RORO → Barge → 灘頭，包含浮橋架設，浮橋被毀就停止卸載
- ✅ 艦砲火力支援 — 052D 對登陸區與機降區的接觸開放陸攻 WCS，440 發 130mm 平均分配
- ✅ 地面單位轉成貨物 — 完整複製掛架與武器的實際庫存，讓 TEL 能藏進建物

---

## 四、電子戰 EW

### 通訊干擾（commsJamming，僅共軍側）

- ✅ Y-9／J-15D／J-16D 干擾台軍 IADS 下的 SAM 與雷達，每架依距離排序，最多處理 N 個目標
- ✅ 兩種干擾模式 — 全向（依距離冪次衰減）與指向（同時看距離與夾角）
- ✅ 四種狀態 — jammed／resisted／cooldown／recovery
- ✅ 台軍飛機通訊等級模型 — 基礎值 + 干擾機影響 + AEW 加成 + ROCC 加成
- ✅ 通訊劣化強制返場 — 低於門檻就設 `outofcomms` 並 RTB

### GNSS 干擾（gnssJamming，雙陣營共用）

- ✅ 武器進入干擾區 → 抗干擾機率判定 → 判定失敗就在終端航點加上隨機偏移
- ✅ 武器失鎖 — 把 `target.guid` 設成 `"BOL"`
- ✅ 干擾機部署時自動建立圓形 zone，並註冊針對敵方武器的進區觸發器
- ✅ 設施被毀時清除 zone 與觸發器

### SIGINT（共軍 Y-9DZ／美軍 RC-135V）

- ✅ 三段偵測機率 — 門檻內必定偵測、超過最大距離為 0、中間依指數衰減
- ✅ 定位誤差模擬 — 回報座標帶有偏移，模擬三角定位的精度限制
- ✅ 發射狀態判定 — C2 視為持續發射；機動車輛需同時滿足「有航路 + 速度 > 0 + 已離開 RL 區」
- ✅ 偵測次數累積 — 累積到 `maxCount` 才設為 autodetectable，沒偵測到就往回遞減並撤銷
- ✅ 產出的 transmissions 直接提供給 targetingProcess 當目標來源

---

## 五、防空 IADS

- ✅ 中方誘餌 — 每個 C2 部署點生成 3 個「Suspected C2 Facility」，隨機挑一個當真節點
- ✅ 台方兩層架構 — ROCC 掛 SAM 與雷達、TAAOC 掛 MRADS
- ✅ **指揮鏈中斷擴散** — C2 節點被毀時，轄下所有 radar 與 sam 一併設為 `outofcomms`
- ✅ 備援雷達自動啟用 — 兩段優先順序（先專用雷達，再 SAM 雷達），並受距離限制
- ✅ 毀傷同步 — 用 `inArea` 判斷歸屬，並從對應 context 移除

---

## 六、支援模組

### attackManager

- ✅ 多目標的射手輪替分配
- ✅ 四道發射資格檢查 — Doctrine／可用彈量／已分配上限／目標需求已滿
- ✅ 重複投射防護 — 查 `ScenEdit_WeaponAllocation` 彙總已經分配出去的量
- ✅ 不確定區改用 BOL 發射 — 目標帶有 `areaofuncertainty` 時改打最後已知座標

### assignMission

- ✅ 篩選 Embarked 平台並補足任務名額
- ✅ 指派打擊任務前先關閉 mission 再恢復 — 避免 CMO 提前安排起飛

### runwayRepairment

- ✅ 跑道受損登錄（Unit Damaged）
- ✅ 每 5 分鐘依 `percentagePerHour / 12` 遞減損傷並滅火
- ❌ 沒有結束條件 — `startTime` 寫入後不會清除，已經修好的跑道還是會被持續呼叫 `SetUnitDamage`

### unitGenerator

- ✅ 陸基機隊與基地彈庫（先清空再重新填充）
- ✅ SAG 水面作戰群（中方 052D×2 + 054A×2、台方 Kidd + KangDing×2）
- ✅ CSG 航艦打擊群 — 含艦載機、彈庫填充，以及 18 個以航艦為基準的相對座標 RP 綁定
- ✅ 9 種登陸艦與車輛貨載
- ✅ 潛艦 — Type 093B，清除預設魚雷換裝 8 枚 SLCM
- ✅ 港內停泊艦艇
- ✅ 一律「先清除再建立」— 特殊動作可以重複執行，不會疊加

### bearingOnlyLaunch

- ✅ 多枚飛彈方位角平均分配、繞開雷達圈的航路生成
- ✅ 外推重試 — 航路穿過雷達圈或超出射程時，把距離倍率往上加，最多試 10 次
- ❌ 整個模組完全沒有接線，也沒有測試與文件

---

## 七、UI 層

### 戰情儀表板（unit-status）

- ✅ SIGINT 訊號表 — 偵測時間戳、次數、信心度、偵測等級
- ✅ 飛彈系統補給鏈 — 發射單位與補給單位狀態、再裝填進度條，補給車以 rowSpan 合併呈現
- ✅ C2 節點樹 — SAM 與雷達的 OODA 比值、失聯狀態、EMCON、是否已被摧毀
- ✅ 基地彈庫存量
- ✅ 登陸區敵軍計數 — 10 種平台分型別即時計數
- ✅ 沒有資料的分頁自動隱藏

### 佈署規劃選單（setup-menu）

- ✅ OPORD 五段式軍用作戰命令書，含敵軍戰鬥序列、8 項下級部隊任務、MLCOA／MDCOA
- ✅ Leaflet 地圖畫出 CSG 與三支兩棲編隊的進攻軸線與登陸區
- ✅ 遊戲機制說明 — 陣地類型、Cargo Operations 藏車、補給鏈判讀
- ✅ 在地圖上點選佈署飛彈系統與干擾機，自動判定開口角
- ✅ 即時預覽 U 形區／AHA／HA／RL／火力點，用顏色標示是否合法
- ✅ 旋轉模式 — 依游標方位角即時重算佈局
- ✅ 個別戰術區搬移 — 含「HA/RL 必須在 U 形區內」與「HA 與 RL 不得重疊」兩項驗證
- ✅ 台灣本島邊界驗證
- ✅ 預算制 — 以注入時的數量為基準，只對超出的部分計價或退款
- ✅ 摘要匯出 — 組成 JSON 寫進隱藏欄位供 Lua 讀取
- ✅ 表單回寫 — 干擾機重新佈署、機場駐機套用、TEL 作戰區與觸發器重建

### 武器管制選單（emcon-setting）

- ✅ PAC-3／天弓三／TC-2 的 Weapons Free / Hold 切換
- ✅ 同步調整間歇輻射組態（`WakeWhenDetectingThreat` / `UseEmissionInterval`）

---

## 八、事件腳本層

### Regular Time

- ✅ 打擊排程主迴圈 — 單一腳本推動從偵察到打擊的整條流程（動態作戰生成、偵察推進、LACM／SLCM 齊射、FSP、ATO）
- ✅ 登陸作戰狀態機（每 5 分鐘）
- ✅ 通訊干擾迴圈（每 1 分鐘）
- ✅ SIGINT 蒐集 ×2（共軍、美軍）
- ✅ TEL 補給循環 ×2（共軍自動、台軍手動）
- ✅ 跑道定時搶修（雙陣營）
- ✅ 台軍反艦任務觸發判定 — 依 NAI-1 區的敵艦數量設定三批任務的開始時間，設定完就自我停用

### Unit Enters Area

- ✅ WZ-8 釋放並轉移偵察佇列的追蹤對象
- ✅ CSG 進入陣位時切換任務並開啟 LACM 打擊旗標
- ✅ ACV 釋放、艦砲壓制、第二波車輛卸載
- ✅ TEL 陣地事件（由 `initEventTriggers` 動態建立的觸發器）
- ✅ GNSS 武器干擾
- ✅ 登陸成功計分

### Unit Destroyed

- ✅ `destroyUnits.lua` — 全專案戰損連動最集中的地方
- ✅ 分類計分（直升機、偵察機、干擾機、UAV、各型艦艇、潛艦、TEL、干擾車、彈藥車）
- ✅ SIGINT 與干擾機的 context 清理
- ✅ GNSS 干擾區清理
- ✅ 彈藥戰損同步（MLRS／SRBM／GLCM）
- ✅ IADS 重新配置 — 移除 context 並啟動備援雷達；C2 被毀會觸發通聯中斷
- ✅ `taiwaneseAssetIsDestroy.lua` — 台美資產的對應處理

### Unit Base Status

- ✅ 雙方戰機落地後的整備重置（套用 `readytime` 並清除任務歸屬）

### Special Actions

- ✅ 共軍 10 個手動選單 — Setup、Unit Status、加飛機／C2／CSG／干擾機／登陸艦／SAG／潛艦／飛彈系統
- ✅ 台軍 7 個手動選單 — Setup、Unit Status、WCS Setting、加飛機／港內艦艇／SAG／飛彈系統

---

## 九、已知缺口

### 完全未接線

- ❌ `bearingOnlyLaunch.lua` — 整個模組沒有任何呼叫端，也沒有測試與文件
- ❌ `score/playerBreakROE.lua` — 沒有列進 `init.lua` 的 `actionNames`，打包器不會注入
- ❌ `DynamicState.updateReconTriggeredOperationStatus` — 實作完整也有測試，但沒有任何地方呼叫

### 功能空殼／被註解

- ❌ `destroyUnits.lua` 共軍地面單位的分支是空的 `if ... then end`
- ❌ 偵察 UAV 被毀後不會從偵察佇列移除（移除的程式碼被註解掉），已經損失的 UAV 還是會被掃到
- ❌ 共軍飛機落地時的護航機與加油機回收邏輯整段被註解
- ❌ `unitGenerator.lua` 的 `removeJammingZones` / `addGPSJammingZones` 整段註解（功能已改由 ew/gnssJamming 負責，屬於該清掉的殘留程式碼）

### 明確的 bug

- ❌ `addSAGs.lua` 傳入不存在的 `constants.SIDES.CHINA`（值是 nil），共軍 SAG 特殊動作等於壞掉
- ❌ `initAircraftContexts` 把陣營寫死成 `SIDES.PLAYER`，共軍呼叫時會把台灣飛機寫進共軍 context
- ❌ 三個 special action 少了 `SaveTableToKey`（共軍 addACs，以及共台兩支 addMissileSystems），context 的變更下次讀檔就會遺失
- ❌ GNSS zone 清理查的是永遠為空的 `saveData.*.gnssJamming.jammers`（實際部署資料放在 config），一定查不到
- ❌ 跑道修復沒有結束條件
- ❌ landingOps 有三個後勤函式永遠回傳 true，部分步驟失敗時階段還是會照樣往前推
- ❌ `LandingOps.offloadVehicles` 少了 barge 紀錄的 nil 防護
- ❌ `taiwan/aircraftLanding.lua` 少了 nil 檢查（共軍版有）
- ❌ `cycle.lua` 的 `completeFiringUnitReload` 少了 resupplyUnit 的 nil 防護

### 架構層落差

- ⚠️ 通訊干擾只有共軍單向 — 沒有 `config.t.commsJamming`，台軍既沒有干擾機也沒有對應腳本
- ⚠️ IADS 的 `EMCONSetting` / `currOODA` 只寫入初始值就不再更新，只有顯示用途
- ⚠️ `handleTaoyuanTemporarySetup` 把 `"Taoyuan"` 寫死在字串裡，Sishu 與 Penghu 沒有對應處理
- ⚠️ 前端的預算限制只是自己遵守，`createSetupMenu` 完全不讀 `budget` 欄位
- ⚠️ `createCSG` 寫死 18 個 `RP-xxxxx`，違反「不得硬編識別字」的規範
- ⚠️ 共軍 SIGINT 的啟用旗標放在 `saveData.u.sigint.enabled`，沒辦法單獨關掉其中一方
- ⚠️ `matrix.strikeInterval` 產生後固定填 0，執行時也完全不讀，這個欄位沒有實際作用
- ⚠️ `TYPE_072A_2`（DBID 4601）只有半套支援 — 會被算進到位判定，但不會分配錨泊位置，也不能釋放 ACV
- ⚠️ `triggers.lua` 的 CUSTOM_ENVIRONMENT zone 分支是不會執行到的程式碼；`addCustomEnvironmentZone` 的名稱與實際行為不符
- ⚠️ emcon-setting 頁面沒有接注入資料 — SAM 系統是寫死的常數，不讀目前的 WCS 設定，而且會對整個 DBID 全體套用
- ⚠️ `countUnitsInEachArea` 的 10 種平台 DBID 用連續的 `if` 寫死在函式裡，沒有改由 config 驅動
- ⚠️ `docs/` 缺 `runwayRepairment` 的文件
