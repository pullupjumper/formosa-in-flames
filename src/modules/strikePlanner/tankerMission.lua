local TankerMission = {}

---Normalize tanker mission creation parameters to an array
---@param missionCreationParams SBJ__TankerMissionCreationParams|nil
---@return SBJ__MissionCreationParams[] missionParamsEntries Normalized mission parameter array
---@return boolean isSingle Whether the input represented one mission object
function TankerMission.normalizeCreationParams(missionCreationParams)
  if not missionCreationParams then
    return {}, false
  end

  local isSingle = missionCreationParams.name ~= nil or missionCreationParams.type ~= nil or
      missionCreationParams.opts ~= nil or missionCreationParams.side ~= nil

  if isSingle then
    return { missionCreationParams }, true
  end

  return missionCreationParams, false
end

return TankerMission
