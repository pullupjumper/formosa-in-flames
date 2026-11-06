# refactor/ui-contract-types

## 目標

控制面板和 Lua 之間往返的資料，型別現在兩邊各寫一份，大約 20 個，全靠人手對齊。改了一邊，另一邊不會報錯。有 4 組名字對不上（`TacticalAreaLayout`/`TacticalAreas`、`MovementPathSet`/`MovementPaths`、`GNSSJammerDescriptor`/`JammerResult`、`AirbaseDeploymentDescriptor`/`Airbase`）。注入頁面的 9 包資料裡，有 6 包在 Lua 沒有型別。飛彈部署會把整份 `SBJ__MissileSystemConfig` 傳給前端，但前端只用到 4 個欄位。

目標：Lua 是唯一來源。往返前端的型別只寫在 `schema.lua` 的一個區塊，TS 型別由工具產生，所以兩邊名字一定一樣。這也是 `docs/missileSystem/naming-review-2026-11-05.md` N4 的後半段。

## 要做到的行為

- `schema.lua` 有一個「UI 介面」區塊。往返前端的型別都在這個區塊，也只有這個區塊會被拿去產生 TS。
- 注入頁面的 9 包資料、玩家送回的結果，在 Lua 都有型別，而且都在這個區塊裡。
- 工具讀這個區塊，產生前端的型別檔。名字規則：`SBJ__X` 變成 `X`，`CMO__Location` 變成 `Coordinate`。工具看不懂的註解會直接報錯，不會猜。
- `bin/build.sh` 在 build UI 之前先產生型別檔。產生的檔案會 commit，所以只開前端也能編譯。
- schema 改了卻沒重新產生：測試會失敗。
- 名字對不上的 4 組，都改成 Lua 那邊的名字。前端手寫的同義型別刪掉，改 import 產生的型別。
- 飛彈部署的注入資料只傳每個發射車的名字、作戰區、飛彈系統類型、武器射程，不再傳整份 config。
- 前端自己用的型別（props、reducer state、地圖用的型別）照舊手寫，不放進產生的檔案。
- 控制面板看到的內容、送回的結果、遊戲行為都不變。

## 不做

- 不改存檔形狀，也不改 config 形狀。
- 不改注入的方式：`string.format` 依序填 `window.__INJECT_*__` 的做法照舊。
- 不改送回 Lua 的 JSON 欄位名，只改型別的名字。
- 不處理 N5–N8，只有 `BatteryStatus` 裡被 N8 點名的欄位例外（見決定）。

## 決定

- `SBJ__BatteryStatus` 保留原名（彙整一個砲連的發射車、裝填車、彈箱）。
- 它的欄位統一成「哪台車 + 什麼」，預設值加 `Default`，時間寫明分鐘。`firingUnitState` 原本裝的是字串標籤，不是 state 物件，所以改成 posture，對上 `MISSILE_UNIT_POSTURE`。送給前端的 JSON 欄位名跟著改，前端一起改：
  `firingPosture`、`resupplyPosture`、`resupplyMissiles`、`resupplyMissilesDefault`、`canisterMissiles`、`canisterMissilesDefault`、`firingReloadMinutes`、`resupplyReloadMinutes`、`reloadMinutesDefault`。
- 產生的檔案是 `htmls-app/src/types/generated.ts`，檔頭註明不要手改。
- 區塊用 `-- UI_CONTRACT_BEGIN` / `-- UI_CONTRACT_END` 包住。區塊外的型別只有 `CMO__Location`、`CMO__Waypoint`（對成 `Coordinate`）和 `SBJ__C2TypeKey`（對成 `string`）可以用。父類別在區塊外時，前端只拿到區塊裡寫的欄位。
- 名字會撞到 Lua 既有型別的面板資料，加上 `Panel` 前綴：`SBJ__PanelFiringUnit`、`SBJ__PanelOperationalArea`、`SBJ__PanelPosition`。集合照 `docs/naming.md` 用單數：`C2NodeSet`、`LandingUnitCountSet`、`PanelMissileSystemSet`。
- 機場另外定 `SBJ__Airbase`，欄位都是必填。config 的 `SBJ__AirbaseDeploymentDescriptor` 欄位都是選填，因為船也共用它。
- SAM 和雷達分成兩個型別，只有 SAM 有 `weaponFree`（`SBJ__C2SamUnit`）。
- 雷達卡片顯示「HOLD FIRE」是既有的錯誤：Lua 從來沒有送雷達的 `weaponFree`。這次照舊顯示，另外處理。

