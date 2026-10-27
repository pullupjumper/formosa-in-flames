# fix/control-panel-redeploy-unchanged

## 目標

現在按 control panel 的 Done，前端會把場景裡所有發射單位都當成「已部署」整份送出。Lua 收到後，`addMissileSystems` 把 config 裡每個系統的每個單位都刪掉再用新 GUID 重建。就算玩家只改了 SAM 的 weapon hold/free，單位也全部被換掉。

IADS 的 ctx（C2 節點下的 SAM/radar）只在新存檔 init 時建一次，單位換了 GUID 之後 ctx 還是舊的。結果：通訊干擾每個週期查舊 GUID 都 `Unit not found`，新單位也沒被 IADS 管到。

目標：只有部署位置真的變了的單位才會被刪除重建；其餘單位維持原樣（GUID 不變）。

## 要做到的行為

- 玩家沒動部署位置的發射單位，不出現在 `summaryData.missileSystems`。
- Lua 只刪除重建 `missileSystems` 裡列出的單位，其餘系統、單位不動。
- 只改 weapon hold/free：不刪不建任何單位，只套用 `emconData.sams` 的交戰規則。
- 前端以「單位的部署資料還是不是場景注入的那一份」判斷有沒有動過；沒動過就不送出。部署後又取消、再部署回原位的，會被當成有動過，重建一次也無妨。
- 被重建的單位換了新 GUID，IADS 裡以名稱對應的 SAM/radar ctx 跟著改成新 GUID，節點歸屬與通訊狀態不變；單位沒重建成功就移除它的 ctx。
- 節點指派（`c2Nodes`，以舊 GUID 指名）先於重建套用，重建之後才換 GUID。
- `missileSystems` 為空時，Lua 不呼叫 redeploy（現況已是如此）。
- `emconData.c2Nodes` 維持現行語意：只列 SAM 名單有變的節點，沒變就是空陣列。

## 不做

- 不改 `reassignSamUnits` 與 `collectC2ContextUpdates` 的邏輯。
- 不改 IADS 的 init 時機（仍只在新存檔建一次）。
- 不處理已存在的舊存檔裡的孤兒 ctx；舊存檔重開新的。
- RECON/3 任務指派已另外移除，不屬於這份 spec。

## 驗收

- 開 control panel 只切換 SAM weapon hold/free 後按 Done：log 沒有 `Add missile systems` 的刪除/新增，單位 GUID 不變。
- 移動一個發射單位後按 Done：只有那個單位被刪除重建。
- 移動一個 SAM 後按 Done，再跑到下一個通訊干擾週期，沒有新增的 `Unit not found` 錯誤。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。
