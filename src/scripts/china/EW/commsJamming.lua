local gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

local function getCommsLevel(saveData, affectedUnitGUID)
  local comm_bonif = CONFIG.c.commsJamming.initialComms

  for _, jammer in ipairs(saveData.c.commsJamming.jammers) do
    local actualJammer = SE_GetUnit({ guid = jammer.guid })

    if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
      comm_bonif = -120 + Tool_Range(affectedUnitGUID, actualJammer.guid) ^ 1.04 + comm_bonif
    end
  end

  for _, AEW in ipairs(saveData.t.air.landBased.AEW) do
    local actualAEW = SE_GetUnit({ guid = AEW.guid })

    if actualAEW and actualAEW.condition == 'Airborne' then
      local d = Tool_Range(affectedUnitGUID, actualAEW.guid)
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
    local ROCC = SE_GetUnit({ guid = ROCCGuid })

    if ROCC then
      local d = Tool_Range(affectedUnitGUID, ROCC.guid)
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
      SE_SetUnit({ guid = affectedUnit.guid, outofcomms = true })
      affectedUnit.outofcomms = affectedUnit.outofcomms + 1
    else
      SE_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
      affectedUnit.outofcomms = 0
      affectedUnit.isOutOfComms = false
    end
  elseif affectedUnit.isOutOfComms == false then
    local actualAffectedUnit = SE_GetUnit({ guid = affectedUnit.guid })

    if actualAffectedUnit and actualAffectedUnit.outOfComms then
      SE_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
      affectedUnit.outofcomms = 0
    end
  end

  if jammer and jammer.condition == 'Airborne' and jammer.jammer then
    if affectedUnit.isOutOfComms == false then
      if affectedUnit.outofcomms < math.random(5, 10) and affectedUnit.outofcomms >= 0 and jammedNum < CONFIG.c.commsJamming.limit then
        local d = Tool_Range(jammer.guid, affectedUnit.guid)
        local n = 1 * math.sqrt(1 - (d ^ 1.9 / CONFIG.c.commsJamming.range ^ 1.8))

        if n == n and n > (math.random() / 2) then
          SE_SetUnit({ guid = affectedUnit.guid, outofcomms = true })
          affectedUnit.outofcomms = affectedUnit.outofcomms + 1
          affectedUnit.isOutOfComms = true
          jammedNum = jammedNum + 1
        else
          SE_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
          affectedUnit.outofcomms = 0
          affectedUnit.isOutOfComms = false
          jammedNum = jammedNum + 1
        end
      elseif affectedUnit.outofcomms < 0 then
        SE_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = affectedUnit.outofcomms + 1
      else
        SE_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = math.random(-5, -1)
      end
    end
  end

  return jammedNum
end

if saveData.c.commsJamming.isActivated then
  -- local jammerTemp = nil
  -- local jammedNum = 0

  -- for _, jammer in ipairs(saveData.c.commsJamming.jammers) do
  --   local actualJammer = SE_GetUnit({ guid = jammer.guid })

  --   if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
  --     jammerTemp = actualJammer
  --     break
  --   end
  -- end

  -- local unitTemp = {}

  -- for key, item in pairs(saveData.t.IADS.ROCC) do
  --   for _, value in pairs(item.SAM) do
  --     unitTemp[value.guid] = value
  --   end
  --   for _, value in pairs(item.radar) do
  --     unitTemp[value.guid] = value
  --   end
  -- end

  -- for key, item in pairs(saveData.t.IADS.TAAOC) do
  --   for _, value in pairs(item.SAM) do
  --     unitTemp[value.guid] = value
  --   end
  -- end

  -- if jammerTemp then
  --   table.sort(unitTemp, function(a, b)
  --     local da = Tool_Range(jammerTemp.guid, a.guid)
  --     local db = Tool_Range(jammerTemp.guid, b.guid)
  --     return da < db
  --   end)
  -- end

  -- for _, affectedUnit in pairs(unitTemp) do
  --   jammedNum = commsJamming(affectedUnit, jammerTemp, jammedNum)
  -- end

  for _, AC in ipairs(saveData.t.air.landBased.AC) do
    local actualAC = SE_GetUnit({ guid = AC.guid })

    if actualAC and actualAC.condition == 'Airborne' then
      AC.commsLevel = AC.commsBase + getCommsLevel(saveData, actualAC.guid)

      if AC.commsLevel < AC.commsThreshold then
        ScenEdit_SetUnit({ guid = AC.guid, outofcomms = true, RTB = true })
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
