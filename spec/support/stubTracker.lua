-- Shared stub bookkeeping for specs: register each stub, revert them all in after_each
local StubTracker = {}

---@type luassert.spy[]
local activeStubs = {}

---Register a stub so revertAll can undo it
---@generic T
---@param s T
---@return T
function StubTracker.track(s)
  table.insert(activeStubs, s)
  return s
end

---Revert every registered stub, newest first
function StubTracker.revertAll()
  for i = #activeStubs, 1, -1 do
    activeStubs[i]:revert()
  end
  activeStubs = {}
end

return StubTracker
