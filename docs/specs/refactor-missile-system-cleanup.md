# refactor/missile-system-cleanup

## 目標

一連飛彈（發射車、補給車、彈藥庫）現在在哪，只記在 ground state 一個地方。config 只當模板，部署時只讀不寫。

以前 redeploy 會把新陣地寫回 live config，存檔不會存 config，所以讀檔後 config 又回到模板。結果有兩個問題：控制面板要另外從 state 補回位置；讀檔後再 redeploy，程式拿 config 的舊陣地去清 zone 和 trigger，真正的舊陣地沒被清掉。熱核審查 F4（`docs/missileSystem/thermo-review-2026-11-04/02_state-and-deployment.md`）也指出部署靠名字猜關係、三種單位各寫一條迴圈。

## 要做到的行為

- 控制面板部署：每一連離開的舊陣地從 state 讀（沒有 state 才用 config）。清掉的是那個陣地的 zone、trigger、bunker。
- 部署前後 config 完全不變（descriptor、陣地 table 都是同一個）。
- 只重設被搬動的那幾連的單位與 state；其他連的 state、reload 計時、彈藥量不變。
- 部署照 config 連結找一連的三個單位，不從名字猜。單位名、生成點、platform、group 和以前一樣（真實 config 比對 603 筆建立呼叫，無差異）。
- 控制面板畫每一連的位置只走 `GroundStateStore.resolveOperationalArea`。
- 匯出 config：`ConfigCodeGenerator.dump(sideName, missileSystemConfigMap)` 指令不變，但改成用 `PersistentState.read` 讀存檔，照 state 的陣地輸出，給 `tools/apply_generated_config.py`；沒有存檔時照 config 輸出。以前能拿到新位置，是因為 redeploy 改了 config；現在 config 不變，所以要從存檔取。`ConfigCodeGenerator` 只在開發用，發佈的 scen 不打包它，所以打包進去的 `MissileSystem` 不碰它。沒搬過任何一連時，輸出和以前逐字相同。

## Log 的改變

- 陣地缺 HA／RL／FP 被拒絕時，summary row 的分母是計畫車數（`0/2`），以前是 `0/0`。
- summary row 是否 FAIL 只看 FAIL row（以前另外用數量再判一次，結果相同）。
- 每筆失敗 row 都帶 `area`。刪除失敗的 row 也一樣。
- `no_resupply_unit_defined`、`no_matching_resupply_unit` 不再出現；連結錯誤改由 `spec/core/missileSystemConfig_spec.lua` 在測試時擋下。
- 建立順序改成一連一連（firing → resupply → ammo），以前是全部 firing、全部 resupply、全部 ammo。
- 沒有任何一連的 system 不再印 summary row。

## 不做

- 不改 state 的形狀（仍是 firingUnits／resupplyUnits／ammunitions 三張表），舊存檔可直接讀。
- `deploySide` 仍是開場用：照 config 重建每一連、重設每一連的 state。

## 驗收

- `init_spec`：讀檔後搬一連，清掉的是 state 的陣地；config 不變；其他連 state 不變。
- `groundStateStore_spec`、`deployment_spec`、`spec/core/missileSystemConfig_spec.lua` 通過。
- 遊戲內：編輯模式部署 → 存檔 → 讀檔 → 再部署同一連，舊陣地的 zone 消失；`ConfigCodeGenerator.dump("China", config.red.ground.missileSystemTypes)` 後跑 `tools/apply_generated_config.py --dry-run`，看到新位置。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
