local assert = require("luassert")
local p = require("resty.parser")
-- local result = require("resty.parser.result")

describe("valid variable row:", function()
	it("only variable", function()
		local r = p.parse({
			"@a=b",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(2))
	end)

	it("global variable", function()
		local r = p.parse({
			"@a=b",
			"",
			"@c=d",
			"###",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_true(r:is_valid_variable_row(2))
		assert.is_true(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(0))
		assert.is_false(r:is_valid_variable_row(4))
	end)

	it("variable before request", function()
		local r = p.parse({
			"@a=b",
			"",
			"@c=d",
			"GET http://host",
		}, 1)

		assert.is_true(r:is_valid_variable_row(1))
		assert.is_true(r:is_valid_variable_row(2))
		assert.is_true(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(0))

		assert.is_false(r:is_valid_variable_row(4))
		assert.is_false(r:is_valid_variable_row(5))

		assert.is_false(r:is_valid_variable_row(10))
	end)

	it("local variables", function()
		local r = p.parse({
			"@a=b",
			"",
			"###",
			"",
			"@c=d",
			"@x=y",
			"",
			"GET http://host",
		}, 3)

		assert.is_true(r:is_valid_variable_row(4))
		assert.is_true(r:is_valid_variable_row(5))
		assert.is_true(r:is_valid_variable_row(6))
		assert.is_true(r:is_valid_variable_row(7))

		assert.is_false(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(2))
		assert.is_false(r:is_valid_variable_row(3))

		assert.is_false(r:is_valid_variable_row(8))
	end)

	it("local variables invalid after headers", function()
		local r = p.parse({
			"###",
			"@c=d",
			"GET http://host",
			"Accept: application/json",
			"",
		}, 3)

		assert.is_true(r:is_valid_variable_row(2))

		assert.is_false(r:is_valid_variable_row(1))
		assert.is_false(r:is_valid_variable_row(3))
		assert.is_false(r:is_valid_variable_row(4))
		assert.is_false(r:is_valid_variable_row(5))
	end)
end)

describe("valid headers row:", function()
	it("no request", function()
		local r = p.parse({
			"",
		}, 1)

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)

	it("header after request", function()
		local r = p.parse({
			"GET http://host",
			"",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(1))
	end)

	it("header after request, with existing headers", function()
		local r = p.parse({
			"GET http://host",
			"Accept: application/json",
			"",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))
		assert.is_true(r:is_valid_headers_row(3))

		assert.is_false(r:is_valid_headers_row(1))
	end)

	it("header before body", function()
		local r = p.parse({
			"GET http://host",
			"",
			"{}",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)

	it("header before script", function()
		local r = p.parse({
			"GET http://host",
			"",
			"--{%",
			"--%}",
		}, 1)

		assert.is_true(r:is_valid_headers_row(2))

		assert.is_false(r:is_valid_headers_row(0))
		assert.is_false(r:is_valid_headers_row(1))
		assert.is_false(r:is_valid_headers_row(3))
	end)
end)