## 驗收

- 往返前端的型別，前端沒有手寫的版本，全部來自產生的檔案。
- 改 `schema.lua` 區塊裡任何一個欄位卻沒重新產生：測試失敗。
- 打開控制面板：部署、訊號、C2、砲連狀態、登陸數量顯示都跟改之前一樣。送出部署後，遊戲的結果也跟改之前一樣。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。

## 第二步：飛彈連合併成一包

### 目標

飛彈連的資料原本用兩包注入頁面，型別有 6 個：`PanelMissileSystemSet` → `PanelMissileSystem` → `PanelFiringUnit` → `PanelOperationalArea` → `PanelPosition`，另外還有 `BatteryStatus`。前端再用名字把兩包對起來（`buildStatusLookup`），也要把 Lua 的作戰區轉成地圖形狀（`fromOperationalArea`）。Lua 先拆開，前端再拼回來。

### 要做到的行為

- 注入頁面的飛彈資料只有一包：`SBJ__PanelBattery[]`。每一連帶名字、飛彈系統、系統類型、射程、`placement`（地圖形狀的陣地）。部署過的再帶 `status`。
- `SBJ__BatteryPlacement`（`center`、`openingAngle`、`tacticalAreas`、`paths`）進出共用：Lua 送出的陣地、前端地圖上的部署、玩家送回的 `SBJ__MissileSystemResult` 都是這個形狀。
- 作戰區轉地圖形狀的工作改由 Lua 的 `PanelBattery.buildPlacement` 做，它是 `buildOperationalArea` 的反向。來回兩個方向放在同一個檔案裡。
- 控制面板看到的內容、送回的 JSON、遊戲行為都不變。

### 不做

- 回程不送整個 battery。`status` 是唯讀的，descriptor 由 Lua 用名字查 config（`Deployment.resolveBattery`）。
- Lua 內部的 `SBJ__Battery`、descriptor、state 型別不動。

### 決定

- `controlPanelLayout.lua` 和 `statusView.lua` 合成 `panelBattery.lua`（模組 `PanelBattery`）。狀態只有這裡用到，分開只會多一個檔案。
- `__INJECT_MISSILE_SYSTEMS__` 改名為 `__INJECT_BATTERIES__`，`__INJECT_BATTERY_STATUSES__` 刪掉。
- `SBJ__BatteryStatus` 拿掉 `name` 和 `missileSystemType`，因為它已經放在所屬的 battery 裡。
- `SBJ__MissileSystemResult` 繼承 `SBJ__BatteryPlacement`，送回的 JSON 欄位不變。
- 前端的 `MissileDeployment` 繼承 `BatteryPlacement`，只多出身分和 ATP 的欄位。
- Lua 的 JSON 會把空 table 寫成 `{}`。44 個作戰區裡有 25 個沒有 SHRL，所以前端在 `buildInjectedDeployments` 把 SHRL 的 `{}` 讀成 `[]`。
- zone 名字找不到參考點時，以前會把名字原樣送給前端，現在送空的頂點列表。只有壞掉的資料會碰到這個情況，以前的版本在地圖上一樣畫不出來。

### 驗收

- 舊的前端 `fromOperationalArea` 對 mock 的 3 個連算出的結果，跟新的 Lua `buildPlacement` 算出的完全一樣。
- 真的 config（台灣 25 連、中國 19 連）經 Lua JSON 進前端後，每條路徑都是陣列，中心點都是有限數字。
- `busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i`、`npm test`、`npm run lint` 都通過。

