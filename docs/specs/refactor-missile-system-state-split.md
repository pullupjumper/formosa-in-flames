# refactor/missile-system-state-split

## 目標

飛彈連的 state 現在是 config descriptor 的整份複製，再加上執行期欄位。建 state 時 `deepCopy` 整本說明書，所以存檔裡帶著武器、彈藥門檻、連結、訊息這些從不改寫的值，執行期程式也從 state 讀它們。看型別分不出哪些會變；改 config 後，舊存檔還是用複製進去的舊值。

目標：state 只存執行期會改寫的值，加上找回 descriptor 用的名字。不會變的值一律回 config 查。這是 `docs/missileSystem/naming-review-2026-11-05.md` N2 的第二步，第一步（只改型別）併在這次一起做。

## 要做到的行為

- state 只存：名字、GUID、單位狀態、作戰區、reload/stow 開始時間、目前彈數。發射車、補給車、彈藥庫三種都一樣。
- 其他值（武器、彈藥門檻、預設彈數、車輛數、配對連結、訊息、DBID）執行期一律從 config descriptor 讀，以 飛彈系統類型 + 單位名字 查。
- descriptor 只描述「要建什麼」；裡面的單位狀態與作戰區明確是開局起始值。
- 改 config 的不變值後讀舊存檔：遊戲用新 config 的值。這是這次唯一刻意的行為改變。
- 讀舊存檔：state 上多出的舊欄位不再被讀，遊戲照常跑。
- 控制面板：部署頁照舊「config 打底、state 的作戰區蓋上去」；重新部署只寫執行期值；狀態表的預設彈數和配對改從 config 查。面板看到的內容不變。
- SIGINT：敵方飛彈發射車的訊息與類型判斷不再從 state 讀，改經 missileSystem facade 取得，不直接碰 missileSystem 的 state 形狀。
- 模組外呼叫端（strikePlanner、landingOps、moveToPosition 腳本）呼叫 facade 的方式若需要多傳 config，一併改；facade 自己解析 config，不把 descriptor 交給外部。

## 不做

- 不改飛彈連的狀態機、移動、會合、隱蔽、補彈規則。
- 不改控制面板前端。
- 不做 N3–N8 的改名。
- 不改 redeploy 只重建被搬動飛彈連的做法。

## 決定

- 舊存檔的舊欄位不刪。`ensureGroundState` 只在編輯模式跑（`src/core/init.lua` 的 `config.isEditMode`），讀舊存檔時不會經過它，沒有地方可以順手刪。舊欄位留在存檔裡，程式不再讀。
- state 的名字在 config 找不到：該單位略過，不中斷整輪。補彈循環記一列 `WARN reason=descriptor_not_found`；到點事件、彈藥統計、控制面板狀態表、SIGINT 清單都直接略過；strikePlanner 看到的是「單位不見」（`sendToFiringPoint`）或 `context_not_found`（`evaluateReadiness`）。
- SIGINT 走 facade：`MissileSystem.listSigintEmitters` 給 {名字、訊息、作戰區}。`SIGINT_TARGETS` 搬進 `ew/sigint.lua`，`PersistentState.sigintEmitters` 刪掉。C2 節點照舊從 `PersistentState.iads` 讀。
- 飛彈單位的 GUID 從來沒有被寫進 state，型別裡也拿掉，不列在 state 欄位內。
- facade 多收 config 的有：`sendToFiringPoint`、`evaluateReadiness`（另收 `sideName`）、`getAmmoInventory`、`processSupplyAssetDestruction`。strikePlanner 經 `FireSupportPlan.process(config, …)` 與 `SBJ__FsemPassContext.config` 傳入；landingOps 的火力閘門把 config 傳給 `getAmmoInventory`。

## 驗收

- 新開局：存檔裡飛彈連 state 只有上面列的執行期值。
- 舊存檔讀檔後跑一輪循環（移動、會合、補彈、隱蔽）、SIGINT 偵測、控制面板開啟與重新部署，行為和改之前一樣，沒有 Lua 錯誤。
- 改 config 某一連的彈藥門檻後讀舊存檔：低彈判斷用新門檻。
- 除 descriptor/state 建構外，missileSystem 與 `ew/sigint.lua` 沒有從 state 讀 config 值的地方。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
