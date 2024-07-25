local assert = require("luassert")
local p = require("resty.parser")
local d = require("resty.parser.delimiter")

describe("find request:", function()
	local s, e, input

	it("empty", function()
		input = {}

		local ok, err = pcall(d.find_request, input, 1)
		assert.is_false(ok)
		assert.are.same("the selected row: 1 is greater then the given rows: 0", err)
	end)

	it("one", function()
		input = { "" }

		s, e = d.find_request(input, 1)
		assert.are.same(1, s)
		assert.are.same(1, e)
	end)

	it("one ###", function()
		input = { "###" }

		local ok, err = pcall(d.find_request, input, 1)
		assert.is_false(ok)
		assert.are.same("after the selected row: 1 are no more input lines", err)
	end)

	it("double ###", function()
		input = { "###", "###" }

		local ok, err = pcall(d.find_request, input, 1)
		assert.is_false(ok)
		assert.are.same("after the selected row: 1 are no more input lines", err)

		ok, err = pcall(d.find_request, input, 2)
		assert.is_false(ok)
		assert.are.same("after the selected row: 2 are no more input lines", err)
	end)

	it("without delimiter", function()
		input = { "@k=v", "", "GET http://host", "" }

		s, e = d.find_request(input, 2)
		assert.are.same(1, s)
		assert.are.same(4, e)
	end)

	it("with one delimiter on the start", function()
		input = { "###", "@key=value", "GET http://host" }

		s, e = d.find_request(input, 1)
		assert.are.same(2, s)
		assert.are.same(3, e)

		s, e = d.find_request(input, 2)
		assert.are.same(2, s)
		assert.are.same(3, e)

		s, e = d.find_request(input, 3)
		assert.are.same(2, s)
		assert.are.same(3, e)
	end)

	it("with one delimiter on the middle", function()
		input = { "GET http://host2", "", "###", "GET http://host" }

		s, e = d.find_request(input, 1)
		assert.are.same(1, s)
		assert.are.same(2, e)

		s, e = d.find_request(input, 2)
		assert.are.same(1, s)
		assert.are.same(2, e)

		s, e = d.find_request(input, 3)
		assert.are.same(4, s)
		assert.are.same(4, e)

		s, e = d.find_request(input, 4)
		assert.are.same(4, s)
		assert.are.same(4, e)
	end)

	it("with three delimiter", function()
		input = { "@key=value", "###", "GET http://host", "###", "GET http://host2", "###" }

		s, e = d.find_request(input, 1)
		assert.are.same(1, s)
		assert.are.same(1, e)

		s, e = d.find_request(input, 2)
		assert.are.same(3, s)
		assert.are.same(3, e)

		s, e = d.find_request(input, 3)
		assert.are.same(3, s)
		assert.are.same(3, e)

		s, e = d.find_request(input, 4)
		assert.are.same(5, s)
		assert.are.same(5, e)

		local ok, err = pcall(d.find_request, input, 6)
		assert.is_false(ok)
		assert.are.same("after the selected row: 6 are no more input lines", err)
	end)
end)
