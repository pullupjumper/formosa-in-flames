local OperationType = {}

---Per-type facts that let the scheduler and the insert pipeline stay generic over air and ground
---Air waves stagger by the configured interval, ground FSEMs are TOT-oriented.
---@type table<SBJ__OperationType, SBJ__OperationTypeDescriptor>
local DESCRIPTORS = {
  air = {
    templateSource = "packageTemplates",
    templateField = "packages",
    registryKey = "air",
    resolvePlan = function(plannerState) return plannerState.air.airTaskingOrder end,
    resolveDefaultInterval = function(config) return config.c.air.strikeInterval end,
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
---@return SBJ__OperationTypeDescriptor|nil # Descriptor, or nil for an unknown type
function OperationType.resolve(operationType)
  return DESCRIPTORS[operationType]
end

return OperationType
