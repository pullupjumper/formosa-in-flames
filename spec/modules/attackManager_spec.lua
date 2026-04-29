local AttackManager = require("src.modules.attackManager")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("AttackManager", function()
  ---@type luassert.spy[]
  local activeStubs

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a mock doctrine object
  ---@param overrides? table
  ---@return table
  local function makeDoctrine(overrides)
    local doctrine = {
      weapon_control_status_land = 0,
    }
    if overrides then
      for k, v in pairs(overrides) do
        doctrine[k] = v
      end
    end
    return doctrine
  end

  ---Create a mock contact
  ---@param overrides? table
  ---@return table
  local function makeContact(overrides)
    local contact = {
      guid = "CONTACT-001",
    }
    if overrides then
      for k, v in pairs(overrides) do
        contact[k] = v
      end
    end
    return contact
  end

  ---Create a mock unit
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "UNIT-001",
      name = "Unit One",
      side = constants.SIDES.ENEMY,
    }
    if overrides then
      for k, v in pairs(overrides) do
        unit[k] = v
      end
    end
    return unit
  end

  ---Create a standard weapon info object
  ---@param overrides? table
  ---@return table
  local function makeWeaponInfo(overrides)
    local info = {
      weaponDBID = 1001,
      mountDBID = 2001,
      availableWeapons = 4,
      maxWeapons = 8,
      assignedWeapons = 0,
    }
    if overrides then
      for k, v in pairs(overrides) do
        info[k] = v
      end
    end
    return info
  end

  -- ============================================================================
  -- attackContact
  -- ============================================================================

  describe("attackContact", function()
    -- Positive: allocates ammo from a single unit and advances index
    it("should attack contact with single unit and allocate requested ammo", function()
      local contact = makeContact()
      local unit = makeUnit({ name = "Shooter A", guid = "UNIT-A" })
      local firingUnits = { { name = "Shooter A", weaponDBID = 1001 } }

      local stubGetContact = trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "Shooter A" then return unit end
        return nil
      end))
      trackStub(stub(GameUtils, "getWeaponInfo").returns(makeWeaponInfo({ availableWeapons = 5 })))
      trackStub(stub(GameApi, "ScenEdit_GetDoctrine").returns(makeDoctrine()))
      trackStub(stub(GameApi, "ScenEdit_WeaponAllocation").returns({}))
      local stubAttack = trackStub(stub(GameApi, "ScenEdit_AttackContact").returns(true))

      local result = AttackManager.attackContact(contact.guid, 3, firingUnits, 1, 1, nil, constants.SIDES.ENEMY)

      assert.are.equal(3, result.ammoAllocated)
      assert.are.equal(1, result.firingUnitIdx)
      assert.are.equal(1, result.shooterIdx)
      assert.stub(stubGetContact).was.called_with(constants.SIDES.ENEMY, contact.guid)
      assert.stub(stubAttack).was.called_with("UNIT-A", contact.guid, {
        mode = "1",
        qty = 3,
        mount = 2001,
        weapon = 1001,
      })
    end)

    -- Negative: skips attack when doctrine is hold fire
    it("should not attack when doctrine weapon control is hold", function()
      local contact = makeContact()
      local unit = makeUnit({ name = "Shooter B", guid = "UNIT-B" })
      local firingUnits = { { name = "Shooter B", weaponDBID = 1001 } }

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))
      trackStub(stub(GameUtils, "getWeaponInfo").returns(makeWeaponInfo()))
      trackStub(stub(GameApi, "ScenEdit_GetDoctrine").returns(makeDoctrine({ weapon_control_status_land = 2 })))
      local stubAttack = trackStub(stub(GameApi, "ScenEdit_AttackContact").returns(true))

      local result = AttackManager.attackContact(contact.guid, 2, firingUnits, 1, 1, nil, constants.SIDES.ENEMY)

      assert.are.equal(0, result.ammoAllocated)
      assert.stub(stubAttack).was_not.called()
    end)

    -- Boundary: each salvo is capped by available weapons
    it("should cap each attack salvo to available weapons", function()
      local contact = makeContact()
      local unit = makeUnit({ name = "Shooter C", guid = "UNIT-C" })
      local firingUnits = { { name = "Shooter C", weaponDBID = 1001 } }

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))
      trackStub(stub(GameUtils, "getWeaponInfo").returns(makeWeaponInfo({ availableWeapons = 2 })))
      trackStub(stub(GameApi, "ScenEdit_GetDoctrine").returns(makeDoctrine()))
      trackStub(stub(GameApi, "ScenEdit_WeaponAllocation").returns({}))
      local stubAttack = trackStub(stub(GameApi, "ScenEdit_AttackContact").returns(true))

      local result = AttackManager.attackContact(contact.guid, 5, firingUnits, 1, 1, nil, constants.SIDES.ENEMY)

      assert.are.equal(6, result.ammoAllocated)
      assert.stub(stubAttack).was.called(3)
      assert.stub(stubAttack).was.called_with("UNIT-C", contact.guid, {
        mode = "1",
        qty = 2,
        mount = 2001,
        weapon = 1001,
      })
    end)

    -- Negative: exits when contact is missing
    it("should return zero allocation when contact does not exist", function()
      local firingUnits = { { name = "Shooter D", weaponDBID = 1001 } }
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local result = AttackManager.attackContact("CONTACT-MISSING", 3, firingUnits, 1, 1, nil, constants.SIDES.ENEMY)

      assert.are.equal(0, result.ammoAllocated)
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Positive: processes grouped units by shooter index and advances to next firing unit
    it("should process unit group using shooterIdx and advance after last group member", function()
      local contact = makeContact({ guid = "CONTACT-GRP" })
      local groupHost = makeUnit({
        name = "Battery A",
        guid = "BATTERY-A",
        group = { unitlist = { "G-1", "G-2" } },
      })
      local groupMember1 = makeUnit({ guid = "G-1", side = constants.SIDES.ENEMY })
      local groupMember2 = makeUnit({ guid = "G-2", side = constants.SIDES.ENEMY })
      local firingUnits = {
        { name = "Battery A", weaponDBID = 1001 },
        { name = "Battery B", weaponDBID = 1001 },
      }

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "Battery A" then return groupHost end
        if id == "G-1" then return groupMember1 end
        if id == "G-2" then return groupMember2 end
        return nil
      end))
      trackStub(stub(GameUtils, "getWeaponInfo").returns(makeWeaponInfo({ availableWeapons = 2 })))
      trackStub(stub(GameApi, "ScenEdit_GetDoctrine").returns(makeDoctrine()))
      trackStub(stub(GameApi, "ScenEdit_WeaponAllocation").returns({}))
      local stubAttack = trackStub(stub(GameApi, "ScenEdit_AttackContact").returns(true))

      local result = AttackManager.attackContact(contact.guid, 2, firingUnits, 1, 2, nil, constants.SIDES.ENEMY)

      assert.are.equal(2, result.ammoAllocated)
      assert.are.equal(2, result.firingUnitIdx)
      assert.are.equal(1, result.shooterIdx)
      assert.stub(stubAttack).was.called_with("G-2", contact.guid, {
        mode = "1",
        qty = 2,
        mount = 2001,
        weapon = 1001,
      })
    end)
  end)

  -- ============================================================================
  -- attackContacts
  -- ============================================================================

  describe("attackContacts", function()
    -- Positive: aggregates ammo from each contact attack
    it("should sum allocated ammo from multiple contacts", function()
      local stubAttackContact = trackStub(stub(AttackManager, "attackContact").invokes(
        function(contactGUID, qty, firingUnits, firingUnitIdx, shooterIdx, weaponDBID, sideName)
          if contactGUID == "C-1" and qty == 2 and sideName == constants.SIDES.ENEMY then
            return { firingUnitIdx = 1, shooterIdx = 1, ammoAllocated = 2 }
          end
          if contactGUID == "C-2" and qty == 2 and sideName == constants.SIDES.ENEMY then
            return { firingUnitIdx = 1, shooterIdx = 1, ammoAllocated = 1 }
          end
          return { firingUnitIdx = firingUnitIdx, shooterIdx = shooterIdx, ammoAllocated = 0 }
        end
      ))

      local result = AttackManager.attackContacts({
        contacts = { "C-1", "C-2" },
        qty = 2,
        firingUnits = { { name = "U1", weaponDBID = 1001 } },
      })

      assert.are.equal(3, result)
      assert.stub(stubAttackContact).was.called(2)
    end)

    -- Boundary: defaults sideName to ENEMY when omitted
    it("should default sideName to enemy", function()
      local stubAttackContact = trackStub(stub(AttackManager, "attackContact").returns({
        firingUnitIdx = 1,
        shooterIdx = 1,
        ammoAllocated = 1,
      }))

      local result = AttackManager.attackContacts({
        contacts = { "C-3" },
        qty = 1,
        firingUnits = { { name = "U1", weaponDBID = 1001 } },
      })

      assert.are.equal(1, result)
      assert.stub(stubAttackContact).was.called_with("C-3", 1, { { name = "U1", weaponDBID = 1001 } }, 1, 1, nil,
        constants.SIDES.ENEMY)
    end)

    -- Negative: returns zero when no contacts are provided
    it("should return zero when contacts are empty", function()
      local stubAttackContact = trackStub(stub(AttackManager, "attackContact"))

      local result = AttackManager.attackContacts({
        contacts = {},
        qty = 2,
        firingUnits = { { name = "U1", weaponDBID = 1001 } },
      })

      assert.are.equal(0, result)
      assert.stub(stubAttackContact).was_not.called()
    end)
  end)
end)
