# 重構計畫：`SBJ__GroundContext` 內分出 `missileSystemTypes`（原 Phase 5-B）

> 接續 `refactor-plan-ground-missile-system-types-2026-09-30.md`（該計畫 Phase 1–4、6 已完成，Phase 5 未做）。

## 1. 目標形狀

```lua
saveData.c.ground = {
  enabled = true,
  fireSupportPlan = {},          -- 見「決策 2」
  missileSystemTypes = {
    mlrs = { ... },              -- 原 saveData.c.ground.mlrs
    srbm = { ... },
  },
}
```

與 `config.{c,t}.ground.missileSystemTypes` 同形。

## 2. 為什麼

`SBJ__GroundContext` 同一層混了三種東西：`enabled`（開關）、`mlrs`/`srbm`…（飛彈類別狀態）、`fireSupportPlan`（strikePlanner 資料）。全部用 `groundCtx[type]` 字串索引，靠 key 不撞名才安全；要走訪所有類別時也得靠 `constants.MISSILE_SYSTEM_TYPES` 過濾。

## 3. 存檔風險（已調查）

- 存檔只有一個 key：`PersistentState` 的 `SAVE_KEY = "SaveData"`，讀寫都經 `gKH.State.LoadTableFromKey / SaveTableToKey`。`load()` 只檢查整包是否 nil，**沒有任何 per-key 缺值處理或版本欄位**。
- `src/core/init.lua:14-19`：`config.isSaved`（`config.lua:8`，目前 `true`）為真時，會 `ensureGroundForceState` 後 `PersistentState.reset(saveData)`，也就是用預設值覆寫存檔。
- **待實測（動手前必做）：** `init.lua` 在「每次載入 .scen 都跑」還是「只有開新局才跑」。若每次載入都跑，存檔本來就會被 reset，形狀改變不構成舊存檔問題；若只在開新局跑，舊的進行中存檔載入後會找不到 `ground.missileSystemTypes`。用 `Scen Loaded` 事件的觸發時機與 CMO 讀檔行為確認，別靠推測。

## 4. 待使用者決策

1. 舊的進行中存檔：接受失效，還是要 migration（載入時偵測舊形狀並搬移）？依第 3 節實測結果決定。
2. `fireSupportPlan` 是否同時搬出 `ground`（建議屬於 strikePlanner）？建議**先不搬**，只包 `missileSystemTypes`，存檔形狀只動一次；搬 `fireSupportPlan` 另案。
3. 是否加存檔版本欄位（`saveData.version`），讓日後形狀變動可偵測？（`SBJ__Config.version` 已在工作區未 commit 的改動中，可參考。）

## 5. 範圍

- `src/core/saveData.lua`：`saveData.{c,t}.ground.<type>` → `.ground.missileSystemTypes.<type>`（`ascm.test` 等），`enabled` 保留。
- `src/core/schema.lua`：`SBJ__GroundContext` 改成 `enabled` + `missileSystemTypes: SBJ__MissileSystemTypeContext`（新型別，欄位 `mlrs`/`srbm`/`mrbm?`/`glcm`/`ascm`/`sam?`）；`SBJ__StrikingGroundContext`、`SBJ__ChinaSaveData.ground`、`SBJ__TaiwanSaveData.ground` 跟進。
- `src/core/persistentState.lua`：`groundForces`（line 99）維持回傳 `ground`；`enemy.ground[system]`（line 120）→ `.ground.missileSystemTypes[system]`。12 處 `groundForces` 呼叫端逐一檢查。
- `src/modules/missileSystem/`：`groundCtx[type]` 的索引點：`init.lua`（119、133、169、204、321）、`statusView.lua`（47、57）、`context.lua`（65、73、88、96、103）。建議入口統一取 `groundCtx.missileSystemTypes` 後再索引，或讓 facade 只收 `missileSystemTypes` 那層（跟 config 側 `missileSystemTypeConfig` 對稱）。
- `src/modules/strikePlanner/`：`fireSupportPlan.lua`（22、88）、`fsemBuilder.lua`（187、397）傳給 `getFiringUnitContext` / `startStow` 的 `plannerState.ground` 要改成 `.ground.missileSystemTypes`；`plannerState.ground.fireSupportPlan` / `.enabled` 不動。
- `src/modules/landingOps/coordinator.lua:164-165`：`landingState.ground` 傳給 `getAmmoInventory`，同上。
- spec：`persistentState_spec`、`missileSystem/*`、`strikePlanner/{fsemBuilder,fireSupportPlan,init,operationType,dynamicPlan}_spec`、`landingOps/{coordinator,init}_spec`、`unitStatusUI_spec`。
- docs：`docs/missileSystem/*.md`、`docs/strikePlanner/*.md` 中的 `saveData.*.ground.<system>`。

## 6. 執行順序

1. 實測第 3 節的待確認項，並取得決策 1–3。
2. 先補測試：`persistentState_spec` 涵蓋 `groundForces` 與 SIGINT 目標取值（line 120 路徑）。
3. schema 與 `saveData.lua`。
4. `missileSystem/` 內部改讀 `missileSystemTypes`；facade 簽名決定後一次改完。
5. `strikePlanner`、`landingOps` 呼叫端。
6. spec 與 docs。
7. 每步 `busted --lua=luajit spec` 全過；最後 `bash bin/build.sh -i`；若可在 CMO 內實測，跑開新局、存檔再讀檔各一次。
8. 殘留檢查：`grep -rnE "ground\[[^]]*(system|type|Type)" src` 與 `saveData\.[ct]\.ground\.(mlrs|glcm|srbm|mrbm|ascm|sam)`。

## 7. 風險

- 沒有 per-key 缺值處理，形狀一改，讀舊存檔的路徑會直接 index nil。
- `plannerState.ground`、`landingState.ground`、`config.*.ground` 名稱相同、層級不同，別一起 sed。
- `groundCtx[string.lower(type)]`（`init.lua:133`）大小寫容錯要保留。
- 每個 phase 一個 commit，commit 前先開 branch（`refactor/ground-context-missile-system-types`）。
