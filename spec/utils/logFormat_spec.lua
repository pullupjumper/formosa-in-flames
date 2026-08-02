-- LogFormat Unit Tests
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")

describe("LogFormat", function()
  -- ============================================================================
  -- fields
  -- ============================================================================

  describe("fields", function()
    -- Positive: emits known keys in canonical order regardless of table order
    it("should order known fields by canonical rank", function()
      local result = LogFormat.fields({
        reason = "add_unit_failed",
        unit = "TEL1",
        system = "srbm",
        role = "firing",
      })

      assert.are.equal("system=srbm unit=TEL1 role=firing reason=add_unit_failed", result)
    end)

    -- Positive: same field set always renders identically
    it("should render the same output for differently built tables", function()
      local first = LogFormat.fields({ guid = "G-1", system = "sam", unit = "TEL1" })
      local second = LogFormat.fields({ unit = "TEL1", guid = "G-1", system = "sam" })

      assert.are.equal(first, second)
    end)

    -- Positive: unknown keys sort alphabetically after known keys
    it("should append unknown fields alphabetically after known fields", function()
      local result = LogFormat.fields({ zulu = 1, alpha = 2, unit = "TEL1" })

      assert.are.equal("unit=TEL1 alpha=2 zulu=1", result)
    end)

    -- Boundary: outcome fields trail unknown keys, not just known ones
    it("should keep outcome fields after unknown fields", function()
      local result = LogFormat.fields({
        reason = "indivisible_tanker_unit_count",
        alpha = 1,
        package = 2,
      })

      assert.are.equal("package=2 alpha=1 reason=indivisible_tanker_unit_count", result)
    end)

    -- Positive: outcome fields always land at the end
    it("should place reason and detail last", function()
      local result = LogFormat.fields({
        detail = "boom",
        reason = "invalid_configuration",
        result = "failed",
        system = "srbm",
      })

      assert.are.equal("system=srbm result=failed reason=invalid_configuration detail=boom", result)
    end)

    -- Positive: values without separators stay unquoted
    it("should leave separator-free values unquoted", function()
      assert.are.equal("reason=add_unit_failed", LogFormat.fields({ reason = "add_unit_failed" }))
      assert.are.equal("firing=0/1", LogFormat.fields({ firing = "0/1" }))
      assert.are.equal("dbid=1234", LogFormat.fields({ dbid = 1234 }))
    end)

    -- Positive: values containing separators are quoted
    it("should quote values containing whitespace or separators", function()
      assert.are.equal("unit=\"Firing Unit Alpha\"", LogFormat.fields({ unit = "Firing Unit Alpha" }))
      assert.are.equal("detail=\"a=b\"", LogFormat.fields({ detail = "a=b" }))
    end)

    -- Positive: embedded quotes are escaped so the field stays parseable
    it("should escape embedded quotes", function()
      assert.are.equal("unit=\"say \\\"hi\\\"\"", LogFormat.fields({ unit = "say \"hi\"" }))
    end)

    -- Boundary: multi-line values collapse so summary line counting stays correct
    it("should collapse newlines into a single space", function()
      local result = LogFormat.fields({ detail = "line1\nline2" })

      assert.are.equal("detail=\"line1 line2\"", result)
      assert.is_nil(result:find("\n", 1, true))
    end)

    -- Boundary: empty string is quoted so the field remains visible
    it("should quote an empty string value", function()
      assert.are.equal("detail=\"\"", LogFormat.fields({ detail = "" }))
    end)

    -- Boundary: booleans render without quotes
    it("should render booleans unquoted", function()
      assert.are.equal("result=false", LogFormat.fields({ result = false }))
    end)

    -- Boundary: empty and nil inputs produce an empty string
    it("should return an empty string for empty input", function()
      assert.are.equal("", LogFormat.fields({}))
      assert.are.equal("", LogFormat.fields(nil))
    end)

    -- Positive: extraFields merge on top of the shared context table
    it("should merge extra fields over the base table", function()
      local context = { system = "srbm", role = "firing" }
      local result = LogFormat.fields(context, { role = "resupply", reason = "add_unit_failed" })

      assert.are.equal("system=srbm role=resupply reason=add_unit_failed", result)
    end)

    -- Negative: merging must not mutate the caller's shared context table
    it("should not mutate the base table when merging", function()
      local context = { system = "srbm", role = "firing" }
      LogFormat.fields(context, { role = "resupply" })

      assert.are.equal("firing", context.role)
      assert.is_nil(context.reason)
    end)
  end)

  -- ============================================================================
  -- line
  -- ============================================================================

  describe("line", function()
    -- Positive: tags are padded so field columns align across statuses
    it("should pad the tag to a fixed column", function()
      assert.are.equal("[OK]   unit=TEL1", LogFormat.line("OK", { unit = "TEL1" }))
      assert.are.equal("[SKIP] unit=TEL1", LogFormat.line("SKIP", { unit = "TEL1" }))
    end)

    -- Negative: a misspelled tag must not be counted as a success
    it("should downgrade an unknown tag to WARN", function()
      assert.are.equal("[WARN] unit=TEL1", LogFormat.line("SKIPPED", { unit = "TEL1" }))
    end)

    -- Boundary: a standalone event carries no report indent
    it("should not indent, unlike a report row", function()
      assert.are.equal("[OK]   side=China reason=none", LogFormat.line("OK", { side = "China", reason = "none" }))
    end)
  end)

  -- ============================================================================
  -- report
  -- ============================================================================

  describe("report", function()
    ---@type luassert.spy
    local logStub
    ---@type luassert.spy
    local errorStub

    before_each(function()
      logStub = stub(Logger, "log")
      errorStub = stub(Logger, "error")
    end)

    after_each(function()
      logStub:revert()
      errorStub:revert()
    end)

    -- Boundary: a report with nothing buffered must stay silent
    it("should emit nothing when no rows were added", function()
      LogFormat.report("AIR", "dynamicAirOperations", "Process operations").emit()

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was_not.called()
    end)

    -- Positive: the header carries the scope, action and non-zero counts only
    it("should emit a header with non-zero counts only", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("OK", { operation = "A" })
      report.add("SKIP", { operation = "B", reason = "no_valid_packages" })
      report.emit()

      assert.stub(logStub).was.called(1)
      assert.are.equal("AIR", logStub.calls[1].vals[1])
      assert.are.equal(
        "dynamicAirOperations: Process operations | total=2 ok=1 skip=1\n"
        .. "  [OK]   operation=A\n"
        .. "  [SKIP] operation=B reason=no_valid_packages",
        logStub.calls[1].vals[2]
      )
    end)

    -- Positive: FAIL and ERROR rows land on the error sink with their own header
    it("should route failures to the error sink", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("OK", { operation = "A" })
      report.add("ERROR", { operation = "B", reason = "missing_wave_template" })
      report.add("FAIL", { operation = "C", reason = "insertion_failed" })
      report.emit()

      assert.stub(logStub).was.called(1)
      assert.is_not_nil(logStub.calls[1].vals[2]:find("total=1 ok=1", 1, true))

      assert.stub(errorStub).was.called(1)
      local errorMessage = errorStub.calls[1].vals[1]
      assert.is_not_nil(errorMessage:find("total=2 fail=1 error=1", 1, true))
      assert.is_not_nil(errorMessage:find("reason=missing_wave_template", 1, true))
    end)

    -- Positive: detail rows nest under their parent instead of flattening
    it("should indent detail rows one level under their parent", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("SKIP", { operation = "B", reason = "no_valid_packages" }, {
        { tag = "SKIP", fields = { package = 1, reason = "insufficient_aircraft" } },
        { tag = "SKIP", fields = { package = 2, reason = "insufficient_aircraft" } },
      })
      report.emit()

      assert.are.equal(
        "dynamicAirOperations: Process operations | total=1 skip=1\n"
        .. "  [SKIP] operation=B reason=no_valid_packages\n"
        .. "    [SKIP] package=1 reason=insufficient_aircraft\n"
        .. "    [SKIP] package=2 reason=insufficient_aircraft",
        logStub.calls[1].vals[2]
      )
    end)

    -- Boundary: detail rows must not inflate the rollup that counts handled items
    it("should exclude detail rows from the rollup", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("OK", { operation = "A" }, {
        { tag = "SKIP", fields = { package = 1, reason = "insufficient_aircraft" } },
      })
      report.emit()

      assert.is_not_nil(logStub.calls[1].vals[2]:find("total=1 ok=1\n", 1, true))
      assert.is_nil(logStub.calls[1].vals[2]:find("skip=", 1, true))
    end)

    -- Boundary: details follow the parent's sink so the nesting stays readable
    it("should send detail rows to the parent's sink", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("FAIL", { operation = "C", reason = "insertion_failed" }, {
        { tag = "SKIP", fields = { package = 1, reason = "insufficient_aircraft" } },
      })
      report.emit()

      assert.stub(logStub).was_not.called()
      assert.is_not_nil(errorStub.calls[1].vals[1]:find("    [SKIP] package=1", 1, true))
    end)

    -- Positive: addAll preserves order and carries nested details through
    it("should append results in order via addAll", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.addAll({
        { tag = "OK", fields = { operation = "A" } },
        { tag = "OK", fields = { operation = "B" }, details = {
          { tag = "SKIP", fields = { package = 1 } },
        } },
      })
      report.emit()

      assert.are.equal(
        "dynamicAirOperations: Process operations | total=2 ok=2\n"
        .. "  [OK]   operation=A\n"
        .. "  [OK]   operation=B\n"
        .. "    [SKIP] package=1",
        logStub.calls[1].vals[2]
      )
    end)

    -- Boundary: producers pass optional result lists straight through
    it("should ignore a nil result list in addAll", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.addAll(nil)
      report.emit()

      assert.stub(logStub).was_not.called()
    end)

    -- Negative: a misspelled tag stays on the info log as WARN
    it("should count an unknown tag as WARN on the info log", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("SKIPPED", { operation = "A" })
      report.emit()

      assert.stub(errorStub).was_not.called()
      assert.is_not_nil(logStub.calls[1].vals[2]:find("total=1 warn=1", 1, true))
    end)

    -- Boundary: a row without fields still renders its tag
    it("should render a row with no fields", function()
      local report = LogFormat.report("AIR", "dynamicAirOperations", "Process operations")
      report.add("OK", nil)
      report.emit()

      assert.is_not_nil(logStub.calls[1].vals[2]:find("  [OK]  ", 1, true))
    end)
  end)
end)
