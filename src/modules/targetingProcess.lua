function SelectTargetsByQueryParams(opts)
  local targetlist = opts.targetlist
  local queryParams = opts.queryParams
  local selectedTargetlist = {}

  for _, item in ipairs(targetlist) do
    for _, param in ipairs(queryParams) do
      local isNameMatched = false
      local isSubTypeMatched = false

      if not param.baseName then
        isNameMatched = true
      end

      if param.baseName then
        if string.find(item.name, param.baseName) ~= nil then
          isNameMatched = true
        end
      end

      for _, subType in ipairs(param.subTypes) do
        if string.find(item.subType, subType) ~= nil then
          isSubTypeMatched = true
          break
        end
      end

      if isNameMatched and isSubTypeMatched then
        table.insert(selectedTargetlist, item.guid)
      end
    end
  end

  return selectedTargetlist
end
