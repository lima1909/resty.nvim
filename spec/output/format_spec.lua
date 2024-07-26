local assert = require("luassert")
local format = require("resty.output.format")

describe("duration:", function()
	it("100.00 s", function()
		assert.are.same("100.00 s", format.duration(100))
	end)

	it("1.00 s", function()
		assert.are.same("1.00 s", format.duration(1))
	end)

	it("2.30 ms", function()
		assert.are.same("2.30 ms", format.duration(0.0023))
	end)

	it("2.30 µs", function()
		assert.are.same("2.30 µs", format.duration(0.0000023))
	end)

	it("2.30 ns", function()
		assert.are.same("2.30 ns", format.duration(0.0000000023))
	end)

	it("nil", function()
		assert.are.same("no time avialable", format.duration())
	end)
end)
