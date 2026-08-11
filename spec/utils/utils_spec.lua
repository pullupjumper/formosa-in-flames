-- Utils Unit Tests
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("Utils", function()
  -- ============================================================================
  -- parseDatetimeToTimestamp
  -- ============================================================================

  describe("parseDatetimeToTimestamp", function()
    -- Every expectation below is a hardcoded UTC epoch, never a re-derivation of
    -- the implementation. That is what makes these fail on a non-UTC+8 machine
    -- if the local-offset compensation regresses.

    -- Positive: a known UTC datetime resolves to its exact epoch
    it("should convert a UTC datetime string to its epoch", function()
      assert.are.equal(1771027200, Utils.parseDatetimeToTimestamp("2026-02-14 00:00:00"))
    end)

    -- Positive: a date in northern-hemisphere summer resolves identically
    it("should convert a summer datetime without a daylight-saving shift", function()
      assert.are.equal(1784032245, Utils.parseDatetimeToTimestamp("2026-07-14 12:30:45"))
    end)

    -- Positive: parsing is the inverse of formatting with the project's own constant
    it("should round-trip a timestamp formatted with DATE_FORMAT", function()
      local timestamp = 1812502800
      local formatted = os.date(constants.DATE_FORMAT, timestamp) --[[@as string]]

      assert.are.equal(timestamp, Utils.parseDatetimeToTimestamp(formatted))
    end)

    -- Positive: CMO mission strings carry a trailing format hint that must be ignored
    it("should ignore the trailing CMO time format suffix", function()
      local withSuffix = "2026-02-14 00:00:00" .. constants.TIME_FORMATS

      assert.are.equal(1771027200, Utils.parseDatetimeToTimestamp(withSuffix))
    end)

    -- Boundary: first second of a year
    -- Dates are kept inside the scenario's own era. Pre-1972 inputs would trip
    -- historical timezone rules (Britain ran year-round DST from 1968 to 1971)
    -- that this function will never legitimately see.
    it("should convert the first second of a year", function()
      assert.are.equal(1767225600, Utils.parseDatetimeToTimestamp("2026-01-01 00:00:00"))
    end)

    -- Boundary: last second before a year rollover
    it("should convert the final second of a year", function()
      assert.are.equal(1798761599, Utils.parseDatetimeToTimestamp("2026-12-31 23:59:59"))
    end)

    -- Boundary: two datetimes one hour apart differ by exactly one hour
    it("should preserve the interval between two datetimes", function()
      local earlier = Utils.parseDatetimeToTimestamp("2026-02-14 00:00:00")
      local later = Utils.parseDatetimeToTimestamp("2026-02-14 01:00:00")

      assert.are.equal(3600, later - earlier)
    end)

    -- Negative: a string with no datetime component
    it("should raise an error for a malformed datetime string", function()
      assert.has_error(function()
        Utils.parseDatetimeToTimestamp("not a datetime")
      end)
    end)

    -- Negative: a date-only string is missing the time component
    it("should raise an error when the time component is absent", function()
      assert.has_error(function()
        Utils.parseDatetimeToTimestamp("2026-02-14")
      end)
    end)
  end)
end)
