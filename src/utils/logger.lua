local Logger = {}

-- 切換是否在遊戲中（由你在 main 中設置）
Logger.inGame = type(ScenEdit_SpecialMessage) == "userdata"



---@param side string @The side the message is visible to (sidename may also be used in place of side)
---@param ... string @Variable number of string arguments to be printed inside the box
local function printBox(side, ...)
  -- 收集所有字串參數到陣列中
  local strings = { ... }

  -- 找出最長字串的長度
  local maxLen = 0
  for _, str in ipairs(strings) do
    if #str > maxLen then
      maxLen = #str
    end
  end

  -- 計算邊框寬度
  local width = 70

  -- 構建頂部和底部邊框：連續的 -
  local border = string.rep("-", width)

  -- 構建中間行
  local middleLines = {}
  for _, str in ipairs(strings) do
    -- 構建中間行：| 空格 字串
    local middle = "| " .. str
    table.insert(middleLines, middle)
  end

  -- 組合成一個單一的字串
  local boxString = border .. "\n" .. table.concat(middleLines, "\n") .. "\n" .. border

  -- 一次性輸出
  ScenEdit_SpecialMessage(side, boxString)
end

-- 真正輸出的函式（自動判斷）
---comment
---@param message string
function Logger.log(message)
  if Logger.inGame then
    printBox('playerside', "[LOG] " .. message)
  else
    print("[LOG] " .. message) -- 開發階段用
  end
end

---comment
---@param message string
function Logger.error(message)
  if Logger.inGame then
    printBox('playerside', "[ERROR] " .. message)
  else
    print("[ERROR] " .. message)
  end
end

return Logger
