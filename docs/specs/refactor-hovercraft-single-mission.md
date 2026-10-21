# refactor/hovercraft-single-mission

## 目標

每區只有一個氣墊船貨運任務，`SBJ__HovercraftMissionDescriptor` 的 `missions`（陣列）改成 `missionName`（`string`）。不再依 `unitCount` 把氣墊船分配到多個任務。

## 要做到的行為

- `SBJ__CargoLandingPlatformDescriptor` 拿掉 `missions`，`missions` 移到 `SBJ__TransportHelicopterDescriptor`（`SBJ__HovercraftMissionDescriptor` 不再有 `missions`）。
- `SBJ__HovercraftMissionDescriptor` 新增 `missionName: string`。
- `config.red.amphibOps.zones[].landing.hovercraft`：三區的 `missions = { ... }` 換成 `missionName = "LANDING/<區>/1/1"`（沿用原第一個任務名），移除被註解掉的第二個任務。
- `hovercraft.lua`：移除 `findMissionName`，登記氣墊船時直接用 `zone.landing.hovercraft.missionName`。
- `amphibiousLogistics.createZoneCargoMissions`：氣墊船建立 `missionName` 一個任務；運輸直升機維持逐一建立 `missions`。建立順序不變（氣墊船先、運輸直升機後），遇到第一個失敗就停。
- `config.red.amphibOps.missionStartTime.boat` 只給氣墊船任務用，一併移除。

## 不做

- 不改氣墊船放出時機、通道、到達判定。
- 不改運輸直升機、攻擊直升機、運輸機的設定。

## 驗收

- `busted --lua=luajit spec` 全過；`hovercraft_spec`、`amphibiousLogistics_spec` 改用 `missionName`，並移除「依 unitCount 換任務」的案例。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `docs/landingOps/hovercraft.md`、`docs/landingOps/amphibiousLogistics.md`（如有提到）同步更新。
- 全專案搜不到 `hovercraft.missions` 與 `findMissionName`。
