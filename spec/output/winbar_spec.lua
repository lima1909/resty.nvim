describe("winbar:", function()
	local output = require("resty.output")
	local winbar = require("resty.output.winbar")
	local assert = require("luassert")

	local status = { is_ok = true, code = 200, text = "OK" }
	local duration = "1.0ms"

	local _, winnr = output._create_buf_with_win("")
	local w = winbar.new(winnr, {
		{ id = 1, name = "body" },
		{ id = 2, name = "headers" },
		{ id = 3, name = "info" },
		{ id = 4, name = "?" },
	}, status, duration)

	it("select first", function()
		local s = w:select(1)

		assert(s:find("StatusOK#200 OK%%*"))
		assert(s:find("ActiveWin#body"))
		assert(s:find("@info"))
	end)

	it("select second", function()
		local s = w:select(2)

		assert(s:find("StatusOK"))
		assert(s:find("ActiveWin#headers"))
		assert(s:find("@body"))
	end)

	it("invalid selection, no ActiveWin", function()
		local s = w:select(5)

		assert(s:find("StatusOK"))
		assert.is_nil(s:find("ActiveWin#"))
	end)

	it("status not ok", function()
		w.status_def = { code = 404, text = "Not Found" }
		local s = w:select(3)

		assert(s:find("StatusNotOK#404 Not Found%%*"))
		assert(s:find("ActiveWin#info"))
	end)
end)
