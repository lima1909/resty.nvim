local assert = require("luassert")
local p = require("resty.parser2")

describe("parser:", function()
	local function check(input, expected)
		local r = p.new():parse(input, 1)

		assert.is_false(r:has_errors())
		assert.are.same(r.readed_lines, expected.readed_lines)
		assert.are.same(r.global_variables, expected.global_variables)
		assert.are.same(r.current_state, expected.state)
		assert.are.same(r.request, expected.request or {})
	end

	it("method url", function()
		check("GET http://host", {
			readed_lines = 1,
			global_variables = {},
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("one variable and method url", function()
		check("@key=value\nGET http://host", {
			readed_lines = 2,
			global_variables = { key = "value" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("two variables and method url", function()
		check({ "@key1=value1", "@key2=value2", "GET http://host" }, {
			readed_lines = 3,
			global_variables = { key1 = "value1", key2 = "value2" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and method url", function()
		check("###\nGET http://host", {
			readed_lines = 2,
			global_variables = {},
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and one variable and method url", function()
		check({ "###", "@key=value", "GET http://host" }, {
			readed_lines = 3,
			global_variables = { key = "value" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and two variable and method url", function()
		check("@key=value\n###\n@key2=value2\nGET http://host", {
			readed_lines = 4,
			global_variables = { key = "value", key2 = "value2" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url and header", function()
		check({ "GET http://host", "", "accept: application/json", "" }, {
			readed_lines = 4,
			global_variables = {},
			state = p.STATE_HEADERS_QUERY,
			request = {
				method = "GET",
				url = "http://host",
				headers = { ["accept"] = "application/json" },
				query = {},
			},
		})
	end)

	it("method url and query", function()
		check({ "GET http://host", "", "id=42", "" }, {
			readed_lines = 4,
			global_variables = {},
			state = p.STATE_HEADERS_QUERY,
			request = {
				method = "GET",
				url = "http://host",
				headers = {},
				query = { ["id"] = "42" },
			},
		})
	end)

	it("method url and header query", function()
		check({ "GET http://host", "", "accept: application/json", "", "id=42" }, {
			readed_lines = 5,
			global_variables = {},
			state = p.STATE_HEADERS_QUERY,
			request = {
				method = "GET",
				url = "http://host",
				headers = { ["accept"] = "application/json" },
				query = { ["id"] = "42" },
			},
		})
	end)

	it("method url with body", function()
		check({ "GET http://host", "  ", "{", "\t'name': 'John'", "}" }, {
			readed_lines = 5,
			global_variables = {},
			state = p.STATE_BODY,
			request = { method = "GET", url = "http://host", body = { "{", "\t'name': 'John'", "}" } },
		})
	end)

	it("method url and header query with body", function()
		check({ "GET http://host", "", "accept: application/json", "", "id=42", "  ", "{", "\t'name': 'John'", "}" }, {
			readed_lines = 9,
			global_variables = {},
			state = p.STATE_BODY,
			request = {
				method = "GET",
				url = "http://host",
				headers = { ["accept"] = "application/json" },
				query = { ["id"] = "42" },
				body = { "{", "\t'name': 'John'", "}" },
			},
		})
	end)
end)

describe("errors:", function()
	local function check(input, expected)
		local r = p.new():parse(input, 1)

		assert.is_true(r:has_errors())
		local err = r.errors[1]
		assert.are.same(expected.message, err.message)
		assert.are.same(expected.lnum, err.lnum)
		assert.are.same(expected.current_state, r.current_state)
	end

	it("only comment", function()
		check(
			"# comment",
			{ message = "a valid request expect at least a url", lnum = 1, current_state = p.STATE_START }
		)
	end)

	it("only one variable", function()
		check(
			"@key=value",
			{ message = "a valid request expect at least a url", lnum = 1, current_state = p.STATE_VARIABLE }
		)
	end)

	it("with variable", function()
		check("@key=", { message = "an empty value is not allowed", lnum = 1, current_state = p.STATE_VARIABLE })
	end)
end)
