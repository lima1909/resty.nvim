local assert = require("luassert")
local format = require("resty.output.format")

describe("duration:", function()
	it("100.00 ns", function()
		assert.are.same("100.00 ns", format.duration_to_str(100))
	end)

	it("1.00 ns", function()
		assert.are.same("1.00 ns", format.duration_to_str(1))
	end)

	it("2.30 ms", function()
		assert.are.same("2.30 ms", format.duration_to_str(2.3 * 1000 * 1000))
	end)

	it("2.30 µs", function()
		assert.are.same("2.30 µs", format.duration_to_str(2.3 * 1000))
	end)

	it("2.30 ns", function()
		assert.are.same("2.30 ns", format.duration_to_str(2.3))
	end)

	it("2.30 s", function()
		assert.are.same("2.30 s", format.duration_to_str(2.3 * 1000 * 1000 * 1000))
	end)

	it("nil", function()
		assert.are.same("no time avialable", format.duration_to_str())
	end)
end)
