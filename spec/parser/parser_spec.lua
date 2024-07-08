local assert = require("luassert")
local p = require("resty.parser2")
local d = require("resty.parser2.delimiter")

describe("find request definition:", function()
	local s, e, input

	it("without delimiter", function()
		input = { "@k=v", "", "GET http://host", "" }
		s, e = d.find_req_def(input, 2)
		assert.are.same(1, s)
		assert.are.same(4, e)
	end)

	it("with one delimiter on the start", function()
		input = { "###", "@key=value", "GET http://host" }
		s, e = d.find_req_def(input, 1)
		assert.are.same(1, s)
		assert.are.same(3, e)

		s, e = d.find_req_def(input, 2)
		assert.are.same(1, s)
		assert.are.same(3, e)

		s, e = d.find_req_def(input, 3)
		assert.are.same(1, s)
		assert.are.same(3, e)
	end)

	it("with one delimiter on the middle", function()
		input = { "GET http://host2", "", "###", "GET http://host" }
		s, e = d.find_req_def(input, 1)
		assert.are.same(1, s)
		assert.are.same(2, e)

		s, e = d.find_req_def(input, 2)
		assert.are.same(1, s)
		assert.are.same(2, e)

		s, e = d.find_req_def(input, 3)
		assert.are.same(3, s)
		assert.are.same(4, e)

		s, e = d.find_req_def(input, 4)
		assert.are.same(3, s)
		assert.are.same(4, e)
	end)

	it("selected row before delimiter", function()
		local parser = p.new()
		parser.lines = { "@k=v", " ", "###", "@key=value", "GET http://host" }
		parser.selected = 2
		parser.readed_lines = 3

		d.parse_delimiter(parser, "###")
		assert.are.same("the selected row: 2 is not in a request definition", parser.errors[1].message)
	end)

	it("with before and one delimiter", function()
		input = { "@k=v", " ", "###", "@key=value", "GET http://host" }
		-- find the global variables. this is not desired, but the find function can not distinguish
		s, e = d.find_req_def(input, 2)
		assert.are.same(1, s)
		assert.are.same(2, e)

		s, e = d.find_req_def(input, 3)
		assert.are.same(3, s)
		assert.are.same(5, e)

		s, e = d.find_req_def(input, 4)
		assert.are.same(3, s)
		assert.are.same(5, e)
	end)

	it("with two delimiter", function()
		input = { "###", "@key=value", "GET http://host", "###", "GET http://host2" }
		s, e = d.find_req_def(input, 4)
		assert.are.same(4, s)
		assert.are.same(5, e)

		s, e = d.find_req_def(input, 5)
		assert.are.same(4, s)
		assert.are.same(5, e)
	end)

	it("with two delimiter", function()
		input = { "@key=value", "###", "@key2=value2", "GET http://host" }
		s, e = d.find_req_def(input, 2)
		assert.are.same(2, s)
		assert.are.same(4, e)

		s, e = d.find_req_def(input, 4)
		assert.are.same(2, s)
		assert.are.same(4, e)
	end)

	it("with three delimiter", function()
		input = { "@key=value", "###", "GET http://host", "###", "GET http://host2", "###" }
		s, e = d.find_req_def(input, 2)
		assert.are.same(2, s)
		assert.are.same(3, e)

		s, e = d.find_req_def(input, 4)
		assert.are.same(4, s)
		assert.are.same(5, e)

		s, e = d.find_req_def(input, 6)
		assert.are.same(6, s)
		assert.are.same(6, e)
	end)
end)

