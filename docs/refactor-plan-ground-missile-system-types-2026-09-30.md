# 重構計畫：`ground` 內分出 `policy` 與 `missileSystemTypes`（含 `firingUnit.missileSystem` 新欄位）

> 給另開的 session 執行。動手前先讀完整份，再依「執行順序」逐 phase 做，每個 phase 一個 commit，跑 `busted --lua=luajit spec` 全過才進下一個。

## 1. 為什麼要改

`config.{c,t}.ground` 原本的設計是「領域 → 彈藥種類」。後來擴充後對不上：

- `ground` 底下的 `mlrs`、`srbm`、`mrbm`、`glcm`、`ascm`、`sam` 共用同一套機動車輛邏輯：設置陣地、發射、再裝填、隱蔽。它們放在一起是對的。
- 但 `missileSystemPolicy` 管的是同一套邏輯，卻跟 `ground` 平行放在外面。
- 「missile system」在智庫報告裡指的是一個具體系統（DF-17、DF-26、HIMARS 搭 ATACMS、PAC-3、HF-3），專案裡卻拿它當 `mlrs`、`srbm` 這一層的名字。要把詞義理清楚：類別叫 type，具體系統叫 system。

## 2. 目標形狀

```lua
config.c.ground = {
  policy = { isAuto = true, hideOnEnterHA = true, hideResupplyOnRLNoMeeting = true },
  missileSystemTypes = {
    mlrs = { ... },   -- 原 config.c.ground.mlrs
    srbm = { ... },
    ascm = { ... },
    sam  = { ... },
  },
}
```

- 外層 `ground` 名稱不變。路徑：`config.c.ground.missileSystemTypes.srbm.firingUnits`。
- 每筆 `firingUnits` 多一個字串欄位 `missileSystem`（例：`"HF-3"`、`"Harpoon Coastal Defense System"`、`"HIMARS"`、`"PAC-3"`、`"DF-17"`）。

四層用詞：

| 層 | 詞 | 例 |
|---|---|---|
| 領域 | `ground` | 跟 `surface`、`subSurface` 同一套發射領域命名 |
| 類別 | `missileSystemType` | `mlrs`、`srbm`、`mrbm`、`glcm`、`ascm`、`sam` |
| 具體系統 | `missileSystem`（`firingUnit` 的字串欄位） | `"DF-17"`、`"HIMARS"`、`"PAC-3"`、`"HF-3"` |
| 部隊 | `firingUnit` | `614th Bde, PLARF` |

一筆 firingUnit 的三個身份：

| 欄位 | 是什麼 | 例 |
|---|---|---|
| `dbid` | 發射車平台 | `constants.PLATFORMS.PHL16` |
| `weaponDBID` | 飛彈或火箭 | `constants.WEAPONS.FD280` |
| `missileSystem`（新） | 具體系統名稱 | `"PHL-16"` |

## 3. 命名決定（使用者已確認）

| 舊 | 新 |
|---|---|
| `SBJ__GroundForceConfig`（`mlrs`、`srbm`… 的對照表） | `SBJ__MissileSystemTypeConfig`（欄位 `mlrs`、`glcm`、`srbm`、`mrbm?`、`ascm?`、`sam?`） |
| `SBJ__MissileSystemPolicyConfig` | `SBJ__GroundPolicyConfig` |
| （新） | `SBJ__GroundConfig`：欄位 `policy: SBJ__GroundPolicyConfig`、`missileSystemTypes: SBJ__MissileSystemTypeConfig` |
| `SBJ__MissileSystemConfig`（單一類別：reload、ammunitions、firingUnits…） | **不變** |
| `SBJ__ChinaConfig.ground` / `SBJ__TaiwanConfig.ground` | 欄位名不變，型別換成 `SBJ__GroundConfig` |
| `SBJ__ChinaConfig.missileSystemPolicy` / `SBJ__TaiwanConfig.missileSystemPolicy` | 移除（併入 `ground.policy`） |
| `task.missileSystem`（值如 `"SRBM"`，其實是類別） | `task.missileSystemType` |
| 參數名 `groundForceConfig` / `groundConfig`（傳的是類別對照表） | `missileSystemTypeConfig`（遵守 `docs/naming.md`，不用 `Cfg`） |

