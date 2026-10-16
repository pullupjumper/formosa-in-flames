# amphibOps 設定重構計畫

## 目標

1. 一個戰區 = 一個 `Zone`，取代 `operations[]` + `operationalZones[]` + `sags{}` 靠名字字串對應的三表結構。
2. `SBJ__AmphibiousOperationDescriptor` 的 `from.areas[i]` 與 `SBJ__SAGDescriptor` 的 `from` 共用同一個 placement 形狀。
3. landingOps 內部函式只收 `zone` 與所需的小設定表，不再傳整個 `SBJ__Config` / `SBJ__AmphibOpsConfig`。
4. 行為不變：重構前後 `busted --lua=luajit spec` 結果一致，存檔格式不變。

## 不變的東西

- `from.areas[]` / `to.areas[]` 陣列結構保留（同一登陸水域可有多個船團）。
- `saveData.red.amphibOps.zoneStates` 以 zone name 為 key，不動，舊存檔相容。
- `config.red.amphibOps` 的位置不變，只重排內容。

## 目標結構

```
config.red.amphibOps
├─ periodSec, isTesting, fireSupportHoldThreshold
├─ formation      全域排列規則（間距、航速、命名 heading 表）
├─ tuning         route / mineClearing / assaultBoat / obstacle / acvWave
├─ cargo, transferCargo, missionStartTime, minefields, transportAircraft
└─ zones[]
   └─ Zone
      ├─ name
      ├─ fleet     stagingFilter, from.areas[], to.areas[]
      │            area = { startingPoints, headingKey, shipCounts }
      ├─ sags[]    { groupName, from = Placement, to = Anchorage, unitMap, ... }
      ├─ anchorage baseGUID, anchorageArea, lstAnchorageArea, arrivalThreshold
      ├─ air       airLandingZone（唯一一份）, contactThreshold, casArea,
      │            transportHelicopter, attackHelicopter
      └─ landing   boat, lst, acv, laneCenter, laneBearing, obstacleArea,
                   sweeper, offloadArea
```

### 共用型別（schema.lua）

- `SBJ__Placement`：`{ pos | startingPoints, headingKey }`。`fleet.from.areas[i]` 與 SAG `from` 共用。
- `SBJ__Composition`：生成用欄位（`shipCounts` / `unitMap`），與執行用欄位分開。
- `SBJ__Anchorage`：`{ area, headingKey }`。SAG `to` 與 Zone `anchorage` 共用。
- `headingKey` 指向 `formation.heading[key]`，取代 `heading.west.vertical` 在 `lstSettings`、`laneBearing`、`to.heading` 的三處手抄。

## 參數傳遞規則

- 只有 `landingOps/init.lua`（facade）拆 `config.red.amphibOps`。
- 內部模組簽名：`fn(zone, tuning.xxx, ...)`。
- 只有讀寫狀態時用 `zoneStates[zone.name]`。

## 步驟（每步一個 commit，每步後跑 `busted --lua=luajit spec` 與 `bash bin/build.sh -c -n -l -i`）

先開 branch，例如 `refactor/amphib-ops-zones`（目前在 `feat/landing-type529`，且 `config.lua`、`saveData.lua` 有未提交變更，需先處理）。

### Step 1：型別與 config 重排
- `src/core/schema.lua`：新增 `SBJ__Zone`、`SBJ__Placement`、`SBJ__Composition`、`SBJ__Anchorage`、`SBJ__AmphibTuning`；移除 `SBJ__AmphibiousOperationDescriptor`、`SBJ__OperationalZoneDescriptor`、`SBJ__SAGDescriptor`、`SBJ__AmphibOpsConfig` 舊欄位。
- `src/core/config.lua`：`formationSettings` 拆成 `formation` + `tuning`；`operations` / `operationalZones` / `sags` 併入 `zones[]`；`heading` 改為 `headingKey`；`airLandingZone` 與 SAG `area` 只留一份。
- 此步 landingOps 暫以轉接函式讀新結構，確保測試先綠。

### Step 2：landingOps 簽名改為收 `zone`
依序：`shipMovement` → `amphibiousAssault` → `secondWaveUnloading` → `mineClearing` / `assaultBoat` / `hovercraft` / `obstacleClearing` → `coordinator` → `init`。
- 刪除 `findOperationByName`、`getShipZone` 的名字比對迴圈。
- 對應 spec 同步更新（`spec/modules/landingOps/*_spec.lua`）。
- `spec/moduleBoundary_spec.lua` 必須維持通過。

### Step 3：外部使用者
- `src/modules/unitGenerator.lua`：`addLandingShips`、`createSAGs` 改走 `zones[]`（`sagDescriptorMap` 參數改為 zone 內 sags）。
- `src/modules/unitStatusUI.lua`：`:181-193`、`:297-304` 改走 `zones[]`。
- `spec/modules/unitStatusUI_spec.lua`、`spec/core/persistentState_spec.lua` 更新。

### Step 4：文件
- 更新 `docs/landingOps/*.md` 中舊欄位名稱。

## 驗證

- 每步：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i`（不得新增 warning）。
- 最後：`bash bin/build.sh -i` 確認打包成功。
- 手動：`config.lua` 中 6 個 operation（Taoyuan、Sishu、Penghu 各兩區）逐一對照舊值，數值不得改變。

## 風險

- `config.lua` 內大量 `config.red.amphibOps.formationSettings.xxx` 引用，改名時容易漏；用 grep 逐一確認。
- `unitStatusUI` 的 HTML 注入若依賴舊欄位，需先看 `htmls-app` 是否讀到（目前 grep 無結果，預期不受影響）。
- 若 CMO 內已有進行中的存檔，`zoneStates` key 不變，應可相容；仍需在 Step 2 後實機載入一次確認。

## 未決事項

- Placement 的位置寫法：Operation 用參考點名稱、SAG 用座標，本次不統一。
- `stagingFilter` 最終名稱。

## 實作結果（與計畫的差異）

已完成：`operations` / `operationalZones` / `sags` 併為 `zones[]`（`zone.fleet`、`zone.sags`、`zone.airLandingZone`、`zone.contactThreshold`）；`route` 等五個小表併為 `tuning`；landingOps 內部改收 `zone` / `zones` / `amphibOps`，不再收整個 `SBJ__Config`。

與計畫不同之處：

- Zone 既有欄位維持平的，未再分 `anchorage` / `air` / `landing` 三層（會動到全部 spec，收益低）。
- 未導入 `headingKey`：藍方 SAG 共用 `SBJ__SAGDescriptor`，heading 仍是數字；fleet area 的 `heading` 仍引用 `formationSettings.heading.*`。
- 未改名 `formationSettings` → `formation`，`from.stagingArea` 未搬出 `from`。
- `airLandingZone` 與 SAG 的 `area` **不是重複**：Sishu / Penghu 的 SAG `area` 分別是 `AIRLANDING_CHANGLONG` / `AIRLANDING_PENGHU`，但 zone 的 `airLandingZone` 三區都是 `AIRLANDING_TAOYUAN`。為保持行為不變，兩者都保留。Sishu / Penghu 的 `airLandingZone` 疑似複製貼上未改，待確認。
- 未做 `SBJ__Placement` / `SBJ__Composition` / `SBJ__Anchorage` 型別對齊。
