describe("winbar:", function()
	local output = require("resty.output").new({})
	local winbar = require("resty.output.winbar")
	local assert = require("luassert")

	local status = { is_ok = true, code = 200, text = "OK" }
	local duration = "1.0ms"

	local w = winbar.new(output:activate())

	it("select first", function()
		local s = w:select(1, status, duration)

		assert(s:find("StatusOK#200 OK%%*"))
		assert(s:find("ActiveWin#body"))
		assert(s:find("@info"))
	end)

	it("select second", function()
		local s = w:select(2, status, duration)

		assert(s:find("StatusOK"))
		assert(s:find("ActiveWin#headers"))
		assert(s:find("@body"))
	end)

	it("invalid selection, no ActiveWin", function()
		local s = w:select(5, status, duration)

		assert(s:find("StatusOK"))
		assert.is_nil(s:find("ActiveWin#"))
	end)

	it("status not ok", function()
		status = { code = 404, text = "Not Found" }
		local s = w:select(3, status, duration)

		assert(s:find("StatusNotOK#404 Not Found%%*"))
		assert(s:find("ActiveWin#info"))
	end)
end)
