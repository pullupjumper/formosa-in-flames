local OperationType = {}

---Per-type facts that let the scheduler and the insert pipeline stay generic over air and ground
---Air waves stagger by the configured interval, ground FSEMs are TOT-oriented.
---@type table<SBJ__OperationType, SBJ__OperationTypeProfile>
local PROFILES = {
  air = {
    templateSource = "packageTemplates",
    templateField = "packages",
    registryKey = "air",
    resolvePlan = function(plannerState) return plannerState.air.airTaskingOrder end,
    resolveDefaultInterval = function(config) return config.red.air.strikeInterval end,
  },
  ground = {
    templateSource = "fireSupportTaskTemplates",
    templateField = "fireSupportTasks",
    registryKey = "ground",
    resolvePlan = function(plannerState) return plannerState.ground.fireSupportPlan end,
    resolveDefaultInterval = function() return 0 end,
  }
}

---Resolve the descriptor for an operation type
---@param operationType string Operation type to look up ("air" or "ground")
---@return SBJ__OperationTypeProfile|nil # Profile, or nil for an unknown type
function OperationType.resolve(operationType)
  return PROFILES[operationType]
end

return OperationType
