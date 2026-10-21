# refactor/zone-transport-aircraft

## 目標

`coordinator.processTaoyuanTemporarySetup` 不再寫死 Taoyuan。每個作戰區自己帶運輸機與偵察設定，離開 `WAITING_ARRIVAL` 時各自觸發。目前只有 Taoyuan 有偵察、Penghu 有運輸機，Sishu 兩者皆空，先把架子搭好。

## 要做到的行為

### 設定搬進區

- 全域 `config.red.amphibOps.transportAircraft` 移除，改放 `zone.air.transportAircraft`（單一 `SBJ__TransportAircraftDescriptor`，`nil` 表示沒有），與 `transportHelicopter` 同層。
- 新增 `zone.air.reconTemplate`（`string|nil`，值為 `config.red.recon.templates` 的 key）。
- 各區內容：

| 區 | `transportAircraft` | `reconTemplate` |
|---|---|---|
| Taoyuan | `nil` | `"GJ11_RECON"` |
| Sishu | `nil` | `nil` |
| Penghu | 原本的漳浦 AAB IL-76（`AIRLANDING/PENGHU/2/2`） | `nil` |

- `schema.lua`：`SBJ__AmphibOpsConfig` 移除 `transportAircraft` 欄位；區的 `air` 型別加上 `transportAircraft`、`reconTemplate`。

### Coordinator

- `processTaoyuanTemporarySetup` 改名 `processZoneAirSetup`，移除 `zone.name ~= "Taoyuan"` 判斷。
- `zone.air.transportAircraft` 有值才呼叫 `AmphibiousLogistics.transferAndAssignTransportAircraft`；該函式改為接收單一 descriptor（不再收陣列）。
- `zone.air.reconTemplate` 有值才呼叫 `StrikePlanner.addReconEntry`（以 `config.red.recon.templates[reconTemplate]` 取模板）。
- 觸發時機不變：`stepWaitingArrival` 成功轉入 `WAITING_ASSAULT` 時。

### 行為變化

漳浦 IL-76 原本在 Taoyuan 離開 `WAITING_ARRIVAL` 時才轉貨，之後改為 Penghu 離開時才轉貨。

## 不做

- 不填 Sishu 的運輸機與偵察內容。
- 不改 `addReconEntry` 本身；`transferAndAssignTransportAircraft` 只改參數形狀（陣列 → 單一 descriptor），邏輯不變。
- 不動 landingOps 以外的模組。
- 不處理工作區裡其他未提交的 debug 設定。

## 驗收

- `busted --lua=luajit spec` 全過。
- `coordinator_spec` 涵蓋：區有運輸機時會轉貨、沒設定時不呼叫、有 `reconTemplate` 時排偵察、沒有時不排；測試中不再依賴區名。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `docs/landingOps/coordinator.md`（「Taoyuan 特例」改為依區設定）與 `docs/landingOps/amphibiousLogistics.md`（設定來源）同步更新。
- 全專案搜不到 `processTaoyuanTemporarySetup` 與 `amphibOps.transportAircraft`。
