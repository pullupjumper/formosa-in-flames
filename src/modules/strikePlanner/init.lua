local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local AttackManager = require("src.modules.attackManager")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

local StrikePlanner = {}

local LACM_SALVO_QTY = 5
local SLCM_SALVO_QTY = 8
local LACM_GROUP_NAME = "CSG"
local WZ8_RECON_CHANCE = 0.5

---Initialize the strike planner state at scenario start
---Builds the persistent target list first, then the recon queue when recon is enabled.
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
function StrikePlanner.init(config, plannerState)
  TargetingProcess.findTargets(constants.SIDES.ENEMY, config.targetScanning, plannerState.targetlist)

  if plannerState.recon.enabled then
    Recon.initQueue(config.c.recon, plannerState.recon)
  end
end

---Insert dynamic FSEM and ATO operations built from current contacts
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts from the game
local function processDynamicOperations(config, plannerState, contacts)
  if not plannerState.dynamicOperations.enabled then return end

  FsemBuilder.build(config, plannerState, contacts)
  AtoBuilder.build(config, plannerState, contacts)
end

---Advance the recon queue and occasionally schedule an extra WZ-8 island sortie
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
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
    Recon.addEntry(plannerState.recon, config.c.recon.template.WZ8_RECON_ISLAND)
  end
end

---Fire the one-shot LACM salvo from the CSG Type 055s once its start time passes
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
local function launchLACMSalvo(config, plannerState)
  local lacmCtx = plannerState.lacm

  -- lacm.enabled is sticky once the CSG reaches station, so hasLaunched is what
  -- keeps the salvo one-shot. Strike scheduling reads enabled to tell whether the
  -- LACM element is committed at all.
  if not lacmCtx.enabled
      or lacmCtx.hasLaunched
      or not GameUtils.isAfterStartTime(config.c.triggers.launchLACM.startTime) then
    return
  end

  local ships = {}

  for _, guid in ipairs(GameApi.ScenEdit_GetUnit(LACM_GROUP_NAME).group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit and unit.dbid == constants.PLATFORMS.TYPE_055 then
      table.insert(ships, { guid = guid, weaponDBID = config.c.surface.lacm.weaponDBID })
    end
  end

  AttackManager.attackContacts({
    contacts = config.c.surface.lacm.targetlist,
    qty = LACM_SALVO_QTY,
    firingUnits = ships,
    weaponDBID = config.c.surface.lacm.weaponDBID
  })
  lacmCtx.hasLaunched = true
end

---Surface the SLCM submarines to launch depth and fire the one-shot salvo
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
local function launchSLCMSalvo(config, plannerState)
  local slcmCtx = plannerState.slcm

  if not slcmCtx.enabled or not GameUtils.isAfterStartTime(config.c.triggers.launchSLCM.startTime) then
    return
  end

  for _, submarine in pairs(config.c.subSurface.slcm.submarines) do
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
    contacts = config.c.subSurface.slcm.targetlist,
    qty = SLCM_SALVO_QTY,
    firingUnits = config.c.subSurface.slcm.submarines,
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  })

  slcmCtx.enabled = false
end

---Advance active FSPs and ATO waves, including any inserted earlier this tick
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
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
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts from the game
function StrikePlanner.process(config, plannerState, contacts)
  processDynamicOperations(config, plannerState, contacts)
  processRecon(config, plannerState)
  launchLACMSalvo(config, plannerState)
  launchSLCMSalvo(config, plannerState)
  processActivePlans(config, plannerState)
end

return StrikePlanner
