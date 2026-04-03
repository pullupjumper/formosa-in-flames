local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local DynamicATOInsertion = require("src.modules.strikePlanner.dynamicATOInsertion")
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")

local StrikePlanner = {}

---Initialize reconnaissance queue entries from configuration
---@param reconConfig SBJ__ReconConfig Reconnaissance configuration
---@param reconContext SBJ__ReconContext Reconnaissance runtime context
function StrikePlanner.initReconQueueEntries(reconConfig, reconContext)
  Recon.initReconQueueEntries(reconConfig, reconContext)
end

---Launch WZ-8 reconnaissance drone from H-6N bomber
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__Waypoint[] The reconnaissance course for WZ-8
---@return CMO__Unit|nil # Returns the WZ-8 unit if successfully launched
function StrikePlanner.launchWZ8(h6n, course)
  return Recon.launchWZ8(h6n, course)
end

---Handle reconnaissance queue processing and dynamic scheduling
---@param config SBJ__Config Global configuration table
---@param reconContext SBJ__ReconContext Reconnaissance runtime context
---@param reconSchedule SBJ__ReconScheduleEntry[] Dynamic operations schedule
---@param LACMContext SBJ__LACMContext LACM context data
function StrikePlanner.handleReconQueue(config, reconContext, reconSchedule, LACMContext)
  Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)
end

---Track target with active reconnaissance assets
---@param reconContext SBJ__ReconContext Reconnaissance runtime context
---@param units CMO__Unit[] Active reconnaissance units
---@param UAVDBID number UAV database ID
---@param target CMO__Contact|CMO__Unit Target to track
function StrikePlanner.trackTarget(reconContext, units, UAVDBID, target)
  Recon.trackTarget(reconContext, units, UAVDBID, target)
end

---Scan and categorize contacts into a target list
---@param sideName string Side name to get contacts from
---@param scanConfig SBJ__TargetScanningConfig Target scanning configuration
---@param saveData SBJ__SaveData Persistent save data
function StrikePlanner.scanTargets(sideName, scanConfig, saveData)
  TargetingProcess.scanTargets(sideName, scanConfig, saveData)
end

---Filter targets by base and subtype criteria
---@param targetlist SBJ__TargetEntry[] Target list entries
---@param queryParams SBJ__TargetQueryParam[] Filter query parameters
---@return string[] # Array of matching target GUIDs
function StrikePlanner.filterTargetsByTypeAndBase(targetlist, queryParams)
  return TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)
end

---Resolve executable targets for strike planning
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param targetConfig SBJ__TargetTemplate Target selection configuration
---@param isFirstWave boolean Whether the strike is the first wave
---@return string[] # Array of target GUIDs
function StrikePlanner.processTargets(config, saveData, contacts, targetConfig, isFirstWave)
  return TargetingProcess.processTargets(config, saveData, contacts, targetConfig, isFirstWave)
end

---Execute dynamic ground fire support planning
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
function StrikePlanner.executeDynamicFireSupportPlan(config, saveData, contacts)
  DynamicFireSupportPlan.execute(config, saveData, contacts)
end

---Execute dynamic air tasking order insertion
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
function StrikePlanner.processDynamicATO(config, saveData, contacts)
  DynamicATOInsertion.process(config, saveData, contacts)
end

---Execute ground fire support strikes for active matrices
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function StrikePlanner.strikeGroundTargets(saveData)
  FireSupportPlan.strike(saveData)
end

---Execute scheduled air strike packages
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
function StrikePlanner.executeAirStrike(config, saveData)
  AirTaskingOrder.airStrike(config, saveData)
end

return StrikePlanner