命名規則（Phase 6 寫進 `docs/naming.md`）：
- 裝很多個的 key 用複數（`missileSystemTypes`、`firingUnits`、`ammunitions`），單一設定區塊用單數（`policy`）。型別名一律單數。
- 第一層陣營，第二層一個功能（對應 `src/modules/` 一個模組或一個發射領域），第三層只在同功能底下有多個欄位一致的變體時才開。

已知的小瑕疵，使用者知情並接受：`SBJ__MissileSystemConfig` 保留原名，但它描述的是「一個類別」，字面上跟「具體系統」易混。若日後想改，是獨立的一次改名。

**不在範圍內：**
- `lacm`、`slcm`：艦艇與潛艦由 `strikePlanner` 處理，沒有這套機動車輛邏輯，不放進來。
- 目錄 `src/modules/missileSystem/` 與模組名 `MissileSystem` 不改名（它是整個子系統的總稱）。
- `constants.MISSILE_SYSTEM_STATE`、`SBJ__GroundForceContext`、`SBJ__StrikingGroundForceContext`（執行期 / 存檔側）不動。

## 4. 現況（已調查）

- `config.lua`：`config.{c,t}.ground` 出現 306 行；`missileSystem = ` 出現 13 行（fire support task template 內，值是類別字串）。
- `src/modules/missileSystem/init.lua`：約 6 處 `config[field].ground`（249、261、269、284、296、311 行），另有 191、552 行讀 `missileSystemPolicy`。
- 其他讀 `.ground` 的：`src/modules/strikePlanner/airTaskingOrder.lua:439`（`config.c.ground.<...>`，需確認讀哪個欄位）。
- `src/modules/missileSystem/` 內 `statusView.lua`、`setupLayout.lua`、`context.lua`、`deployment.lua` 的參數型別註解用 `SBJ__GroundForceConfig`；參數名 `groundConfig` / `groundForceConfig`。
- `src/utils/configCodeGenerator.lua`：`formatConfigCode`（約 575–600 行）用 `"config." .. sideField .. ".ground." .. sysKey` 組路徑；`@param configPath` 註解與 `format` 的 example 寫 `config.c.ground.mlrs`。**`spec/utils/` 下沒有它的測試。**
- `src/core/saveData.lua`：`saveData.c.ground`（`enabled`、`fireSupportPlan` 與各系統 state 混在同一層）、`saveData.t.ground`（`ascm.test` 等）。
- `src/core/persistentState.lua`：`PersistentState.groundForces(state, sideName)` 回傳 `state[field].ground`，12 處呼叫。
- `strikePlanner` 的 `plannerState.ground` 就是 `saveData.c.ground`（`fireSupportPlan` 在裡面），跟 config 的 `ground` 是不同層概念，別搞混。
- 相關 spec：`spec/modules/missileSystem/*`（`init_spec.lua` 用 `config.t.ground`、`saveData.t.ground`、`missileSystemPolicy`）、`spec/modules/strikePlanner/{fsemBuilder,fireSupportPlan}_spec.lua`、`spec/core/persistentState_spec.lua`。
- 相關 docs：`docs/missileSystem/*.md`、`docs/FEATURES.md`、`docs/naming.md`、`AGENTS.md`。

## 5. 執行順序

**Phase 0 — 準備**
- 目前 branch `refactor/config-score-namespace` 有兩個尚未 push 的 commit（`config.s` → `config.score`、頂層欄位搬進陣營）。先確認它們已合併或 push，再從最新的 `main` / `dev` 切新 branch：`git switch -c refactor/ground-missile-system-types`。不要直接 commit 到 dev/main。
- 跑一次 `busted --lua=luajit spec` 確認基準全過。

