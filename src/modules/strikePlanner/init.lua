local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local AttackManager = require("src.modules.attackManager")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local PersistentState = require("src.core.persistentState")
local constants = require("src.core.constants")

local StrikePlanner = {}

local LACM_SALVO_QTY = 5
local SLCM_SALVO_QTY = 8
local LACM_GROUP_NAME = "CSG"
local WZ8_RECON_CHANCE = 0.5

---Initialize the strike planner state at scenario start
---Builds the persistent target list first, then the recon queue when recon is enabled.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function StrikePlanner.init(config, saveData)
  local plannerState = PersistentState.strikePlanner(saveData)

  TargetingProcess.findTargets(constants.SIDES.RED, config.red.targetScanning, plannerState.targetlist)

  if plannerState.recon.enabled then
    Recon.initQueue(config.red.recon, plannerState.recon)
  end
end

---Insert dynamic FSEM and ATO operations built from current contacts
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
---@param contacts CMO__Contact[]
local function processDynamicOperations(config, plannerState, contacts)
  if not plannerState.dynamicOperations.enabled then return end

  FsemBuilder.build(config, plannerState, contacts)
  AtoBuilder.build(config, plannerState, contacts)
end

---Advance the recon queue and occasionally schedule an extra WZ-8 island sortie
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
local function processRecon(config, plannerState)
  if not plannerState.recon.enabled then return end

  Recon.processQueue({
    config = config,
    reconCtx = plannerState.recon,
    reconTriggeredOperationBatches = plannerState.dynamicOperations.reconTriggeredOperationBatches,
    lacmCtx = plannerState.lacm,
    fireSupportOnHold = plannerState.fireSupportOnHold
  })

  if math.random() > WZ8_RECON_CHANCE then
    Recon.addEntry(plannerState.recon, config.red.recon.templates.WZ8_RECON_ISLAND)
  end
end

---Fire the one-shot LACM salvo from the CSG Type 055s once its start time passes
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
local function launchLACMSalvo(config, plannerState)
  local lacmCtx = plannerState.lacm

  -- lacm.enabled is sticky once the CSG reaches station, so hasLaunched is what
  -- keeps the salvo one-shot. Strike scheduling reads enabled to tell whether the
  -- LACM element is committed at all.
  if not lacmCtx.enabled
      or lacmCtx.hasLaunched
      or not GameUtils.isAfterStartTime(config.red.triggers.launchLACM.startTime) then
    return
  end

  local ships = {}

  for _, guid in ipairs(GameApi.ScenEdit_GetUnit(LACM_GROUP_NAME).group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit and unit.dbid == constants.PLATFORMS.TYPE_055 then
      table.insert(ships, { guid = guid, weaponDBID = config.red.surface.lacm.weaponDBID })
    end
  end

  AttackManager.attackContacts({
    contacts = config.red.surface.lacm.targetlist,
    qty = LACM_SALVO_QTY,
    firingUnits = ships,
    weaponDBID = config.red.surface.lacm.weaponDBID
  })
  lacmCtx.hasLaunched = true
end

---Surface the SLCM submarines to launch depth and fire the one-shot salvo
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
local function launchSLCMSalvo(config, plannerState)
  local slcmCtx = plannerState.slcm

  if not slcmCtx.enabled or not GameUtils.isAfterStartTime(config.red.triggers.launchSLCM.startTime) then
    return
  end

  for _, submarine in pairs(config.red.subSurface.slcm.submarines) do
    local actualUnit = GameApi.ScenEdit_GetUnit(submarine.name)

    if actualUnit then
      local course = { { latitude = actualUnit.latitude, longitude = actualUnit.longitude, presetDepth = 2 } }
      for _, waypoint in ipairs(actualUnit.course) do
        table.insert(course, { latitude = waypoint.latitude, longitude = waypoint.longitude, presetDepth = 2 })
      end

      actualUnit.course = course
    end
  end

  AttackManager.attackContacts({
    contacts = config.red.subSurface.slcm.targetlist,
    qty = SLCM_SALVO_QTY,
    firingUnits = config.red.subSurface.slcm.submarines,
    weaponDBID = config.red.subSurface.slcm.weaponDBID
  })

  slcmCtx.enabled = false
end

---Advance active FSPs and ATO waves, including any inserted earlier this tick
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
local function processActivePlans(config, plannerState)
  if plannerState.ground.enabled then
    FireSupportPlan.process(plannerState)
  end

  if plannerState.air.enabled then
    AirTaskingOrder.process(config, plannerState)
  end
end

---Run one strike planner tick
---Order matters: dynamic plans are inserted before recon settles its queue, and
---execution runs last so plans inserted this tick can start in the same tick.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function StrikePlanner.process(config, saveData)
  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    Logger.error("contacts is nil")
    return
  end

  local plannerState = PersistentState.strikePlanner(saveData)
  processDynamicOperations(config, plannerState, contacts)
  processRecon(config, plannerState)
  launchLACMSalvo(config, plannerState)
  launchSLCMSalvo(config, plannerState)
  processActivePlans(config, plannerState)
end

---Release a WZ-8 from an H-6N flying a recon entry and hand the entry over to it
---@param reconCtx SBJ__ReconContext
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@return CMO__Unit|nil # The launched WZ-8, or nil when no entry is flying this H-6N or the launch failed
function StrikePlanner.launchWZ8(reconCtx, h6n)
  return Recon.launchWZ8(reconCtx, h6n)
end

---Insert a UAV reconnaissance entry from a template if no equivalent entry covers the window
---@param reconCtx SBJ__ReconContext
---@param entryTemplate SBJ__ReconUAVTemplate
---@param startTime string|nil Timestamp or datetime string for the start time of the entry
---@return SBJ__ReconUAVEntry|nil # The inserted entry, or nil if no entry was inserted
function StrikePlanner.addReconEntry(reconCtx, entryTemplate, startTime)
  return Recon.addEntry(reconCtx, entryTemplate, startTime)
end

---Filter targets by type and base name
---@param targetlist SBJ__TargetEntry[]
---@param queryParams SBJ__TargetQueryEntry[]
---@return string[] # Array of target GUIDs matching query criteria
function StrikePlanner.filterTargetsByTypeAndBase(targetlist, queryParams)
  return TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)
end

return StrikePlanner
