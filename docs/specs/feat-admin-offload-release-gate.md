# feat/admin-offload-release-gate

## 目標

行政下卸要等泛水出發線上的船艦與兩棲車輛都釋放完畢才啟動，避免還沒放完就開始卸貨。

## 要做到的行為

- `WAITING_ADMIN_OFFLOADING` 階段，以下三項任一成立就不啟動行政下卸，區域維持在該階段：
  - ACV 區內的 LST／渡輪還載著 ZBD-05 或 ZTD-05（含因波次配額暫停而留在艙內的）。
  - 停泊區內的母艦（Type 075／076／071）還有裝滿貨、尚未出發的 Type 726A 氣墊船。
  - 還有狀態為 `pending` 的突擊艇。
- 三項都不成立時，照舊呼叫 `AdminOffloading.startAdminOffloading`，區域進入 `COMPLETED`。
- 新增 `AmphibiousAssault.hasUnreleasedACV`、`Hovercraft.hasUnlaunchedHovercraft`、`AssaultBoat.hasPendingBoats` 三個判斷函式。

## 不做

- 不改 ACV、氣墊船、突擊艇的釋放流程與數值。
- 不加逾時：釋放卡住時行政下卸會一直等。

## 驗收

- `busted --lua=luajit spec` 全過。
- `coordinator_spec` 涵蓋三種「尚未釋放」都會擋住行政下卸；三個判斷函式各有自己的 spec。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
