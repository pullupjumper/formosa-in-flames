-- PersistentState Unit Tests
local PersistentState = require("src.core.persistentState")
local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")

describe("PersistentState", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local loadStub
  ---@type luassert.spy
  local saveStub
  ---@type luassert.spy
  local errorStub
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    errorStub = trackStub(stub(Logger, "error"))
    loadStub = trackStub(stub(gKH.State, "LoadTableFromKey"))
    saveStub = trackStub(stub(gKH.State, "SaveTableToKey"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- update
  -- ============================================================================

  describe("update", function()
    -- Positive: the table fn mutated is the one written back under the same key
    it("should save the mutated state back to the SaveData key", function()
      local state = { c = { counter = 1 } }
      loadStub.returns(state)

      local ran = PersistentState.update(function(s)
        s.c.counter = 2
      end)

      assert.is_true(ran)
      assert.are.equal(2, state.c.counter)
      assert.stub(loadStub).was.called_with("SaveData")
      assert.stub(saveStub).was.called_with(state, "SaveData")
    end)

    -- Negative: nothing saved means nothing to run against; must not overwrite the key
    it("should skip fn and save when no state is stored", function()
      loadStub.returns(nil)
      local fn = spy.new(function() end)

      local ran = PersistentState.update(fn)

      assert.is_false(ran)
      assert.spy(fn).was_not.called()
      assert.stub(saveStub).was_not.called()
      assert.stub(errorStub).was.called()
    end)

    -- Boundary: a failing fn must not persist a half-applied mutation
    it("should not save when fn raises", function()
      loadStub.returns({})

      assert.has_error(function()
        PersistentState.update(function() error("boom") end)
      end)

      assert.stub(saveStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- reset
  -- ============================================================================

  describe("reset", function()
    -- Positive: defaults replace whatever is stored, without loading first
    it("should write defaults to the SaveData key", function()
      local defaults = { c = { targetlist = {} } }

      PersistentState.reset(defaults)

      assert.stub(saveStub).was.called_with(defaults, "SaveData")
      assert.stub(loadStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- read
  -- ============================================================================

  describe("read", function()
    -- Positive: fn sees the loaded state and nothing is written
    it("should run fn with the loaded state without saving", function()
      local state = { c = {} }
      loadStub.returns(state)
      local fn = spy.new(function() end)

      local ran = PersistentState.read(fn)

      assert.is_true(ran)
      assert.spy(fn).was.called_with(state)
      assert.stub(saveStub).was_not.called()
    end)

    -- Negative: no stored state means fn is skipped
    it("should skip fn when no state is stored", function()
      loadStub.returns(nil)
      local fn = spy.new(function() end)

      local ran = PersistentState.read(fn)

      assert.is_false(ran)
      assert.spy(fn).was_not.called()
      assert.stub(errorStub).was.called()
    end)
  end)
end)
