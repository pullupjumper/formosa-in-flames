---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- LandingOps DirectFirePrep Unit Tests
local DirectFirePrep = require("src.modules.landingOps.directFirePrep")
local GameApi = require("src.utils.gameApi")
local AttackManager = require("src.modules.attackManager")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("DirectFirePrep", function()
  local trackStub = StubTracker.track

  after_each(function()
    StubTracker.revertAll()
  end)

  ---Create a SAG ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildShip(overrides)
    local ship = {
      guid = "SHIP-001",
      side = constants.SIDES.RED,
      dbid = constants.PLATFORMS.TYPE_052D,
      group = { name = "SAG Alpha" },
    }
    for k, v in pairs(overrides or {}) do ship[k] = v end
    return ship
  end

  ---Create a mock contact with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildContact(overrides)
    local contact = {
      guid = "CONTACT-001",
      typed = constants.CONTACT_TYPES.FACILITY_MOBILE,
      inArea = function() return true end,
    }
    for k, v in pairs(overrides or {}) do contact[k] = v end
    return contact
  end

  ---Create an amphibious config with one zone holding SAG Alpha
  ---@return table
  local function buildAmphibOps()
    return {
      fireSupport = { airlandingShotQty = 440 },
      zones = {
        {
          name = "A",
          sags = {
            { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
          },
        },
      },
    }
  end

  ---Create zone states with zone A at the given phase
  ---@param phase string
  ---@return table
  local function buildZoneStates(phase)
    return { A = { phase = phase } }
  end

  describe("attackAirlandingZone", function()
    it("should attack filtered mobile ground contacts for a valid Type 052D SAG ship", function()
      local ship = buildShip()
      local contacts = {
        buildContact({ guid = "C-1" }),
        buildContact({ guid = "C-2" }),
        buildContact({
          guid = "C-3",
          typed = constants.CONTACT_TYPES.AIR,
        }),
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = DirectFirePrep.attackAirlandingZone(
        buildAmphibOps(),
        buildZoneStates(constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT),
        ship
      )

      assert.is_true(result)
      assert.stub(stubSetDoctrine).was.called_with(
        { side = ship.side, unitname = ship.group.name },
        { weapon_control_status_land = constants.WCS.TIGHT }
      )
      assert.stub(stubAttackContacts).was.called_with({
        contacts = { "C-1", "C-2" },
        qty = 220,
        attackingUnits = { ship },
        weaponDBID = constants.WEAPONS.HPJ_38,
      })
    end)

    it("should return false for ships outside the supported SAG destroyer context", function()
      local ship = buildShip({ dbid = constants.PLATFORMS.TYPE_054A })

      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = DirectFirePrep.attackAirlandingZone({ zones = {} }, {}, ship)

      assert.is_false(result)
      assert.stub(stubAttackContacts).was_not.called()
    end)

    for _, phase in ipairs({ "WAITING_ARRIVAL", "MOVING" }) do
      it("should hold fire in " .. phase .. " before the zone reaches WAITING_ASSAULT", function()
        local stubGetContacts = trackStub(stub(GameApi, "ScenEdit_GetContacts").returns({ buildContact() }))
        local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

        local result = DirectFirePrep.attackAirlandingZone(
          buildAmphibOps(),
          buildZoneStates(constants.AMPHIBIOUS_PHASES[phase]),
          buildShip()
        )

        assert.is_false(result)
        assert.stub(stubGetContacts).was_not.called()
        assert.stub(stubAttackContacts).was_not.called()
      end)
    end

    it("should hold fire once the zone moves on to administrative offloading", function()
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns({ buildContact() }))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = DirectFirePrep.attackAirlandingZone(
        buildAmphibOps(),
        buildZoneStates(constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING),
        buildShip()
      )

      assert.is_false(result)
      assert.stub(stubAttackContacts).was_not.called()
    end)

    it("should return false when no mobile ground contacts remain after filtering", function()
      local contacts = {
        buildContact({
          guid = "C-1",
          inArea = function() return false end,
        }),
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = DirectFirePrep.attackAirlandingZone(
        buildAmphibOps(),
        buildZoneStates(constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT),
        buildShip()
      )

      assert.is_false(result)
      assert.stub(stubSetDoctrine).was_not.called()
    end)
  end)

  describe("scheduleAirRecon", function()
    it("should queue the zone's recon template", function()
      local template = { templateId = "GJ11_RECON" }
      local config = { red = { recon = { templates = { GJ11_RECON = template } } } }
      local reconState = {}
      local stubAddReconEntry = trackStub(stub(StrikePlanner, "addReconEntry"))

      DirectFirePrep.scheduleAirRecon(config, reconState, { air = { reconTemplate = "GJ11_RECON" } })

      assert.stub(stubAddReconEntry).was.called_with(reconState, template)
    end)

    it("should skip zones without a recon template", function()
      local stubAddReconEntry = trackStub(stub(StrikePlanner, "addReconEntry"))

      DirectFirePrep.scheduleAirRecon({ red = { recon = { templates = {} } } }, {}, { air = {} })

      assert.stub(stubAddReconEntry).was_not.called()
    end)
  end)
end)