## 第三步：面板型別對齊 config 與 Lua 作戰區

### 目標

面板和 Lua 對同一個東西用不同的名字和形狀。前端的部署叫 `MissileDeployment`、欄位叫 `unitname`，Lua 和 `PanelBattery` 叫 `name`。路徑和區域在前端是單一物件，Lua 作戰區每種陣地（FP、HA、ATP、RL、SHRL）都是陣列。前端的 `RL[i]` 是「第 i 個發射點回重裝點」，Lua 的 `RL[i]` 是「第 i 個重裝陣地」，而 `buildOperationalArea` 只讀 `RL[1]`。這一步把面板的命名和形狀對齊 Lua，保留以後一種陣地有多個的彈性。

### 要做到的行為

- 面板型別規則照 `docs/naming.md` §6：能用 config 型別就用，config 沒有的資料才另外定義；送出和送回共用型別，送回的比較小就抽出共用的小型別。
- 前端的砲連部署改叫 battery，身分欄位用 `name`。部署 map 的 key 只用 `name`，不再加系統類型。
- 同一陣營的發射車名字不能重複，有測試直接檢查真的 config。
- 路徑每種陣地都是路徑陣列，區域每種陣地都是多邊形陣列，key 用陣地代號（FP、HA、ATP、RL），跟路徑和 Lua 一樣。`uShapeVertices`、`shelterPoints` 不變。
- 目前 HA、ATP、RL、SHRL 都只有一個，前端只產生一個，Lua 照陣列逐一建立。
- `RL[i]` 的意思改成第 i 個重裝陣地，跟 Lua 一樣。送出的 `RL[0]` 跟現在送的 `RL[0]` 是同一組點。
- 「每個發射點回重裝點」的線只給地圖畫，不放進往返的資料：
  - 剛畫好的砲連：照現在的算法，從發射點中心繞開 ATP、HA 到重裝點中心。
  - 讀檔進來的砲連：照現在 Lua `buildPlacement` 的拼法，發射點路徑終點接上 `RL[0]` 路線。
- 地圖上每一條線、送出後遊戲裡單位的路線，都跟改之前一樣。

### 不做

- 不改存檔形狀和 config 形狀，Lua 作戰區不動。
- 不改單位從 FP2 以後回重裝點時走 FP1 那條路線的現況。
- 不處理 `SBJ__AirbaseDeploymentDescriptor` 被機場和船共用的問題（naming review N9）。

### 決定

- 推翻第一步的「機場另外定 `SBJ__Airbase`」：面板直接用 `SBJ__AirbaseDeploymentDescriptor`，跟干擾機用 `SBJ__GNSSJammerDescriptor` 一致。沒有座標的機場地圖上不畫。
- 送回的砲連改用 `SBJ__PlacedBattery`（名字、系統類型、`placement`），`SBJ__PanelBattery` 繼承它。`SBJ__MissileSystemResult` 刪除，`ControlPanelResult` 的欄位改叫 `batteries`，不再送 Lua 沒讀的 `key`。
- ATP 的 `atpCenter`、`atpRadius` 維持單一，對應 ATP 的第一個區域。
- 送回的砲連沒有 SHRL 時，Lua 作戰區就不放 SHRL，補給車離開掩體改走 RL。以前會放一條空路線，補給車停在原地。只有搬動區域後找不到掩體出口的砲連會碰到。

### 驗收

- 同一份 mock 和真的 config（台灣 25 連、中國 19 連）：改前改後地圖上每條路徑的點完全一樣，送回 Lua 的 `RL[0]` 也一樣。
- 遊戲裡：控制面板搬一個砲連、存檔再讀檔，地圖上的線跟改之前一樣，機場正常顯示。
- `busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i`、`npm test`、`npm run lint` 都通過。
