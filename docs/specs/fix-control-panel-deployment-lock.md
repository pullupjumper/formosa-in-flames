# fix/control-panel-deployment-lock

## 目標

控制面板的部署鎖（`saveData.<side>.isDeploymentLocked`）在 edit mode 完全沒作用：Lua 傳給畫面的鎖、送出時的檢查、前端的 `resolveControlPanelView` 三個地方都在 edit mode 略過它。鎖住時面板又用 `inert` 整塊停用，連單位狀態都看不到。

這次讓 edit mode 也照鎖走，並把「鎖住」改成唯讀：看得到，改不了。EMCON 不受鎖影響。

## 要做到的行為

- 新增 `config.red.triggers.scenBegin.startTime`，代表開戰時間。
- 什麼時候上鎖：
  - play mode：第一次送出部署就上鎖（不變）。
  - edit mode：開戰前送出不上鎖，可以一直重來；開戰後送出就上鎖。
- 已上鎖時，不論哪種 mode：
  - Lua 不套用送出的部署（Jammer、飛彈發射車、飛機），也不套用 C2 指派。
  - SAM doctrine（EMCON）照常套用。
- 畫面在鎖住時：
  - Jammer、Missile Batteries、Aircraft Deployment 面板標題顯示 `LOCKED`，不再整塊變灰停用。
  - Jammer 與飛彈卡片可以點開，看 Zone、Range、Status。
  - 部署、取消部署、移動、旋轉都沒有反應。
  - 飛機與彈藥只顯示數量，`+`/`-` 按鈕隱藏。
  - C2 Nodes 面板（含 SAM weapons-free 切換）與 Submit 按鈕照常可用。
- `resolveControlPanelView` 的 `isDeploymentLocked` 直接等於注入的鎖，不再看 `isEditMode`。

## 不做

- 不改 play mode 上鎖的時機。
- 不提供解鎖；edit mode 開戰後上了鎖，要重新開局才能再部署。
- 不改 Landing Units 與 Add Units 只在 edit mode 顯示的規則。
- 不改部署送出的資料格式（`summaryData`、`emconData`）。

## 驗收

- edit mode、開戰前：送出兩次部署，兩次都生效，不上鎖。
- edit mode、開戰後：送出一次後上鎖；重開面板，三個部署面板顯示 `LOCKED`。
- 鎖住時：飛彈卡片點開看得到 Status；點地圖、取消部署沒有效果；飛機沒有 `+`/`-`。
- 鎖住時：切換 SAM weapons-free 後送出，遊戲內 SAM 的 WCS 跟著變。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。