describe("parser:", function()
	local function check(input, selected, expected)
		local r = p.new():parse(input, selected)

		assert.is_false(r:has_errors(), vim.inspect(r.errors), "has error")
		assert.are.same(r.readed_lines, expected.readed_lines, "compare readed_lines")
		assert.are.same(r.global_variables, expected.global_variables, "compare global_variables")
		assert.are.same(r.current_state, expected.state, "compare state")
		assert.are.same(r.request, expected.request or {}, "compare request")
	end

	it("method url", function()
		check("GET http://host", 1, {
			readed_lines = 1,
			global_variables = {},
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("one variable and method url", function()
		check({ "@key=value", "###", "GET http://host" }, 3, {
			readed_lines = 3,
			global_variables = { key = "value" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("two variables and method url", function()
		check({ "@key1=value1", " ", "# comment", "", "@key2=value2", "###", "GET http://host" }, 6, {
			readed_lines = 7,
			global_variables = { key1 = "value1", key2 = "value2" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and method url", function()
		check("###\nGET http://host", 1, {
			readed_lines = 2,
			global_variables = {},
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and one variable and method url", function()
		check({ "###", "@key=value", "# comment", "GET http://host" }, 2, {
			readed_lines = 4,
			global_variables = { key = "value" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and two variable and method url", function()
		check({ "@key=value", "# comment", "###", "@key2=value2", "GET http://host" }, 3, {
			readed_lines = 5,
			global_variables = { key = "value", key2 = "value2" },
			state = p.STATE_METHOD_URL,
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url and header", function()
		check({ "GET http://host", "", "accept: application/json", "" }, 4, {
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

	it("one variable and method url and header", function()
		check({ "@key=value", "###", "GET http://host", "", "accept: application/json", "" }, 4, {
			readed_lines = 6,
			global_variables = { key = "value" },
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
		check({ "GET http://host", "", "id=42", "" }, 2, {
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
		check({ "GET http://host", "", "accept: application/json", "", "id=42" }, 1, {
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
		check({ "GET http://host", "  ", "{", "\t'name': 'John'", "}" }, 1, {
			readed_lines = 5,
			global_variables = {},
			state = p.STATE_BODY,
			request = { method = "GET", url = "http://host", body = { "{", "\t'name': 'John'", "}" } },
		})
	end)

	it("method url and header query with body", function()
		check(
			{ "GET http://host", "", "accept: application/json", "", "id=42", "  ", "{", "\t'name': 'John'", "}" },
			9,
			{
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
			}
		)
	end)

	it("second method url and header query with body", function()
		check(
			{
				"@k=v",
				"###",
				"GET http://host",
				"###",
				"GET http://host",
				"",
				"accept: application/json",
				"",
				"id=42",
				"  ",
				"{",
				"\t'name': 'John'",
				"}",
			},
			9,
			{
				readed_lines = 13,
				global_variables = { k = "v" },
				state = p.STATE_BODY,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = { ["id"] = "42" },
					body = { "{", "\t'name': 'John'", "}" },
				},
			}
		)
	end)

	it("first method url and header query with body", function()
		check(
			{
				"@k=v",
				"###",
				"GET http://host",
				"accept: application/json",
				"###",
				"GET http://host",
			},
			3,
			{
				readed_lines = 4,
				global_variables = { k = "v" },
				state = p.STATE_HEADERS_QUERY,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = {},
				},
			}
		)
	end)
end)

describe("errors:", function()
	local function check(input, selected, expected)
		local r = p.new():parse(input, selected)

		assert.is_true(r:has_errors())
		local err = r.errors[1]
		assert.are.same(expected.message, err.message)
		assert.are.same(expected.lnum, err.lnum)
		assert.are.same(expected.current_state, r.current_state)
	end

	it("empty", function()
		check("", 1, { message = "a valid request expect at least a url", lnum = 1, current_state = p.STATE_START })
	end)

	it("only comment", function()
		check(
			"# comment",
			1,
			{ message = "a valid request expect at least a url", lnum = 1, current_state = p.STATE_START }
		)
	end)

	it("only one variable", function()
		check(
			"@key=value",
			1,
			{ message = "a valid request expect at least a url", lnum = 1, current_state = p.STATE_GLOBAL_VARIABLE }
		)
	end)

	it("only one variable and delimiter", function()
		check("@key=value\n###", 1, {
			message = "the selected row: 1 is not in a request definition",
			lnum = 2,
			current_state = p.STATE_DELIMITER,
		})
	end)

	--Note: invalid status transition, not implemented yet
	-- it("only one variable and method and url", function()
	-- 	check({ "@key=value", "GET http://host" }, 2, {
	-- 		message = "the selected row: 1 is not in a request definition",
	-- 		lnum = 2,
	-- 		current_state = p.STATE_DELIMITER,
	-- 	})
	-- end)

	it("only delimiter", function()
		check("###", 1, {
			message = "a valid request expect at least a url",
			lnum = 1,
			current_state = p.STATE_DELIMITER,
		})
	end)

	it("with variable", function()
		check(
			"@key=",
			1,
			{ message = "an empty value is not allowed", lnum = 1, current_state = p.STATE_GLOBAL_VARIABLE }
		)
	end)

	it("wrong selection", function()
		check("GET http://host", 2, {
			message = "the selected row: 2 is greater then the given rows: 1",
			lnum = 0,
			current_state = p.STATE_START,
		})
	end)

	it("selected in global variable", function()
		check({ "@key=value", " ", "###", "GET http://host" }, 2, {
			message = "the selected row: 2 is not in a request definition",
			lnum = 3,
			current_state = p.STATE_METHOD_URL,
		})
	end)
end)
