# refactor/missile-system-naming

## 目標

missileSystem 的彈藥用詞照 MLRS 野戰手冊統一。現在「存彈藥的單位」有七個名字（`docs/missileSystem/naming-review-2026-11-05.md` N1），補給地點叫 AHA（Ammo Holding Area）。手冊把這個地點叫 ATP（Ammunition Transfer Point），彈藥以 canister 為單位。

改成：地點一律叫 ATP；存彈的單位一律叫 canister stock（`canisterStock`）。canister 這個字只指一罐彈，不拿來叫單位。這次連 config、saveData 的 key 一起改（N1 選 B），所以要轉換舊存檔。

## 要做到的行為

- 遊戲裡的行為不變：部署、補給循環、會合、控制面板顯示的數字都和以前一樣。
- 用詞對應：
  - AHA → ATP：陣地欄位、位置類型、區域常數名、移動步驟、log 的 action 名、控制面板標籤。
  - 彈藥庫 → canister stock：型別、config／saveData 的表與連結欄位、battery 欄位、role。
- 不改的：單獨的 `ammo` 指「彈藥數量」（`isLowAmmo`、`ammoThreshold`），照舊；`score/`、`attackManager` 裡的 `ammunition` 是別的意思，不動。
- 舊存檔：`PersistentState` 讀檔時，把舊 key 原地改成新 key。這一步要能重跑，新存檔跑過不會變。轉換只在這一處，其他模組只認新 key。
- 控制面板（`htmls-app`）和 Lua 同一次改。面板送回的資料、注入的資料都用新名字，不留舊名的相容層。
- `.scen` 裡區域的名字（`RP-xxxxx`）不變，不需要改劇本檔。
- `ConfigCodeGenerator` 輸出新 key；`tools/apply_generated_config.py` 能套用。

## Log 的改變

- 移動 action `move_to_ammo_holding_area` 改成 `move_to_ammunition_transfer_point`。
- 讀到舊存檔、做了轉換時，印一行 info。

## 不做

- N2–N8（Descriptor／State 分家、其他改名）。
- 不改 config 的數值，也不改陣地座標。
- 不新增通用的存檔版本機制，只處理這次的 key。

## 驗收

- 拿這次改名前的存檔讀進來：每一連的位置、彈藥量、reload 計時都和讀檔前一樣，可以繼續補給循環。
- `grep` 在 `src/`、`spec/`、`htmls-app/src/` 找不到舊名（`AHA`、`ammunitions`、`ammoDepot`、`SBJ__Ammunition`），上面列的例外不算。
- 遊戲內：編輯模式部署 → 一連打完彈 → 補給車去 ATP、回來重裝成功；控制面板顯示 ATP。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。
