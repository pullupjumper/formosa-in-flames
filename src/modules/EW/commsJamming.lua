local GameApi = require("src.utils.gameApi")

local CommsJamming = {}


---comment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param affectedUnitGUID string
---@return integer
local function getCommsLevel(config, saveData, affectedUnitGUID)
  local comm_bonif = config.c.commsJamming.initialComms

  for _, jammer in ipairs(saveData.c.commsJamming.jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammer.guid)

    if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
      comm_bonif = -120 + GameApi.Tool_Range(affectedUnitGUID, actualJammer.guid) ^ 1.04 + comm_bonif
    end
  end

  for _, AEW in pairs(saveData.t.air.landBased.AEW) do
    local actualAEW = GameApi.ScenEdit_GetUnit(AEW.guid)

    if actualAEW and actualAEW.condition == 'Airborne' then
      local d = GameApi.Tool_Range(affectedUnitGUID, actualAEW.guid)
      if d < 100 then
        comm_bonif = comm_bonif + 400 + math.random(-1, 1)
      elseif d < 200 then
        comm_bonif = comm_bonif + 350 + math.random(-3, 3)
      elseif d < 300 then
        comm_bonif = comm_bonif + 250 + math.random(-6, 6)
      elseif d < 400 then
        comm_bonif = comm_bonif + 150 + math.random(-10, 10)
      end
    end
  end

  for ROCCGuid, value in pairs(saveData.t.IADS.ROCC) do
    local ROCC = GameApi.ScenEdit_GetUnit(ROCCGuid)

    if ROCC then
      local d = GameApi.Tool_Range(affectedUnitGUID, ROCC.guid)
      if d < 100 then
        comm_bonif = comm_bonif + 400 + math.random(-1, 1)
      elseif d < 200 then
        comm_bonif = comm_bonif + 350 + math.random(-3, 3)
      elseif d < 300 then
        comm_bonif = comm_bonif + 250 + math.random(-6, 6)
      elseif d < 400 then
        comm_bonif = comm_bonif + 150 + math.random(-10, 10)
      end
      break
    end
  end

  return math.floor(comm_bonif)
end

local function commsJamming(affectedUnit, jammer, jammedNum)
  if affectedUnit.isOutOfComms then
    if affectedUnit.outofcomms <= math.random(15, 25) then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = true })
      affectedUnit.outofcomms = affectedUnit.outofcomms + 1
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
      affectedUnit.outofcomms = 0
      affectedUnit.isOutOfComms = false
    end
  elseif affectedUnit.isOutOfComms == false then
    local actualAffectedUnit = GameApi.ScenEdit_GetUnit(affectedUnit.guid)

    if actualAffectedUnit and actualAffectedUnit.outOfComms then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
      affectedUnit.outofcomms = 0
    end
  end

  if jammer and jammer.condition == 'Airborne' and jammer.jammer then
    if affectedUnit.isOutOfComms == false then
      if affectedUnit.outofcomms < math.random(5, 10) and affectedUnit.outofcomms >= 0 and jammedNum < config.c.commsJamming.limit then
        local d = GameApi.Tool_Range(jammer.guid, affectedUnit.guid)
        local n = 1 * math.sqrt(1 - (d ^ 1.9 / config.c.commsJamming.range ^ 1.8))

        if n == n and n > (math.random() / 2) then
          GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = true })
          affectedUnit.outofcomms = affectedUnit.outofcomms + 1
          affectedUnit.isOutOfComms = true
          jammedNum = jammedNum + 1
        else
          GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
          affectedUnit.outofcomms = 0
          affectedUnit.isOutOfComms = false
          jammedNum = jammedNum + 1
        end
      elseif affectedUnit.outofcomms < 0 then
        GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = affectedUnit.outofcomms + 1
      else
        GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = math.random(-5, -1)
      end
    end
  end

  return jammedNum
end

---comment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
function CommsJamming.handleCommsJamming(config, saveData)
  for _, AC in pairs(saveData.t.air.landBased.AC) do
    local actualAC = GameApi.ScenEdit_GetUnit(AC.guid)

    if actualAC and actualAC.condition == 'Airborne' then
      AC.commsLevel = AC.commsBase + getCommsLevel(config, saveData, actualAC.guid)

      if AC.commsLevel < AC.commsThreshold then
        GameApi.ScenEdit_SetUnit({ guid = AC.guid, outofcomms = true, RTB = true })
      end
    end
  end
end

return CommsJamming
