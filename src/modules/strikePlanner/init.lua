local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")

local StrikePlanner = {}

---Initialize reconnaissance queue from configuration
---@param reconConfig SBJ__ReconConfig Reconnaissance configuration
---@param reconContext SBJ__ReconContext Reconnaissance runtime context
function StrikePlanner.initReconQueue(reconConfig, reconContext)
  Recon.initQueue(reconConfig, reconContext)
end

---Schedule a UAV entry in the reconnaissance queue
---@param reconContext SBJ__ReconContext Reconnaissance runtime context
---@param entryTemplate SBJ__ReconUAVTemplate The template for the entry to insert
---@param startTime string|nil The start time of the entry to insert
---@return SBJ__ReconUAVEntry|nil # The inserted entry, or nil if no entry was inserted
function StrikePlanner.scheduleReconUAVEntry(reconContext, entryTemplate, startTime)
  return Recon.insertEntry(reconContext, entryTemplate, startTime)
end

---Launch WZ-8 reconnaissance drone from H-6N bomber
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__Waypoint[] The reconnaissance course for WZ-8
---@return CMO__Unit|nil # Returns the WZ-8 unit if successfully launched
function StrikePlanner.launchWZ8FromH6N(h6n, course)
  return Recon.launchWZ8(h6n, course)
end

---Process reconnaissance queue and dynamic scheduling
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
function StrikePlanner.processReconQueue(processingContext)
  Recon.processQueue(processingContext)
end

---Populate the persistent target list from categorized contacts
---@param sideName string Side name to get contacts from
---@param scanConfig SBJ__TargetScanningConfig Target scanning configuration
---@param saveData SBJ__SaveData Persistent save data
function StrikePlanner.populateTargetList(sideName, scanConfig, saveData)
  TargetingProcess.scanTargets(sideName, scanConfig, saveData)
end

---Select target GUIDs by base and subtype criteria
---@param targetlist SBJ__TargetEntry[] Target list entries
---@param queryParams SBJ__TargetQueryParam[] Filter query parameters
---@return string[] # Array of matching target GUIDs
function StrikePlanner.selectTargetGUIDsByBaseAndSubtype(targetlist, queryParams)
  return TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)
end

---Process dynamic ground operations and generate fire support matrices
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
function StrikePlanner.processDynamicGroundOperations(config, saveData, contacts)
  FsemBuilder.execute(config, saveData, contacts)
end

---Process dynamic air operations and generate air tasking order waves
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
function StrikePlanner.processDynamicAirOperations(config, saveData, contacts)
  AtoBuilder.process(config, saveData, contacts)
end

---Process active fire support plans, including deployment and strikes
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function StrikePlanner.processActiveFireSupportPlans(saveData)
  FireSupportPlan.strike(saveData)
end

---Process active air tasking order waves and strike packages
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
function StrikePlanner.processActiveATOWaves(config, saveData)
  AirTaskingOrder.airStrike(config, saveData)
end

return StrikePlanner
