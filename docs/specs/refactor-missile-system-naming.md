# refactor/missile-system-naming

## 目標

missileSystem 的彈藥用詞照 MLRS 野戰手冊統一。現在「存彈藥的單位」有七個名字（`docs/missileSystem/naming-review-2026-11-05.md` N1），補給地點叫 AHA（Ammo Holding Area）。手冊把這個地點叫 ATP（Ammunition Transfer Point），彈藥以 canister 為單位。

改成：地點一律叫 ATP；存彈的單位一律叫 canister stock（`canisterStock`）。canister 這個字只指一罐彈，不拿來叫單位。這次連 config、saveData 的 key 一起改（N1 選 B），所以 `.scen` 也要轉換。

## 要做到的行為

- 遊戲裡的行為不變：部署、補給循環、會合、控制面板顯示的數字都和以前一樣。
- 用詞對應：
  - AHA → ATP：陣地欄位、位置類型、區域常數名、移動步驟、log 的 action 名、控制面板標籤。
  - 彈藥庫 → canister stock：型別、config／saveData 的表與連結欄位、battery 欄位、role。
- 不改的：單獨的 `ammo` 指「彈藥數量」（`isLowAmmo`、`ammoThreshold`），照舊；`score/`、`attackManager` 裡的 `ammunition` 是別的意思，不動。
- `.scen` 裡有舊名字：arrival 事件 `(China|Taiwan) Arrive in AHA`、它們的 trigger、`AHA/...` zone，以及 `.scen` 自帶的 SaveData 裡的 `ammunitions`、`ammunition`、`AHA` key。程式靠這些名字認位置、找要刪的 zone，所以必須一起改。
- 用一次性工具 `tools/rename_scen_missile_terms.py` 改 `.scen`，程式碼裡不留讀檔轉換。工具重跑不會再改任何東西。
- 遊戲中途存的 `.save` 不支援：裡面的 trigger 名字是舊的，沒辦法在讀檔時修。
- 控制面板（`htmls-app`）和 Lua 同一次改。面板送回的資料、注入的資料都用新名字，不留舊名的相容層。
- `.scen` 裡參考點的名字（`RP-xxxxx`）不變。
- `ConfigCodeGenerator` 輸出新 key；`tools/apply_generated_config.py` 能套用。

## Log 的改變

- 移動 action `move_to_ammo_holding_area` 改成 `move_to_ammunition_transfer_point`。
- 彈藥庫被擊毀的 log：`role=ammo_depot` 改成 `role=canister_stock`。
- 部署 summary 欄位 `ammo=` 改成 `canister_stock=`；火力支援暫停（`fireSupportGate`）的欄位 `depot` 改成 `canisterStock`。
- 步驟名 `failAmmoDepotStateNotFound` 改成 `failCanisterStockStateNotFound`，它的 reason `ammo_context_not_found` 改成 `canister_stock_state_not_found`。
- 控制面板資料欄位 `missilesInAHA` 改成 `missilesInCanisterStock`（存的是彈罐庫存的彈量，不是地點）。

## 不做

- N2–N8（Descriptor／State 分家、其他改名）。
- 不改 config 的數值，也不改陣地座標。
- 不新增存檔版本機制，也不在讀檔時轉換舊 key。

## 驗收

- 工具跑完，解開 `.scen` 找不到 `Arrive in AHA`、`AHA/` zone，SaveData 裡沒有舊 key；把新名字換回舊名字後，和原檔逐 byte 相同。
- `grep` 在 `src/`、`spec/`、`htmls-app/src/` 找不到舊名（`AHA`、`ammunitions`、`ammoDepot`、`SBJ__Ammunition(Unit|State)`），上面列的例外不算。
- 遊戲內：編輯模式部署 → 一連打完彈 → 補給車去 ATP、回來重裝成功；控制面板顯示 ATP。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。
