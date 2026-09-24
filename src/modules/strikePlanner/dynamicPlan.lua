local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local Recon = require("src.modules.strikePlanner.recon")
local OperationType = require("src.modules.strikePlanner.operationType")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local DynamicPlan = {}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Resolve the descriptor for an operation type, failing loudly on a type this pipeline cannot serve
---@param operationType string Operation type ("air" or "ground")
---@return SBJ__OperationTypeDescriptor # Descriptor for the type
local function resolveDescriptor(operationType)
  local descriptor = OperationType.resolve(operationType)
  if not descriptor then
    error("DynamicPlan: unknown operation type " .. tostring(operationType))
  end
  return descriptor
end

---Ensure generatedOperations table exists in saveData
---@param saveData SBJ__SaveData Game save data
local function ensureGeneratedOperations(saveData)
  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end
end

---Abbreviate a reconnaissance source for use in a dynamic instance tag
---Falls back to the uppercased reconType when the source is not mapped.
---@param reconType string Reconnaissance source (e.g., "satellite", "UAV", "SIGINT")
---@return string # Short uppercase source code (e.g., "SAT", "UAV", "SIGINT")
local function formatReconSource(reconType)
  return constants.RECON_SOURCE_ABBREVIATIONS[reconType] or string.upper(reconType)
end

---Generate a unique operation name by appending a dynamic instance tag to the template name.
---The template name (wave-stage number included) is kept verbatim as the prefix so downstream
---wave-number parsing stays intact; the appended "/DYN-<source>-NN" segment uses "-" separators
---to stay visually distinct from the "/" taxonomy path.
---Example: template "AIR/STRIKE/AB/W/2" + "satellite" -> "AIR/STRIKE/AB/W/2/DYN-SAT-01"
---@param templateName string Full operation template name, wave-stage number included (e.g. "AIR/STRIKE/AB/W/2")
---@param reconType string Reconnaissance source that triggered the operation (e.g., "satellite", "UAV", "SIGINT")
---@param registrySet table<string, boolean> Generated operation names already handed out for this type
---@param existingPlan table<string, any>|nil Plan table to check for conflicts with static entries
---@return string # Generated unique operation name
local function buildUniqueOperationName(templateName, reconType, registrySet, existingPlan)
  local instancePrefix = templateName .. "/DYN-" .. formatReconSource(reconType) .. "-"
  local sequence = 1

  local operationName
  repeat
    operationName = instancePrefix .. string.format("%02d", sequence)
    sequence = sequence + 1
  until not registrySet[operationName] and not (existingPlan and existingPlan[operationName])

  return operationName
end

-- ============================================================================
-- Public API
-- ============================================================================

---Evaluate targets for every package or task in an operation template
---An entry qualifies when it finds at least its minTargetCount targets.
---Recon tracking is requested for every entry that raised it, qualified or not.
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param operationType SBJ__OperationType Operation type the template belongs to
---@param template SBJ__WaveTemplate|SBJ__FireSupportExecutionMatrixTemplate Template whose entries are evaluated
---@return table<integer, string[]> targetsByIndex Evaluated targets keyed by entry index, qualified entries only
---@return integer qualifiedCount Number of entries with enough targets
function DynamicPlan.evaluateTargets(config, saveData, contacts, operationType, template)
  local descriptor = resolveDescriptor(operationType)
  local targetsByIndex = {}
  local qualifiedCount = 0
  local trackingRequests = {}

  for index, entryTemplate in ipairs(template[descriptor.templateField]) do
    ---@cast entryTemplate SBJ__FireSupportTaskTemplate|SBJ__PackageTemplate
    local targets, requests = TargetingProcess.processTargets(
      config,
      saveData,
      contacts,
      entryTemplate.target,
      template.isFirstWave
    )
    if requests then
      Utils.addAll(trackingRequests, requests)
    end

    if #targets >= entryTemplate.target.minTargetCount then
      targetsByIndex[index] = targets
      qualifiedCount = qualifiedCount + 1
    end
  end

  if #trackingRequests > 0 then
    Recon.trackTargets(saveData.c.recon, trackingRequests)
  end

  return targetsByIndex, qualifiedCount
end

---Name, insert and register a generated plan in one step
---buildPlan receives the unique name and returns the wave or matrix to store under it.
---The name is registered in the same call, so a generated name can never go unregistered.
---@param saveData SBJ__SaveData Persistent save data holding the plan table and the name registry
---@param operationType SBJ__OperationType Operation type deciding which plan table and registry are used
---@param templateName string Full operation template name, wave-stage number included
---@param reconType string Reconnaissance source that triggered the operation
---@param buildPlan fun(planName: string): table Builds the plan entry for the generated name
---@return string # The generated plan name
function DynamicPlan.insert(saveData, operationType, templateName, reconType, buildPlan)
  local descriptor = resolveDescriptor(operationType)
  ensureGeneratedOperations(saveData)

  local registrySet = saveData.c.dynamicOperations.generatedOperations[descriptor.registryKey]
  local plan = descriptor.resolvePlan(saveData)
  local planName = buildUniqueOperationName(templateName, reconType, registrySet, plan)

  plan[planName] = buildPlan(planName)
  registrySet[planName] = true

  return planName
end

return DynamicPlan
