---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- LandingOps SagFireSupport Unit Tests
local SagFireSupport = require("src.modules.landingOps.sagFireSupport")
local GameApi = require("src.utils.gameApi")
local AttackManager = require("src.modules.attackManager")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("SagFireSupport", function()
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
      local configOverrides = {
        fireSupport = { airlandingShotQty = 440 },
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = SagFireSupport.attackAirlandingZone(configOverrides, ship)

      assert.is_true(result)
      assert.stub(stubSetDoctrine).was.called_with(
        { side = ship.side, unitname = ship.group.name },
        { weapon_control_status_land = constants.WCS.FREE }
      )
      assert.stub(stubAttackContacts).was.called_with({
        contacts = { "C-1", "C-2" },
        qty = 220,
        firingUnits = { ship },
        weaponDBID = constants.WEAPONS.HPJ_38,
      })
    end)

    it("should return false for ships outside the supported SAG destroyer context", function()
      local ship = buildShip({ dbid = constants.PLATFORMS.TYPE_054A })
      local configOverrides = { zones = {} }

      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = SagFireSupport.attackAirlandingZone(configOverrides, ship)

      assert.is_false(result)
      assert.stub(stubAttackContacts).was_not.called()
    end)

    it("should return false when no mobile ground contacts remain after filtering", function()
      local ship = buildShip()
      local contacts = {
        buildContact({
          guid = "C-1",
          inArea = function() return false end,
        }),
      }
      local configOverrides = {
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = SagFireSupport.attackAirlandingZone(configOverrides, ship)

      assert.is_false(result)
      assert.stub(stubSetDoctrine).was_not.called()
    end)
  end)
end)