**Phase 1 — 補 `configCodeGenerator` 的測試（先保護再改）**
- 新增 `spec/utils/configCodeGenerator_spec.lua`，用 `build-test` skill 的風格。
- 至少覆蓋：對一個小的 ground config 產出正確的 `config.<side>.ground.<sys>.{ammunitions,resupplyUnits,firingUnits}` 區塊；`wpnDefault * 2`、`/ 2` 引用；`ammoThreshold` 引用。
- 這個 phase 只加測試，不改 src。

**Phase 2 — 型別與 config 形狀（只動 config 側，saveData 不動）**
1. `schema.lua`：
   - `SBJ__GroundForceConfig` 改名 `SBJ__MissileSystemTypeConfig`。
   - `SBJ__MissileSystemPolicyConfig` 改名 `SBJ__GroundPolicyConfig`。
   - 新增 `SBJ__GroundConfig`（`policy`、`missileSystemTypes`）。
   - `SBJ__ChinaConfig` / `SBJ__TaiwanConfig`：`ground` 改型別為 `SBJ__GroundConfig`，刪掉 `missileSystemPolicy` 欄位。
   - `SBJ__MissileSystemConfig` 不動。
2. `config.lua`：`config.{c,t}.ground.<type>` → `config.{c,t}.ground.missileSystemTypes.<type>`（306 行，可用 sed，只針對 `mlrs|glcm|srbm|mrbm|ascm|sam` 這些 key；跑完檢查縮排與行寬，必要時在段落頂端加區域別名）。`missileSystemPolicy` 移到 `ground.policy`（初始化 `config.c.ground = { missileSystemTypes = {} }` 之類的骨架要先建好）。
3. 讀取端：`missileSystem/init.lua` 6 處 `.ground` → `.ground.missileSystemTypes`，2 處 policy（191、552 行）→ `.ground.policy`；`airTaskingOrder.lua:439`。
4. `missileSystem/` 內各檔型別註解與參數名換成新名稱。
5. `configCodeGenerator.lua`：路徑改 `"config." .. sideField .. ".ground.missileSystemTypes." .. sysKey`，更新註解與 example。
6. 更新 spec（`init_spec.lua` 的 `config.t.ground`、policy 建構等）。
7. 用 grep 確認 `htmls-app/` 與 `unitStatusUI.lua` 有沒有讀這些路徑。
8. 驗證：`busted` 全過；`grep -rnE 'config\.[ct]\.ground\.(mlrs|glcm|srbm|mrbm|ascm|sam)|config\[[^]]*\]\.ground\b[^.]|missileSystemPolicy|SBJ__GroundForceConfig|SBJ__MissileSystemPolicyConfig' src spec docs` 應該沒有殘留（`.ground.policy` 與 `.ground.missileSystemTypes` 是新路徑，不算）。

**Phase 3 — `task.missileSystem` → `task.missileSystemType`**
- 範圍：`config.lua` 內 13 處、`fsemBuilder.lua`（187、397 行）、`fireSupportPlan.lua`（22、88 行）、`statusView.lua:66`，加上 `SBJ__FireSupportTask*` 相關型別與 spec。
- 這個 phase 必須在 Phase 4 之前完成：Phase 4 會把 `missileSystem` 這個名字重新用在 firingUnit 的具體系統欄位上，兩邊不能同時存在。
- `MissileSystem.getFiringUnitContext(plannerState.ground, <type>, name)` 的第二個參數是類別字串，參數名跟著改。
- 順手把 `missileSystem/` 內註解裡的「missile system type」用語整理成一致。

