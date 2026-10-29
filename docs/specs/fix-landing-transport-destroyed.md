# fix/landing-transport-destroyed

## 目標

landingOps 追蹤的單位被擊殺後，不再每個 tick 噴 `Unit not found with name` ERROR。

原因：`GameApi.ScenEdit_GetUnit` 找不到單位會 `error`，被 `tryCall` 記成 ERROR 再回 `nil`。第一步只修了 heliWave（擊殺事件移除運輸機）。其他登記表各自處理死亡：ACV 輪詢時刪、assault boat 標 `LOST`、minesweeper 標 `isDone`、lane slot 每次排路線都查持有者、hovercraft 完全不處理（每 tick 查死掉的氣墊船）。「哪些單位歸 landingOps 管」還寫死在 `destroyUnits.lua` 的 DBID 名單。

改成：擊殺事件為主，所有登記表在同一處忘掉死掉的 GUID；輪詢當事件沒趕上時的後備，第一次查不到就刪掉，之後不再查。

「死掉要刪哪些地方」集中在 landingOps 內一個模組（TrackedUnits），它知道每個登記表的形狀；擊殺事件和各模組的輪詢都經過它。原因：分散在各模組時，輪詢只刪自己那張表，停車位等其他登記表留著死 GUID，會再被查一次。代價：新增登記表時要在這個模組加一筆。

## 要做到的行為

- 擊殺事件（任何類型的單位）一律交給 `LandingOps` facade；facade 自己判斷這個 GUID 有沒有被 landingOps 記錄，`destroyUnits.lua` 不再挑 DBID。
- 一次擊殺，從所有區的所有登記表忘掉該 GUID：ACV、assault boat、hovercraft、攻擊直升機、運輸直升機、運輸機、minesweeper、lane 停車位。
- 「忘掉」一律是整筆刪掉，不標 `LOST`／`isDone`。所有登記表同一條規則。
- 忘掉之後，各自的「完成／配額」判斷和現在把它當成已擊殺時一樣（ACV 配額回補、boat 不再擋全部到岸、sweeper 不再擋掃雷完成、停車位可再分配、一波直升機照舊結束）。
- 已刪掉的 boat，它的母船不再算進第一波直升機的起飛時間；最遠的母船只剩死掉的 boat 時，直升機會稍早起飛。接受這個差別。
- 停車位的持有者被擊殺時，擊殺事件當下就空出該位，不等下次排路線才發現。
- 沒有紀錄的 GUID 不報錯，回 `false`。
- 輪詢遇到查不到的單位：當成已擊殺，同樣整筆刪掉。不論哪個模組先查到（包括排路線時查停車位佔位者），從該區所有登記表一起刪掉，所以每個死掉的單位最多記一筆 ERROR（輪詢比事件先到時）。
- 輪詢只清查到它的那一區；一個 GUID 只會登記在一區。
- 下列沿用第一步，行為不變：
  - 運輸直升機、運輸機的下一波架數只看候選，不看 `units`。
  - `GameUtils.isCargoUnloaded` 要求 `UNDERWAY` 且 `cargo == nil`。
  - 攻擊直升機的移除。

## 不做

- 不動 `GameApi`：不改 `ScenEdit_GetUnit` 的 `error` 行為，也不加不記 ERROR 的查詢（`GameApi` 只包 CMO API）。
- 不處理 landingOps 以外的 `Unit not found`（`startMineClearing` 的 `GetMission`、UAV 的 `GetUnit`）。
- 不合併載運生命週期（heliWave／airlift／hovercraft 的 CargoRun），那是另一個改動。
- 不動 `destroyUnits.lua` 的計分。
- 不處理不在登記表裡的單位查不到時的 ERROR（例如衝鋒舟的母船沉了）。

## 驗收

- 在 CMO 擊沉一艘氣墊船、擊毀一輛 ACV，之後的 session log 對它的 GUID 最多一筆 `Unit not found`，不再每個 tick 出現。
- 新增一種運輸機型時，不用改 `destroyUnits.lua`。
- `busted --lua=luajit spec` 全過。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 同步更新 `docs/landingOps/` 下受影響模組的「狀態」段，新模組有自己的文件並列進 README。
