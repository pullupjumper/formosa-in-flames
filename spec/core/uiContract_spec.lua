describe("UI contract", function()
  it("should keep htmls-app/src/types/generated.ts in step with schema.lua", function()
    local pipe = assert(io.popen("python3 tools/gen_ui_types.py --check 2>&1; echo \"exit=$?\""))
    local output = pipe:read("*a")
    pipe:close()

    local message, code = output:match("^(.-)exit=(%d+)%s*$")

    assert.are.same({ code = "0", message = "" }, { code = code, message = message })
  end)
end)
