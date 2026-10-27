# refactor/amphib-ships-config

> 補寫，行為已實作。

## 目標

艦艇定義與貨物放進 config，每艘船直接帶自己的貨物清單；同時依編制表重新配貨。

## 要做到的行為

- 艦艇定義搬進 `config.red.amphibOps.ships`；每艘船的 `cargo` 直接是貨物清單，不再用 `cargoKey` 與 `cargoMap` 查表。
- 貨量依編制表重配（貨是兵力池，不是 Z-18 一輪的運量）：
  - 075 / 076 / 071 合計約 5 個兩棲合成旅。
  - 075 的 MC 41、HMMWV 50，合計約 12 個空中突擊營。
  - RORO 的貨約 1.5 個重型合成旅（見 [hovercraftCapacity](../landingOps/hovercraftCapacity.md)）；桃園、喜樹各加第 3 艘 RORO，每區超過 1 個旅。
- `unitGenerator` 依 `ship.cargo` 載貨。

## 不做

- 不改氣墊船、直升機的運送邏輯。
- 不改艦艇數量以外的編隊。

## 驗收

- `spec/core/amphibCargo_spec.lua` 釘住：PLZ-96 合計 135、RORO 的 ZBD-04 合計 252、RORO 在三區是 3 / 3 / 0。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `docs/landingOps/hovercraftCapacity.md` 對齊上述數字。
