GameUtils = require("src.utils.gameUtils")

Logger = {}

-- 切換是否在遊戲中（由你在 main 中設置）
Logger.inGame = type(ScenEdit_SpecialMessage) == "userdata"

-- 真正輸出的函式（自動判斷）
---comment
---@param message string
function Logger.log(message)
  if Logger.inGame then
    GameUtils.PrintBox('playerside', "[LOG] " .. message) -- 在遊戲中使用 ScenEdit_SpecialMessage
  else
    print("[LOG] " .. message)                            -- 開發階段用
  end
end

---comment
---@param message string
function Logger.error(message)
  if Logger.inGame then
    GameUtils.PrintBox('playerside', "[ERROR] " .. message) -- 在遊戲中使用 ScenEdit_SpecialMessage
  else
    print("[ERROR] " .. message)
  end
end

return Logger
