-- TargetingProcess Unit Tests
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
---@diagnostic disable-next-line: invisible
local _internal = TargetingProcess._internal
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Recon = require("src.modules.strikePlanner.recon")
local constants = require("src.core.constants")
local Utils = require("src.utils.utils")
local BaseConfig = require("src.core.config")

describe("TargetingProcess", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local warnStub

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    warnStub = trackStub(stub(Logger, "warn"))
    trackStub(stub(Logger, "log"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a contact with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeContact(overrides)
    local contact = {
      guid = "contact-001",
      type_description = "Building",
      latitude = 25.0,
      longitude = 121.0,
      typed = 4,
      emissions = nil,
      lastDetections = nil,
      BDA = nil,
      actualunitid = "unit-001",
      posture = nil,
      inArea = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do contact[k] = v end
    end
    return contact
  end

  ---Create a target entry for targetlist
  ---@param overrides? table
  ---@return table
  local function makeTargetEntry(overrides)
    local entry = {
      name = "Hsinchu/Runway (3000m)",
      guid = "target-001",
      category = "Airfield",
      subType = "Runway (3000m)",
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a scan config for scanTargets
  ---@param overrides? table
  ---@return table
  local function makeScanConfig(overrides)
    local config = {
      distanceThreshold = 5,
      taiwanAirBases = { "Hsinchu", "Taoyuan" },
      taiwanPorts = { "Keelung" },
      targetCategories = {
        airfield = {
          runwayPattern = "Runway %(%d+m%)",
          taxiwayPattern = "Taxiway",
          shelterPattern = "Shelter",
          hangarPattern = "Hangar",
          tarmacPattern = "Tarmac",
          helipadPattern = "Helipad",
          ammoBunkerPattern = "Ammo Bunker",
          ammoRevetmentPattern = "Ammo Revetment",
        },
        port = {
          pierPattern = "Pier",
        },
        radar = {
          radarPattern = "Radar",
        },
        sam = {
          skyBowPattern = "Sky Bow",
        },
        asm = {
          asmPattern = "Hsiung Feng",
        },
        c2 = {
          hengshanPattern = "Hengshan",
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do config[k] = v end
    end
    return config
  end

  ---Create a saveData structure
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        targetlist = overrides.targetlist or {},
        sigint = {
          transmissions = overrides.transmissions or {},
        },
        recon = overrides.recon or { enabled = true, queue = {} },
      },
    }
  end

  ---Create a task structure
  ---@param overrides? table
  ---@return table
  local function makeTask(overrides)
    local task = {
      target = {
        list = overrides and overrides.list or {},
        areas = overrides and overrides.areas or { { "area-1" } },
        contactAge = overrides and overrides.contactAge or 300,
        minTargetCount = overrides and overrides.minTargetCount or 1,
      },
    }
    return task
  end

  ---Create a config structure
  ---@param overrides? table
  ---@return SBJ__Config
  local function makeConfig(overrides)
    overrides = overrides or {}
    local config = Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
    config.c.sigint.maxRange = overrides.maxRange or 50
    config.c.sigint.maxCount = overrides.maxCount or 3
    return config
  end

  -- ============================================================================
  -- scanTargets
  -- ============================================================================

  describe("scanTargets", function()
    -- Positive: categorizes runway contact near airbase
    it("should categorize runway contact near known airbase", function()
      local baseContact = makeContact({
        guid = "base-001",
        type_description = "Hsinchu",
        latitude = 24.8,
        longitude = 120.9,
      })
      local runwayContact = makeContact({
        guid = "runway-001",
        type_description = "Runway (3000m)",
        latitude = 24.81,
        longitude = 120.91,
      })
      local contacts = { baseContact, runwayContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))
      trackStub(stub(GameApi, "Tool_Range").returns(2))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("Airfield", saveData.c.targetlist[1].category)
      assert.are.equal("runway-001", saveData.c.targetlist[1].guid)
    end)

    -- Positive: categorizes pier contact near port
    it("should categorize pier contact near known port", function()
      local portContact = makeContact({
        guid = "port-001",
        type_description = "Keelung",
        latitude = 25.1,
        longitude = 121.7,
      })
      local pierContact = makeContact({
        guid = "pier-001",
        type_description = "Pier",
        latitude = 25.11,
        longitude = 121.71,
      })
      local contacts = { portContact, pierContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))
      trackStub(stub(GameApi, "Tool_Range").returns(1))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("Port", saveData.c.targetlist[1].category)
      assert.are.equal("pier-001", saveData.c.targetlist[1].guid)
    end)

    -- Positive: categorizes standalone radar target
    it("should categorize standalone radar target", function()
      local radarContact = makeContact({
        guid = "radar-001",
        type_description = "Radar Station",
      })
      local contacts = { radarContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("ISR", saveData.c.targetlist[1].category)
    end)

    -- Positive: categorizes SAM target
    it("should categorize Sky Bow SAM target", function()
      local samContact = makeContact({
        guid = "sam-001",
        type_description = "Sky Bow III",
      })
      local contacts = { samContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("SAM", saveData.c.targetlist[1].category)
    end)

    -- Positive: categorizes ASM target
    it("should categorize ASM target", function()
      local asmContact = makeContact({
        guid = "asm-001",
        type_description = "Hsiung Feng III",
      })
      local contacts = { asmContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("ASM", saveData.c.targetlist[1].category)
    end)

    -- Positive: categorizes C2 target
    it("should categorize Hengshan C2 target", function()
      local c2Contact = makeContact({
        guid = "c2-001",
        type_description = "Hengshan Command Center",
      })
      local contacts = { c2Contact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("C2", saveData.c.targetlist[1].category)
    end)

    -- Positive: categorizes shelter near airbase
    it("should categorize shelter near known airbase", function()
      local baseContact = makeContact({
        guid = "base-002",
        type_description = "Taoyuan",
        latitude = 25.0,
        longitude = 121.2,
      })
      local shelterContact = makeContact({
        guid = "shelter-001",
        type_description = "Shelter",
        latitude = 25.01,
        longitude = 121.21,
      })
      local contacts = { baseContact, shelterContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))
      trackStub(stub(GameApi, "Tool_Range").returns(1))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(1, #saveData.c.targetlist)
      assert.are.equal("Airfield", saveData.c.targetlist[1].category)
      assert.is_true(string.find(saveData.c.targetlist[1].name, "Taoyuan") ~= nil)
    end)

    -- Negative: no contacts returned
    it("should set empty targetlist when no contacts returned", function()
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(nil))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(0, #saveData.c.targetlist)
      assert.stub(warnStub).was.called(1)
    end)

    -- Negative: airfield contact too far from base
    it("should not categorize airfield contact too far from base", function()
      local baseContact = makeContact({
        guid = "base-003",
        type_description = "Hsinchu",
        latitude = 24.8,
        longitude = 120.9,
      })
      local runwayContact = makeContact({
        guid = "runway-far",
        type_description = "Runway (2500m)",
        latitude = 26.0,
        longitude = 122.0,
      })
      local contacts = { baseContact, runwayContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))
      trackStub(stub(GameApi, "Tool_Range").returns(100))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(0, #saveData.c.targetlist)
    end)

    -- Negative: unrecognized contact description
    it("should skip contacts that do not match any pattern", function()
      local unknownContact = makeContact({
        guid = "unknown-001",
        type_description = "Unknown Facility",
      })
      local contacts = { unknownContact }
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(0, #saveData.c.targetlist)
    end)

    -- Boundary: empty contacts list
    it("should produce empty targetlist for empty contacts array", function()
      local saveData = makeSaveData()
      local scanConfig = makeScanConfig()

      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns({}))

      TargetingProcess.scanTargets("China", scanConfig, saveData)

      assert.are.equal(0, #saveData.c.targetlist)
    end)
  end)

  -- ============================================================================
  -- findInfantry
  -- ============================================================================

  describe("findInfantry", function()
    -- Positive: finds infantry in area
    it("should return guids of ground infantry contacts in area", function()
      local contact = makeContact({
        guid = "infantry-001",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findInfantry({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("infantry-001", result[1])
    end)

    -- Positive: sets posture to H
    it("should set posture to H for found infantry", function()
      local contact = makeContact({
        guid = "infantry-002",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      _internal.findInfantry({ contacts = { contact }, task = task })

      assert.are.equal("H", contact.posture)
    end)

    -- Negative: wrong typed value
    it("should not return contacts with non-infantry typed value", function()
      local contact = makeContact({
        guid = "ship-001",
        typed = 2,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findInfantry({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: not in area
    it("should not return infantry contacts outside of area", function()
      local contact = makeContact({
        guid = "infantry-003",
        typed = 8,
        inArea = function() return false end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findInfantry({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- findAirborne
  -- ============================================================================

  describe("findAirborne", function()
    -- Positive: finds P-3C by sensor DBID
    it("should return P-3C contact with SEAVUE emission in area", function()
      local contact = makeContact({
        guid = "p3c-001",
        typed = 0,
        emissions = { { sensor_dbid = constants.SENSORS.P3C_SEAVUE } },
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("p3c-001", result[1])
    end)

    -- Positive: finds E-2K by sensor DBID
    it("should return E-2K contact with APS-145 emission in area", function()
      local contact = makeContact({
        guid = "e2k-001",
        typed = 0,
        emissions = { { sensor_dbid = constants.SENSORS.E2K_APS145 } },
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("e2k-001", result[1])
    end)

    -- Negative: no emissions
    it("should not return contacts without emissions", function()
      local contact = makeContact({
        guid = "air-001",
        typed = 0,
        emissions = nil,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: wrong sensor DBID
    it("should not return contacts with unrecognized sensor DBID", function()
      local contact = makeContact({
        guid = "air-002",
        typed = 0,
        emissions = { { sensor_dbid = 99999 } },
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: wrong typed value
    it("should not return contacts with non-aircraft typed value", function()
      local contact = makeContact({
        guid = "ground-001",
        typed = 8,
        emissions = { { sensor_dbid = constants.SENSORS.P3C_SEAVUE } },
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: not in area
    it("should not return airborne contacts outside area", function()
      local contact = makeContact({
        guid = "p3c-002",
        typed = 0,
        emissions = { { sensor_dbid = constants.SENSORS.P3C_SEAVUE } },
        inArea = function() return false end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findAirborne({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- analyzeEmissions
  -- ============================================================================

  describe("analyzeEmissions", function()
    ---Helper to create a SAM contact with specific sensor
    ---@param sensorDbid number
    ---@param overrides? table
    ---@return table
    local function makeSAMContact(sensorDbid, overrides)
      local contact = makeContact({
        guid = "sam-001",
        emissions = { { sensor_dbid = sensorDbid } },
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      if overrides then
        for k, v in pairs(overrides) do contact[k] = v end
      end
      return contact
    end

    -- Positive: detects TK-3 Long Mountain radar
    it("should detect SAM with TK3 Long Mountain radar emission", function()
      local contact = makeSAMContact(constants.SENSORS.TK3_LONG_MOUNTAIN)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("sam-001", result[1])
    end)

    -- Positive: detects TK-3 Long White 2 radar
    it("should detect SAM with TK3 Long White 2 radar emission", function()
      local contact = makeSAMContact(constants.SENSORS.TK3_LONG_WHITE_2)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
    end)

    -- Positive: detects PAC-3 MPQ-65 radar
    it("should detect SAM with PAC3 MPQ65 radar emission", function()
      local contact = makeSAMContact(constants.SENSORS.PAC3_MPQ65)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
    end)

    -- Positive: detects TC-2 CS MPQ90 radar
    it("should detect SAM with TC2 CS MPQ90 radar emission", function()
      local contact = makeSAMContact(constants.SENSORS.TC2_CS_MPQ90)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
    end)

    -- Positive: detects TK-2 CS MPG25 radar
    it("should detect SAM with TK2 CS MPG25 radar emission", function()
      local contact = makeSAMContact(constants.SENSORS.TK2_CS_MPG25)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
    end)

    -- Negative: contact age exceeds threshold
    it("should not detect SAM when contact age exceeds threshold", function()
      local contact = makeSAMContact(constants.SENSORS.TK3_LONG_MOUNTAIN, {
        lastDetections = { { age = 500 } },
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: not in area
    it("should not detect SAM contact outside area", function()
      local contact = makeSAMContact(constants.SENSORS.TK3_LONG_MOUNTAIN, {
        inArea = function() return false end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: unrecognized sensor
    it("should not detect SAM with unrecognized sensor DBID", function()
      local contact = makeSAMContact(99999)
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty emissions table
    it("should not crash when contact emissions is empty table", function()
      local contact = makeContact({
        guid = "sam-empty-001",
        emissions = {},
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Boundary: nil emissions
    it("should not crash when contact emissions is nil", function()
      local contact = makeContact({
        guid = "sam-nil-001",
        emissions = nil,
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.analyzeEmissions({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- findMobileTargets
  -- ============================================================================

  describe("findMobileTargets", function()
    -- Positive: finds mobile ground units
    it("should return guids of ground mobile contacts in area", function()
      local contact = makeContact({
        guid = "mobile-001",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findMobileTargets({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("mobile-001", result[1])
    end)

    -- Positive: sets posture to H
    it("should set posture to H for found mobile targets", function()
      local contact = makeContact({
        guid = "mobile-002",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      _internal.findMobileTargets({ contacts = { contact }, task = task })

      assert.are.equal("H", contact.posture)
    end)

    -- Negative: not ground type
    it("should not return non-ground contacts", function()
      local contact = makeContact({
        guid = "air-001",
        typed = 0,
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findMobileTargets({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: not in area
    it("should not return mobile targets outside area", function()
      local contact = makeContact({
        guid = "mobile-003",
        typed = 8,
        inArea = function() return false end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findMobileTargets({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- findC2
  -- ============================================================================

  describe("findC2", function()
    -- Positive: finds ROCC
    it("should return guid of ROCC contact in area", function()
      local contact = makeContact({
        guid = "rocc-001",
        type_description = "ROCC Command",
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findC2({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("rocc-001", result[1])
    end)

    -- Positive: finds TAAOC
    it("should return guid of TAAOC contact in area", function()
      local contact = makeContact({
        guid = "taaoc-001",
        type_description = "TAAOC Center",
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findC2({ contacts = { contact }, task = task })

      assert.are.equal(1, #result)
      assert.are.equal("taaoc-001", result[1])
    end)

    -- Negative: non-C2 description
    it("should not return contacts without ROCC or TAAOC in description", function()
      local contact = makeContact({
        guid = "building-001",
        type_description = "Generic Building",
        inArea = function() return true end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findC2({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)

    -- Negative: C2 not in area
    it("should not return C2 contacts outside area", function()
      local contact = makeContact({
        guid = "rocc-002",
        type_description = "ROCC",
        inArea = function() return false end,
      })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findC2({ contacts = { contact }, task = task })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- findNavalTargets
  -- ============================================================================

  describe("findNavalTargets", function()
    -- Positive: finds naval contacts in area within contact age
    it("should return naval contacts in area within contact age", function()
      local contact = makeContact({
        guid = "ship-001",
        typed = 2,
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.findNavalTargets({
        contacts = { contact },
        task = task,
      })

      assert.are.equal(1, #result)
      assert.are.equal("ship-001", result[1])
    end)

    -- Negative: contact age exceeds threshold
    it("should not return naval contacts with expired contact age", function()
      local contact = makeContact({
        guid = "ship-003",
        typed = 2,
        lastDetections = { { age = 500 } },
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.findNavalTargets({
        contacts = { contact },
        task = task,
      })

      assert.are.equal(0, #result)
    end)

    -- Negative: not typed 2 (not naval)
    it("should not return non-naval contacts", function()
      local contact = makeContact({
        guid = "ground-001",
        typed = 8,
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.findNavalTargets({
        contacts = { contact },
        task = task,
      })

      assert.are.equal(0, #result)
    end)

    -- Negative: not in area
    it("should not return naval contacts outside area", function()
      local contact = makeContact({
        guid = "ship-006",
        typed = 2,
        lastDetections = { { age = 100 } },
        inArea = function() return false end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })

      local result = _internal.findNavalTargets({
        contacts = { contact },
        task = task,
      })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- findRadioDirection
  -- ============================================================================

  describe("findRadioDirection", function()
    -- Positive: finds targets near radio sources
    it("should return targets near radio transmission sources", function()
      local contact = makeContact({
        guid = "mobile-radio-001",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })
      local config = makeConfig({ maxRange = 50, maxCount = 3 })
      local saveData = makeSaveData({
        transmissions = {
          ["tm-001"] = {
            latitude = 25.0,
            longitude = 121.0,
            currentDetectionLevel = 5,
            type = "fixed",
          },
        },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "Tool_Range").returns(10))

      local result = _internal.findRadioDirection({
        contacts = { contact },
        task = task,
        config = config,
        saveData = saveData,
      })

      assert.is_not_nil(result)
      assert.are.equal(1, #result)
    end)

    -- Negative: no config or saveData
    it("should return empty table when config is nil", function()
      local contact = makeContact({ guid = "c-001", typed = 8, inArea = function() return true end })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findRadioDirection({
        contacts = { contact },
        task = task,
        config = nil,
        saveData = makeSaveData(),
      })

      assert.are.equal(0, #result)
    end)

    it("should return empty table when saveData is nil", function()
      local contact = makeContact({ guid = "c-002", typed = 8, inArea = function() return true end })
      local task = makeTask({ areas = { { "area-1" } } })

      local result = _internal.findRadioDirection({
        contacts = { contact },
        task = task,
        config = makeConfig(),
        saveData = nil,
      })

      assert.are.equal(0, #result)
    end)

    -- Negative: target out of range
    it("should not return targets beyond max SIGINT range", function()
      local contact = makeContact({
        guid = "mobile-radio-003",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })
      local config = makeConfig({ maxRange = 50, maxCount = 3 })
      local saveData = makeSaveData({
        transmissions = {
          ["tm-003"] = {
            latitude = 25.0,
            longitude = 121.0,
            currentDetectionLevel = 5,
            type = "fixed",
          },
        },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "Tool_Range").returns(100))

      local result = _internal.findRadioDirection({
        contacts = { contact },
        task = task,
        config = config,
        saveData = saveData,
      })

      assert.are.equal(0, #result)
    end)

    -- Negative: detection level below threshold
    it("should not return targets when detection level is below threshold", function()
      local contact = makeContact({
        guid = "mobile-radio-004",
        typed = 8,
        inArea = function() return true end,
      })
      local task = makeTask({ contactAge = 300, areas = { { "area-1" } } })
      local config = makeConfig({ maxRange = 50, maxCount = 3 })
      local saveData = makeSaveData({
        transmissions = {
          ["tm-004"] = {
            latitude = 25.0,
            longitude = 121.0,
            currentDetectionLevel = 2,
            type = "fixed",
          },
        },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "Tool_Range").returns(10))

      local result = _internal.findRadioDirection({
        contacts = { contact },
        task = task,
        config = config,
        saveData = saveData,
      })

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- triggerReconTracking
  -- ============================================================================

  describe("triggerReconTracking", function()
    local mockFilteredUnits
    local vpGetSideStub
    local reconTrackTargetStub

    before_each(function()
      mockFilteredUnits = { { guid = "uav-001" } }
      local mockSide = {
        unitsBy = function() return mockFilteredUnits end,
      }
      vpGetSideStub = trackStub(stub(GameApi, "VP_GetSide").returns(mockSide))
      reconTrackTargetStub = trackStub(stub(Recon, "trackTarget").returns(true))
    end)

    -- Positive: triggers WZ-8 for findNavalTargets
    it("should call Recon.trackTarget with WZ8 for findNavalTargets", function()
      local contact = makeContact({
        guid = "ship-001",
        typed = 2,
      })
      local opts = {
        contacts = { contact },
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findNavalTargets", { "ship-001" })

      assert.stub(reconTrackTargetStub).was.called(1)
      assert.stub(reconTrackTargetStub).was.called_with(
        opts.saveData.c.recon,
        mockFilteredUnits,
        constants.PLATFORMS.WZ8,
        contact
      )
    end)

    -- Positive: triggers BZK-005 for findRadioDirection
    it("should call Recon.trackTarget with BZK005 for findRadioDirection", function()
      local contact = makeContact({
        guid = "radio-001",
        typed = 8,
      })
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      local opts = {
        contacts = {},
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findRadioDirection", { "radio-001" })

      assert.stub(reconTrackTargetStub).was.called(1)
      assert.stub(reconTrackTargetStub).was.called_with(
        opts.saveData.c.recon,
        mockFilteredUnits,
        constants.PLATFORMS.BZK005,
        contact
      )
    end)

    -- Negative: no tracking config for filter
    it("should not call Recon.trackTarget for non-tracking filter", function()
      local opts = {
        contacts = {},
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findInfantry", { "inf-001" })

      assert.stub(reconTrackTargetStub).was_not.called()
    end)

    -- Negative: saveData is nil
    it("should not call Recon.trackTarget when saveData is nil", function()
      local opts = {
        contacts = {},
        saveData = nil,
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findNavalTargets", { "ship-001" })

      assert.stub(reconTrackTargetStub).was_not.called()
    end)

    -- Negative: VP_GetSide returns nil
    it("should not call Recon.trackTarget when VP_GetSide returns nil", function()
      vpGetSideStub.returns(nil)

      local opts = {
        contacts = { makeContact({ guid = "ship-001" }) },
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findNavalTargets", { "ship-001" })

      assert.stub(reconTrackTargetStub).was_not.called()
    end)

    -- Negative: no aircraft available
    it("should not call Recon.trackTarget when no aircraft available", function()
      local mockSide = {
        unitsBy = function() return nil end,
      }
      vpGetSideStub.returns(mockSide)

      local opts = {
        contacts = { makeContact({ guid = "ship-001" }) },
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findNavalTargets", { "ship-001" })

      assert.stub(reconTrackTargetStub).was_not.called()
    end)

    -- Negative: target not found in contacts (findNavalTargets)
    it("should not call Recon.trackTarget when target contact not found", function()
      local opts = {
        contacts = { makeContact({ guid = "other-001" }) },
        saveData = makeSaveData(),
        task = makeTask(),
      }

      _internal.triggerReconTracking(opts, "findNavalTargets", { "ship-missing" })

      assert.stub(reconTrackTargetStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- processDynamicTargets recon integration
  -- ============================================================================

  describe("processTargets recon integration", function()
    local mockFilteredUnits
    local reconTrackTargetStub

    before_each(function()
      mockFilteredUnits = { { guid = "uav-001" } }
      local mockSide = {
        unitsBy = function() return mockFilteredUnits end,
      }
      trackStub(stub(GameApi, "VP_GetSide").returns(mockSide))
      reconTrackTargetStub = trackStub(stub(Recon, "trackTarget").returns(true))
    end)

    -- Positive: findNavalTargets triggers WZ-8 recon via processDynamicTargets
    it("should trigger WZ-8 recon when findNavalTargets finds targets", function()
      local contact = makeContact({
        guid = "ship-integ-001",
        typed = 2,
        lastDetections = { { age = 100 } },
        inArea = function() return true end,
      })
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        filterNames = { "findNavalTargets" },
        areas = { { "area-1" } },
        contactAge = 300,
        minTargetCount = 1,
      }

      TargetingProcess.processTargets(config, saveData, { contact }, targetConfig, false)

      assert.stub(reconTrackTargetStub).was.called(1)
      local callArgs = reconTrackTargetStub.calls[1]
      assert.are.equal(constants.PLATFORMS.WZ8, callArgs.vals[3])
    end)

    -- Positive: findRadioDirection triggers BZK-005 recon via processDynamicTargets
    it("should trigger BZK-005 recon when findRadioDirection finds targets", function()
      local contact = makeContact({
        guid = "mobile-integ-001",
        typed = 8,
        inArea = function() return true end,
      })
      local config = makeConfig({ maxRange = 50, maxCount = 3 })
      local saveData = makeSaveData({
        transmissions = {
          ["tm-integ-001"] = {
            latitude = 25.0,
            longitude = 121.0,
            currentDetectionLevel = 5,
            type = "mobile",
          },
        },
      })
      local targetConfig = {
        filterNames = { "findRadioDirection" },
        areas = { { "area-1" } },
        contactAge = 300,
        minTargetCount = 1,
      }

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(contact))
      trackStub(stub(GameApi, "Tool_Range").returns(10))

      TargetingProcess.processTargets(config, saveData, { contact }, targetConfig, false)

      assert.stub(reconTrackTargetStub).was.called(1)
      local callArgs = reconTrackTargetStub.calls[1]
      assert.are.equal(constants.PLATFORMS.BZK005, callArgs.vals[3])
    end)

    -- Negative: non-tracking filter does not trigger recon
    it("should not trigger recon for non-tracking filter like findInfantry", function()
      local contact = makeContact({
        guid = "infantry-integ-001",
        typed = 8,
        inArea = function() return true end,
      })
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        filterNames = { "findInfantry" },
        areas = { { "area-1" } },
        contactAge = 300,
        minTargetCount = 1,
      }

      TargetingProcess.processTargets(config, saveData, { contact }, targetConfig, false)

      assert.stub(reconTrackTargetStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- evaluateTarget
  -- ============================================================================

  describe("evaluateTarget", function()
    local getUnitStub
    before_each(function()
      getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        embarkedUnits = { Aircraft = {} },
      }))
    end)

    -- Positive: valid target with BDA and recent detection
    it("should return true for target with BDA and recent detection", function()
      local target = makeContact({
        type_description = "Runway (3000m)",
        actualunitid = "unit-001",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_true(result)
    end)

    -- Positive: first wave accepts all targets
    it("should return true for any target when isFirstWave is true", function()
      local target = makeContact({
        type_description = "Building",
        actualunitid = "unit-002",
        BDA = { STRUCTURAL = "Heavy damage" },
        lastDetections = { { age = 1000 } },
      })

      local result = _internal.evaluateTarget(target, 300, true)

      assert.is_true(result)
    end)

    -- Positive: helipad with embarked aircraft
    it("should return true for helipad with embarked aircraft", function()
      getUnitStub.returns({
        embarkedUnits = { Aircraft = { "helo-001" } },
      })

      local target = makeContact({
        type_description = "Helipad",
        actualunitid = "unit-003",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_true(result)
    end)

    -- Negative: heavily damaged target
    it("should return false for heavily damaged target", function()
      local target = makeContact({
        type_description = "Runway (3000m)",
        actualunitid = "unit-004",
        BDA = { STRUCTURAL = "Heavy damage" },
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_false(result)
    end)

    -- Negative: actual unit not found
    it("should return false when actual unit is not found", function()
      getUnitStub.returns(nil)

      local target = makeContact({
        type_description = "Runway (3000m)",
        actualunitid = "unit-missing",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_false(result)
    end)

    -- Negative: contact age exceeds threshold
    it("should return false when contact age exceeds threshold", function()
      local target = makeContact({
        type_description = "Runway (3000m)",
        actualunitid = "unit-005",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 500 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_false(result)
    end)

    -- Negative: helipad without embarked aircraft (and not first wave)
    it("should return false for helipad without embarked aircraft", function()
      local target = makeContact({
        type_description = "Helipad",
        actualunitid = "unit-006",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_false(result)
    end)

    -- Negative: nil BDA
    it("should return false when BDA is nil", function()
      local target = makeContact({
        type_description = "Runway (3000m)",
        actualunitid = "unit-007",
        BDA = nil,
        lastDetections = { { age = 100 } },
      })

      local result = _internal.evaluateTarget(target, 300, false)

      assert.is_false(result)
    end)
  end)

  -- ============================================================================
  -- assessTargetsDamage
  -- ============================================================================

  describe("assessTargetsDamage", function()
    -- Positive: returns evaluated targets
    it("should return targets that pass BDA evaluation", function()
      local target = makeContact({
        guid = "eval-001",
        type_description = "Runway (3000m)",
        actualunitid = "unit-001",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        embarkedUnits = { Aircraft = {} },
      }))

      local task = makeTask({ list = { "eval-001" }, contactAge = 300 })

      local result = _internal.assessTargetsDamage(task, false)

      assert.are.equal(1, #result)
      assert.are.equal("eval-001", result[1])
    end)

    -- Positive: first wave includes all targets
    it("should include all targets for first wave", function()
      local target = makeContact({
        guid = "eval-002",
        type_description = "Runway (3000m)",
        actualunitid = "unit-002",
        BDA = { STRUCTURAL = "Heavy damage" },
        lastDetections = { { age = 1000 } },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        embarkedUnits = { Aircraft = {} },
      }))

      local task = makeTask({ list = { "eval-002" }, contactAge = 300 })

      local result = _internal.assessTargetsDamage(task, true)

      assert.are.equal(1, #result)
    end)

    -- Negative: contact not found
    it("should skip targets when contact is not found", function()
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))

      local task = makeTask({ list = { "missing-001" }, contactAge = 300 })

      local result = _internal.assessTargetsDamage(task, false)

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty target list
    it("should return empty table for empty target list", function()
      local task = makeTask({ list = {}, contactAge = 300 })

      local result = _internal.assessTargetsDamage(task, false)

      assert.are.equal(0, #result)
    end)

    -- Boundary: nil target list
    it("should return empty table when target list is nil", function()
      local task = { target = { list = nil, contactAge = 300 } }

      local result = _internal.assessTargetsDamage(task, false)

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- filterTargetsByTypeAndBase
  -- ============================================================================

  describe("filterTargetsByTypeAndBase", function()
    -- Positive: matches by base name and subType
    it("should return targets matching base name and subType", function()
      local targetlist = {
        makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "t-001" }),
        makeTargetEntry({ name = "Taoyuan/Shelter", subType = "Shelter", guid = "t-002" }),
      }
      local queryParams = {
        { baseName = "Hsinchu", subTypes = { "Runway" } },
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)

      assert.are.equal(1, #result)
      assert.are.equal("t-001", result[1])
    end)

    -- Positive: matches without baseName (all bases)
    it("should match all bases when baseName is nil", function()
      local targetlist = {
        makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "t-001" }),
        makeTargetEntry({ name = "Taoyuan/Runway (2500m)", subType = "Runway (2500m)", guid = "t-002" }),
      }
      local queryParams = {
        { baseName = nil, subTypes = { "Runway" } },
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)

      assert.are.equal(2, #result)
    end)

    -- Positive: matches multiple subTypes
    it("should match targets with any of the specified subTypes", function()
      local targetlist = {
        makeTargetEntry({ name = "Hsinchu/Shelter", subType = "Shelter", guid = "t-001" }),
        makeTargetEntry({ name = "Hsinchu/Hangar", subType = "Hangar", guid = "t-002" }),
        makeTargetEntry({ name = "Hsinchu/Tarmac", subType = "Tarmac", guid = "t-003" }),
      }
      local queryParams = {
        { baseName = "Hsinchu", subTypes = { "Shelter", "Hangar" } },
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)

      assert.are.equal(2, #result)
    end)

    -- Negative: no matching baseName
    it("should return empty when no baseName matches", function()
      local targetlist = {
        makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "t-001" }),
      }
      local queryParams = {
        { baseName = "Songshan", subTypes = { "Runway" } },
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)

      assert.are.equal(0, #result)
    end)

    -- Negative: no matching subType
    it("should return empty when no subType matches", function()
      local targetlist = {
        makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "t-001" }),
      }
      local queryParams = {
        { baseName = "Hsinchu", subTypes = { "Pier" } },
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty targetlist
    it("should return empty for empty targetlist", function()
      local result = TargetingProcess.filterTargetsByTypeAndBase({}, {
        { baseName = "Hsinchu", subTypes = { "Runway" } },
      })

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty queryParams
    it("should return empty for empty queryParams", function()
      local targetlist = {
        makeTargetEntry({ guid = "t-001" }),
      }

      local result = TargetingProcess.filterTargetsByTypeAndBase(targetlist, {})

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- processTargets
  -- ============================================================================

  describe("processTargets", function()
    -- Positive: routes to dynamic processing when filterNames present
    it("should use dynamic processing when filterNames are present", function()
      local mockFilteredUnits = { { guid = "uav-001" } }
      local mockSide = {
        unitsBy = function() return mockFilteredUnits end,
      }
      trackStub(stub(GameApi, "VP_GetSide").returns(mockSide))
      trackStub(stub(Recon, "trackTarget").returns(true))

      local contact = makeContact({
        guid = "infantry-proc-001",
        typed = 8,
        inArea = function() return true end,
      })
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        filterNames = { "findInfantry" },
        areas = { { "area-1" } },
        contactAge = 300,
        minTargetCount = 1,
      }

      local result = TargetingProcess.processTargets(config, saveData, { contact }, targetConfig, false)

      assert.are.equal(1, #result)
    end)

    -- Positive: routes to fixed processing when no filterNames
    it("should use fixed processing when filterNames are absent", function()
      local saveData = makeSaveData({
        targetlist = {
          makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "proc-001" }),
        },
      })
      local target = makeContact({
        guid = "proc-001",
        type_description = "Runway (3000m)",
        actualunitid = "unit-001",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        embarkedUnits = { Aircraft = {} },
      }))

      local config = makeConfig()
      local targetConfig = {
        objs = { { baseName = "Hsinchu", subTypes = { "Runway" } } },
        contactAge = 300,
        minTargetCount = 1,
      }

      local result = TargetingProcess.processTargets(config, saveData, {}, targetConfig, false)

      assert.are.equal(1, #result)
    end)

    -- Negative: nil targetConfig
    it("should return empty when targetConfig is nil", function()
      local targetTemplate = {}
      local result = TargetingProcess.processTargets(makeConfig(), makeSaveData(), {}, targetTemplate, false)

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty filterNames falls through to fixed processing
    it("should use fixed processing when filterNames is empty table", function()
      local saveData = makeSaveData({
        targetlist = {
          makeTargetEntry({ name = "Hsinchu/Runway (3000m)", subType = "Runway (3000m)", guid = "proc-002" }),
        },
      })
      local target = makeContact({
        guid = "proc-002",
        type_description = "Runway (3000m)",
        actualunitid = "unit-002",
        BDA = { STRUCTURAL = "Light damage" },
        lastDetections = { { age = 100 } },
      })

      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        embarkedUnits = { Aircraft = {} },
      }))

      local config = makeConfig()
      local targetConfig = {
        filterNames = {},
        objs = { { baseName = "Hsinchu", subTypes = { "Runway" } } },
        contactAge = 300,
        minTargetCount = 1,
      }

      local result = TargetingProcess.processTargets(config, saveData, {}, targetConfig, false)

      assert.are.equal(1, #result)
    end)

    -- Positive: combines results from multiple dynamic filter functions
    it("should combine results from multiple dynamic filter functions", function()
      local infantryContact = makeContact({
        guid = "infantry-dyn-002",
        typed = 8,
        inArea = function() return true end,
      })
      local c2Contact = makeContact({
        guid = "c2-dyn-001",
        type_description = "ROCC Station",
        typed = 4,
        inArea = function() return true end,
      })
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        filterNames = { "findInfantry", "findC2" },
        areas = { { "area-1" } },
        contactAge = 300,
        minTargetCount = 1,
      }

      local result = TargetingProcess.processTargets(
        config, saveData, { infantryContact, c2Contact }, targetConfig, false
      )

      assert.are.equal(2, #result)
    end)

    -- Negative: unknown dynamic filter function
    it("should warn and skip unknown dynamic filter function names", function()
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        filterNames = { "nonExistentFilter" },
        areas = { { "area-1" } },
        contactAge = 300,
      }

      local result = TargetingProcess.processTargets(config, saveData, {}, targetConfig, false)

      assert.are.equal(0, #result)
      assert.stub(warnStub).was.called(1)
    end)

    -- Negative: fixed target objs is nil
    it("should return empty when fixed target objs is nil", function()
      local config = makeConfig()
      local saveData = makeSaveData()
      local targetConfig = {
        objs = nil,
        contactAge = 300,
      }

      local result = TargetingProcess.processTargets(config, saveData, {}, targetConfig, false)

      assert.are.equal(0, #result)
    end)

    -- Negative: no matching fixed targets
    it("should return empty when no fixed targets match query", function()
      local config = makeConfig()
      local saveData = makeSaveData({
        targetlist = {
          makeTargetEntry({ name = "Hsinchu/Shelter", subType = "Shelter", guid = "shelter-001" }),
        },
      })
      local targetConfig = {
        objs = { { baseName = "Hsinchu", subTypes = { "Runway" } } },
        contactAge = 300,
        minTargetCount = 1,
      }

      local result = TargetingProcess.processTargets(config, saveData, {}, targetConfig, false)

      assert.are.equal(0, #result)
    end)
  end)
end)
