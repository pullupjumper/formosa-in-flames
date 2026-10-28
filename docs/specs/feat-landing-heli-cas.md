# feat/landing-heli-cas

## 目標

現在攻擊直升機只是機波的護航：跟運輸直升機一起放飛，飛到降落點盤旋，運輸直升機卸完才一起返航。要改成：攻擊直升機的航線快走完時，指派進 CAS 任務，之後由 CMO 任務接管。

運輸機（固定翼）的任務也一併移除，只留轉貨；手動放飛與卸貨另案處理。

## 要做到的行為

- 每區建立一個 CAS 任務，區域用該區的 `air.attackHelicopter.zone`。不再靠劇本預先建好的任務。
- 任務在階段轉換時建立：進入 `BOAT_ASSAULT`、排定機波（`HeliWave.schedule`）的同一刻。
- 攻擊直升機仍由機波放飛，走自己的左右翼航線。距降落點 3 NM 時指派進 CAS 任務（先擬的數值，之後進 CMO 調整）。
- 一旦指派，攻擊直升機的行為完全由 CMO 任務決定，與運輸直升機的卸貨、`RTB` 脫鉤：
  - `isWaveDone` 與「運輸機全部卸完才讓護航返航」都不再看它。
  - 腳本不再對它下 `RTB`，也不拿掉任務。
- 攻擊直升機總數維持 4 架（`escortSize`）：已指派 CAS 的加上還在飛往門檻的，都算。下一波補到 4 架，已滿就不放。
- 數量就是該區攻擊直升機的 `SBJ__HeliState` 筆數，不去查 CMO 任務。攻擊直升機的資料不隨波次清掉，跨波保留。
- 被擊毀時由事件腳本 `src/scripts/score/destroyUnits.lua` 觸發 landingOps 的公開函式，依 GUID 移除該架的 `SBJ__HeliState`，筆數隨之減少。
- 運輸直升機的行為不變：到降落點 `UnloadCargo`，卸完 `RTB`。

## 不做

- 不動氣墊船的流程。運輸直升機只動波數上限（見「後來追加」）。
- 不為運輸機補手動放飛與卸貨。
- 不改運輸直升機的波次大小、放飛時間推算、航線形狀。
- 不寫拿掉任務或 CAS 直升機返航的腳本。
- 不提早讓未指派的攻擊直升機返航：運輸機卸完後，尚未走到門檻的攻擊直升機照樣飛到門檻、指派。

## 待確認

- CAS 任務目前用 `patrol` + `type = "land"` 建立，是否等同想要的 CAS 要進 CMO 確認。
- 攻擊直升機被 CMO 任務帶回去降落、油彈用完、沒被擊毀：筆數不會減少，也就不會補。目前傾向接受，之後在 CMO 觀察。

## 後來追加

- `transportHelicopter.missions` 移除。它只用來決定波數，移除後波數不設上限，放到沒有載貨的運輸機為止，`isFinished` 一併移除。
- `attackHelicopter.missions` 移除；CAS 區域欄位由 `air.casArea` 改為 `air.attackHelicopter.zone`（與其他平台的 `zone` 一致）。
- `transportAircraft.missions` 移除，運輸機只轉貨不指派任務；`transferAndAssignTransportAircraft` 改名 `transferTransportAircraftCargo`。
- 擊毀 Z-10 或 Z-18 都會觸發移除攻擊直升機紀錄，不分地面或空中；舊的 Parked 加分分支拿掉。

## 驗收

- 攻擊直升機指派後，不會讓這一波卡到 `waveTimeoutSec`，下一波照常放飛。
- 進 CMO 確認：攻擊直升機走到門檻後離開原航線，進入 CAS 任務並出現在 `attackHelicopter.zone`。
- 擊毀一架攻擊直升機後，它的資料被移除；下一波補到 4 架，滿 4 架時不放攻擊直升機。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
