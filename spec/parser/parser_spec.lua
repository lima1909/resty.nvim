local assert = require("luassert")
local p = require("resty.parser")
local body = require("resty.parser.body")

describe("parser:", function()
	local function check(input, selected, expected)
		local r = p.parse(input, selected)

		assert.is_false(r:has_errors(), vim.inspect(r.errors), "has error")
		assert.are.same(r.readed_lines, expected.readed_lines, "compare readed_lines")
		assert.are.same(r.variables, expected.variables, "compare global_variables")
		assert.are.same(r.current_state.id, expected.state, "compare state")
		assert.are.same(r.request, expected.request or {}, "compare request")
		assert.are.same(r.script, expected.script, "compare script")
	end

	it("method url", function()
		check("GET http://host", 1, {
			readed_lines = 1,
			variables = {},
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("only one variable and method and url", function()
		check({ "@key=value", "GET http://host" }, 0, {
			readed_lines = 2,
			variables = { key = "value" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("method url with comment in the same line", function()
		check("GET http://host # with comment in the same line", 1, {
			readed_lines = 1,
			variables = {},
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("method url with variable", function()
		check({ "@host=my-host", "###", "GET http://{{host}}" }, 3, {
			readed_lines = 3,
			variables = { host = "my-host" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://my-host", headers = {}, query = {} },
		})
	end)

	it("one variable and method url", function()
		check({ "@key=value", "###", "GET http://host" }, 3, {
			readed_lines = 3,
			variables = { key = "value" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("two variables and method url", function()
		check({ "@key1=value1 #comment", " ", "# comment", "", "@key2=value2", "###", "GET http://host" }, 6, {
			readed_lines = 7,
			variables = { key1 = "value1", key2 = "value2" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("delimiter and method url", function()
		check("###\nGET http://host", 1, {
			readed_lines = 2,
			variables = {},
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("delimiter and one variable and method url", function()
		check({ "###", "@key=value", "# comment", "GET http://host" }, 2, {
			readed_lines = 4,
			variables = { key = "value" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("delimiter and two variable and method url", function()
		check({ "@key=value", "# comment", "###", "@key2=value2", "GET http://host" }, 3, {
			readed_lines = 5,
			variables = { key = "value", key2 = "value2" },
			state = p.STATE_METHOD_URL.id,
			request = { method = "GET", url = "http://host", headers = {}, query = {} },
		})
	end)

	it("method url and header", function()
		check({ "GET http://host", "", "accept: application/json # comment", "" }, 4, {
			readed_lines = 4,
			variables = {},
			state = p.STATE_HEADERS_QUERY.id,
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
			variables = { key = "value" },
			state = p.STATE_HEADERS_QUERY.id,
			request = {
				method = "GET",
				url = "http://host",
				headers = { ["accept"] = "application/json" },
				query = {},
			},
		})
	end)

	it("method url and query", function()
		check({ "GET http://host", "", "id=42# comment", "" }, 2, {
			readed_lines = 4,
			variables = {},
			state = p.STATE_HEADERS_QUERY.id,
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
			variables = {},
			state = p.STATE_HEADERS_QUERY.id,
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
			variables = {},
			state = p.STATE_BODY.id,
			request = {
				method = "GET",
				url = "http://host",
				headers = {},
				query = {},
				body = "{\n\t'name': 'John'\n}\n",
			},
		})
	end)

	it("method url and header query with body", function()
		check(
			{ "GET http://host", "", "accept: application/json", "", "id=42", "  ", "{", "\t'name': 'John'", "}" },
			9,
			{
				readed_lines = 9,
				variables = {},
				state = p.STATE_BODY.id,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = { ["id"] = "42" },
					body = "{\n\t'name': 'John'\n}\n",
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
				variables = { k = "v" },
				state = p.STATE_BODY.id,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = { ["id"] = "42" },
					body = "{\n\t'name': 'John'\n}\n",
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
				variables = { k = "v" },
				state = p.STATE_HEADERS_QUERY.id,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = {},
				},
			}
		)
	end)

	it("replace variable from environment variable", function()
		check(
			{
				"GET http://host",
				"accept: application/json",
				"",
				"user={{$user}}",
			},
			1,
			{
				readed_lines = 4,
				variables = {},
				state = p.STATE_HEADERS_QUERY.id,
				request = {
					method = "GET",
					url = "http://host",
					headers = { ["accept"] = "application/json" },
					query = { ["user"] = os.getenv("USER") },
				},
			}
		)
	end)

	it("replace variable from variable from environment variable", function()
		check(
			{
				"@host=$USER",
				"GET http://{{host}}",
			},
			1,
			{
				readed_lines = 2,
				variables = { ["host"] = "$USER" },
				state = p.STATE_METHOD_URL.id,
				request = {
					method = "GET",
					url = "http://" .. os.getenv("USER"),
					headers = {},
					query = {},
				},
			}
		)
	end)

	it("replace variable from command", function()
		check(
			{
				"GET http://{{> echo 'echo-host'}}",
				"accept: application/json",
				"",
				"cmd={{>echo 'my output'}}",
			},
			1,
			{
				readed_lines = 4,
				variables = {},
				state = p.STATE_HEADERS_QUERY.id,
				request = {
					method = "GET",
					url = "http://echo-host",
					headers = { ["accept"] = "application/json" },
					query = { ["cmd"] = "my output" },
				},
			}
		)
	end)

	it("replace variable from variable from command", function()
		check(
			{
				"@host = >echo 'my-host-from-var'",
				"GET http://{{host}}",
			},
			1,
			{
				readed_lines = 2,
				variables = { ["host"] = ">echo 'my-host-from-var'" },
				state = p.STATE_METHOD_URL.id,
				request = {
					method = "GET",
					url = "http://my-host-from-var",
					headers = {},
					query = {},
				},
			}
		)
	end)

	it("method url with script", function()
		check({ "GET http://host", "  ", body.script.open, "-- comment", body.script.close }, 1, {
			readed_lines = 5,
			variables = {},
			state = p.STATE_SCRIPT.id,
			request = {
				method = "GET",
				url = "http://host",
				headers = {},
				query = {},
			},
			script = body.script.open .. "\n-- comment\n" .. body.script.close .. "\n",
		})
	end)

	it("method url with script and body", function()
		check(
			{
				"GET http://host",
				"",
				"{",
				"\t'name': 'John'",
				"}",
				"",
				body.script.open,
				"print('Hey ...')",
				body.script.close,
			},
			1,
			{
				readed_lines = 9,
				variables = {},
				state = p.STATE_SCRIPT.id,
				request = {
					method = "GET",
					url = "http://host",
					body = "{\n\t'name': 'John'\n}\n",
					headers = {},
					query = {},
				},
				script = body.script.open .. "\nprint('Hey ...')\n" .. body.script.close .. "\n",
			}
		)
	end)

	it("method url with body and script ", function()
		check(
			{
				"GET http://host",
				"accept: application/json",
				"",
				body.script.open,
				"print('Hey ...')",
				body.script.close,
				"",
				"{",
				"\t'name': 'John'",
				"}",
			},
			1,
			{
				readed_lines = 10,
				variables = {},
				state = p.STATE_BODY.id,
				request = {
					method = "GET",
					url = "http://host",
					body = "{\n\t'name': 'John'\n}\n",
					headers = { ["accept"] = "application/json" },
					query = {},
				},
				script = body.script.open .. "\nprint('Hey ...')\n" .. body.script.close .. "\n",
			}
		)
	end)
end)

describe("errors:", function()
	local function check(input, selected, expected)
		local r = p.parse(input, selected)

		assert.is_true(r:has_errors())
		local err = r.errors[1]
		assert.are.same(expected.message, err.message)
		assert.are.same(expected.lnum, err.lnum)
		assert.are.same(expected.current_state, r.current_state.id)
	end

	it("empty", function()
		check("", 1, {
			message = "a valid request expect at least a url (parse rows: 1:1)",
			lnum = 0,
			current_state = p.STATE_START.id,
		})
	end)

	it("only comment", function()
		check("# comment", 1, {
			message = "a valid request expect at least a url (parse rows: 1:1)",
			lnum = 0,
			current_state = p.STATE_START.id,
		})
	end)

	it("only one variable", function()
		check("@key=value", 1, {
			message = "a valid request expect at least a url (parse rows: 1:1)",
			lnum = 0,
			current_state = p.STATE_VARIABLE.id,
		})
	end)

	it("only one variable and delimiter", function()
		check("@key=value\n###", 1, {
			message = "a valid request expect at least a url (parse rows: 1:1)",
			lnum = 0,
			current_state = p.STATE_VARIABLE.id,
		})
	end)

	it("only delimiter", function()
		check("###", 1, {
			message = "after the selected row: 1 are no more input lines",
			lnum = 0,
			current_state = p.STATE_START.id,
		})
	end)

	it("with variable", function()
		check("@key=", 1, { message = "an empty value is not allowed", lnum = 0, current_state = p.STATE_VARIABLE.id })
	end)

	it("wrong selection", function()
		check("GET http://host", 2, {
			message = "the selected row: 2 is greater then the given rows: 1",
			lnum = 0,
			current_state = p.STATE_START.id,
		})
	end)

	it("selected in global variable", function()
		check({ "@key=value", " ", "###", "GET http://host" }, 2, {
			message = "a valid request expect at least a url (parse rows: 1:2)",
			lnum = 1,
			current_state = p.STATE_VARIABLE.id,
		})
	end)

	it("invalid transition, is not a method", function()
		check({ "@key=value", "accept: application/json" }, 2, {
			message = "invalid method name: 'accept:'. Only letters are allowed",
			lnum = 1,
			current_state = p.STATE_METHOD_URL.id,
		})
	end)

	it("invalid transition", function()
		check({ "@key=value", "GET http://host", "{", "}", "@key2=value2" }, 2, {
			message = "from current state: 'body' are only possible state(s): body, script",
			lnum = 4,
			current_state = p.STATE_BODY.id,
		})
	end)
end)