**Phase 4 — 新增 `firingUnit.missileSystem`**
- 型別：在 firing unit 的 descriptor 型別加 `---@field missileSystem string Missile system designation (e.g. "HF-3")`。
- config：每一筆 `firingUnits` 都補上。**具體名稱要問使用者**，不要自己猜（`PHL-16`、`DF-11A`、`HF-3`、`Harpoon Coastal Defense System`、`PAC-3` 等）；可以從現有的 `dbid` 對應的平台名稱先列一份草稿給使用者確認。
- `configCodeGenerator.formatFiringUnitsBlock`（約 559 行）要序列化這個欄位，並補 Phase 1 的測試。
- 先決定它的用途：目前建議**只給顯示與 log 用**（例如 `statusView`），不驅動邏輯。若使用者要用在別處，另開。

**Phase 5 — saveData（獨立決策，先問使用者）**

`saveData.{c,t}.ground` 有同樣的問題：`enabled`、`fireSupportPlan` 跟各類別的 state 混在同一層。

- **A. 不動（建議先做這個）：** saveData 形狀維持 `saveData.{c,t}.ground.<type>`。零存檔風險。config 與 saveData 的第一層名稱仍是 `ground`，只是 config 多一層 `missileSystemTypes`。`PersistentState.groundForces` 維持原樣。
- **B. saveData 也改成 `saveData.{c,t}.ground.missileSystemTypes.<type>`，並把 `enabled`、`fireSupportPlan` 拆出去**（`fireSupportPlan` 應屬於 strikePlanner）。這會改變存檔形狀：舊存檔載入後會找不到 key。動之前要先查存檔讀取端（`LoadTableFromKey` / `SaveTableToKey`，`core/init.lua` 與各 script）如何處理缺 key，並跟使用者確認是否接受舊存檔失效、是否需要 migration。
- 若選 B：影響 `saveData.lua`、`persistentState.lua`（12 處呼叫）、`schema.lua` 的 `SBJ__GroundForceContext` / `SBJ__StrikingGroundForceContext` / `SBJ__ChinaSaveData.ground`、`plannerState.ground`（strikePlanner 多處：`fsemBuilder`、`fireSupportPlan`、`operationBatch`、`init.lua:135`）、相關 spec。工作量大，建議另開一份計畫。

**Phase 6 — 文件**
- `docs/naming.md` 第 7 節：加上「複數 / 單數」與「第一層陣營、第二層功能、第三層變體」兩條規則（見第 3 節）。
- `docs/missileSystem/*.md`、`docs/FEATURES.md`、`AGENTS.md` 內所有 `config.{c,t}.ground.<type>`、`missileSystemPolicy`、「missile system type」的用語同步更新。

## 6. 驗證清單

- [ ] 每個 phase 結束：`busted --lua=luajit spec` 全過。
- [ ] `spec/moduleBoundary_spec.lua` 仍通過（`missileSystem/` 是 package facade，外部只准 require `init.lua`）。
- [ ] `grep` 確認舊路徑與舊名稱沒有殘留（見 Phase 2 步驟 8；Phase 3 後再加 `task.missileSystem\b`）。
- [ ] `bash bin/build.sh -i`（跳過 scen 注入）確認 bundler 能組出 `slim/main.lua`。
- [ ] 若可在 CMO 內實測：跑一輪 TEL 的設置陣地／發射／再裝填／隱蔽，並產生一次 `configCodeGenerator` 輸出，比對路徑正確。

## 7. 風險

- 306 行 sed 搬移，最容易出的錯是縮排、行寬與註解裡的路徑殘留；靠 grep 與 spec 抓。
- `configCodeGenerator` 沒有測試，改之前一定要先做 Phase 1。
- `plannerState.ground`（存檔）與 `config.*.ground`（設定）名稱相同、概念不同，別一起 sed。
- Phase 3 與 Phase 4 順序不能顛倒（`missileSystem` 一詞的用途會在兩者之間轉換）。
- Phase 5-B 會讓舊存檔失效，必須先問使用者。
- commit 訊息用 Conventional Commit（例如 `refactor: group ground config into policy and missileSystemTypes`），結尾加 `Co-Authored-By` 行；每個 phase 一個 commit。
