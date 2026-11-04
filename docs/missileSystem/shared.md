# shared.lua

missileSystem 共用工具函式模組。

> Source: `src/modules/missileSystem/shared.lua`

責任摘要：weaponDBID 一致化與 group 展開。只放兩個以上檔案都會用到的小工具。

---

## 概觀

`shared.lua` 是底層輔助層，避免在 `movement/ammo/concealment/deployment/cargoProxy` 重複處理 weaponDBID 與 group GUID。

單位屬性設定（`ScenEdit_SetUnit`、WCS doctrine 欄位）只有 [movement](movement.md) 用，所以放在 `movement.lua`。

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `normalizeWeaponDBIDs` | `weaponDBID` | `number[]` | weaponDBID 單值/陣列一致化 |
| `getGroupUnits` | `unit` | `string[]` | 取得group內所有 GUID |

---

## 相關模組

- [movement](movement.md)
- [ammo](ammo.md)
- [concealment](concealment.md)
- [deployment](deployment.md)
