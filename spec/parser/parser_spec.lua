local assert = require("luassert")
local p = require("resty.parser")

local function check(input, selected, expected)
	local r = p.parse(input, selected)

	if r:has_error() then
		print(vim.inspect(r))
	end
	assert.is_false(r:has_error())
	assert.are.same(r.variables, expected.variables)
	assert.are.same(r.request, expected.request or {})
	assert.are.same(r.script, expected.script)
end

describe("parser:", function()
	it("method url", function()
		check("GEt http://host", 1, {
			variables = {},
			request = { method = "GEt", url = "http://host" },
		})
	end)

	it("only one variable and method and url", function()
		check({ "@key=value # comment", "GET http://host" }, 0, {
			variables = { key = "value" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url with comment in the same line", function()
		check("GET http://host # with comment in the same line", 1, {
			variables = {},
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url with variable", function()
		check({ "@host=my-host # comment", "###", "GET http://{{host}}" }, 3, {
			variables = { host = "my-host" },
			request = { method = "GET", url = "http://my-host" },
		})
	end)

	it("one variable and method url", function()
		check({ "@key=value", "###", "GET http://host" }, 3, {
			variables = { key = "value" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("two variables and method url", function()
		check({ "@key1=value1 #comment", " ", "# comment", "", "@key2=value2", "###", "GET http://host" }, 6, {
			variables = { key1 = "value1", key2 = "value2" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and method url", function()
		check("###\nGET http://host", 1, {
			variables = {},
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and one variable and method url", function()
		check({ "###", "@key=value", "# comment", "GET http://host" }, 2, {
			variables = { key = "value" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("delimiter and two variable and method url", function()
		check({ "@key=value", "# comment", "###", "@key2=value2", "GET http://host" }, 3, {
			variables = { key = "value", key2 = "value2" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url and header", function()
		check({ "GET http://host", "", "accept: application/json # comment", "" }, 4, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				headers = { accept = "application/json" },
			},
		})
	end)

	it("one variable and method url and header", function()
		check({ "@key=value", "###", "GET http://host", "", "accept: application/json", "" }, 4, {
			variables = { key = "value" },
			request = {
				method = "GET",
				url = "http://host",
				headers = { accept = "application/json" },
			},
		})
	end)

	it("method url and query", function()
		check({ "GET http://host", "", "id=42# comment", "" }, 2, {
			variables = {},
			request = { method = "GET", url = "http://host", query = { id = "42" } },
		})
	end)

	it("method url and header query", function()
		check({ "GET http://host", "", "accept: application/json", "", "id=42" }, 1, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				query = { id = "42" },
				headers = { accept = "application/json" },
			},
		})
	end)

	it("method url with body", function()
		check({ "GET http://host", "  ", "{", "\t'name': 'John'", "}" }, 1, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				body = "{\t'name': 'John'}",
			},
		})
	end)

	it("method url and header query with body", function()
		check({ "GET http://host", "", "accept: application/json", "", "id=42", "  ", "{", "'name': 'John'", "}" }, 9, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				query = { id = "42" },
				headers = { accept = "application/json" },
				body = "{'name': 'John'}",
			},
		})
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
				"{'name': 'John'}",
			},
			9,
			{
				variables = { k = "v" },
				request = {
					method = "GET",
					url = "http://host",
					query = { id = "42" },
					headers = { accept = "application/json" },
					body = "{'name': 'John'}",
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
				variables = { k = "v" },
				request = {
					method = "GET",
					url = "http://host",
					headers = { accept = "application/json" },
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
				variables = {},
				request = {
					method = "GET",
					url = "http://host",
					query = { user = os.getenv("USER") },
					headers = { accept = "application/json" },
				},
			}
		)
	end)

	it("replace variable from variable from environment variable", function()
		check(
			{
				"@host={{$USER}}",
				"GET http://{{host}}",
			},
			1,
			{
				variables = { ["host"] = os.getenv("USER") },
				request = {
					method = "GET",
					url = "http://" .. os.getenv("USER"),
				},
			}
		)
	end)

	it("replace variable from command", function()
		check(
			{
				"GET http://{{> echo -n 'echo-host'}}",
				"accept: application/json",
				"",
				"cmd={{>echo -n 'my output'}}",
			},
			1,
			{
				variables = {},
				request = {
					method = "GET",
					url = "http://echo-host",
					query = { cmd = "my output" },
					headers = { accept = "application/json" },
				},
			}
		)
	end)

	it("replace variable from variable from command", function()
		check(
			{
				"@host = {{>echo 'my-host-from-var'}}",
				"GET http://{{host}}",
			},
			1,
			{
				variables = { ["host"] = "my-host-from-var" },
				request = {
					method = "GET",
					url = "http://my-host-from-var",
				},
			}
		)
	end)

	it("do not replace variable in comment", function()
		local r = p.parse("GET http://host\nid=3 # {{:id}}")
		assert.are.same({}, r.replacements)
	end)

	it("method url with script", function()
		check({ "GET http://host", "  ", "--{%", "-- comment", "--%}" }, 1, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				script = "-- comment",
			},
		})
	end)

	it("method url with body and script", function()
		check(
			{
				"GET http://host",
				"",
				"{",
				"\t'name': 'John'",
				"}",
				"",
				"--{%",
				"print('Hey ...')",
				"--%}",
			},
			1,
			{
				variables = {},
				request = {
					method = "GET",
					url = "http://host",
					body = "{\t'name': 'John'}",
					script = "print('Hey ...')",
				},
			}
		)
	end)

	it("wrong selection, but works", function()
		check("GET http://host", 2, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
			},
		})
	end)

	it("empty", function()
		local r = p.parse("", 1, { is_in_execute_mode = false })
		assert.are.same({}, r.request)
	end)
end)

describe("errors:", function()
	local function check(input, selected, expected)
		local r = p.parse(input, selected)

		assert.is_true(r:has_diag())
		local err = r.diagnostics[1]
		assert.are.same(expected.message, err.message)
		assert.are.same(expected.lnum, err.lnum)
	end

	it("empty", function()
		check("", 1, {
			message = "no request URL found. please set the cursor to an valid request",
			lnum = 0,
		})
	end)

	it("only comment", function()
		check("# comment", 1, {
			message = "no request URL found. please set the cursor to an valid request",
			lnum = 0,
		})
	end)

	it("only one variable", function()
		check("@key=value", 1, {
			message = "no request URL found. please set the cursor to an valid request",
			lnum = 0,
		})
	end)

	it("only one variable and delimiter", function()
		check("@key=value\n###", 2, {
			message = "no request URL found",
			lnum = 2,
		})
	end)

	it("only delimiter", function()
		check("###", 1, {
			message = "no request URL found",
			lnum = 1,
		})
	end)

	it("with variable", function()
		check("@key=", 1, { message = "variable value is missing", lnum = 0 })
	end)

	it("selected in global variable", function()
		check({ "@key=value", " ", "###", "@local=value" }, 4, {
			message = "no request URL found",
			lnum = 3,
		})
	end)

	it("invalid transition, is not a method", function()
		check({ "@key=value", "accept: application/json" }, 2, {
			message = "this is not a valid http method",
			lnum = 1,
		})
	end)

	it("method url with script and body", function()
		check(
			{
				"GET http://host",
				"accept: application/json",
				"",
				"--{%",
				"print('Hey ...')",
				"--%}",
				"",
				"{",
				"\t'name': 'John'",
				"}",
			},
			1,
			{
				message = "invalid input, this and the following lines are ignored",
				lnum = 7,
			}
		)
	end)

	it("invalid transition", function()
		check({ "@key=value", "GET http://host", "{", "}", "", "@key2=value2" }, 2, {
			message = "invalid input, this and the following lines are ignored",
			lnum = 5,
		})
	end)
end)

describe("curl requests:", function()
	it("simpelst curl", function()
		check(">curl http://host", 1, {
			variables = {},
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("simple curl with variables", function()
		check({ "@key=value # comment", ">curl -X get http://host" }, 1, {
			variables = { key = "value" },
			request = { method = "GET", url = "http://host" },
		})
	end)

	it("method url and header", function()
		check({ ">curl  http://host -H 'accept: application/json' ", "" }, 4, {
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				headers = { accept = "application/json" },
			},
		})
	end)

	it("method url with body and script", function()
		check(
			{
				">curl  http://host",
				[[--data "{	'name': 'John'}" ]],
				"",
				"--{%",
				"print('Hey ...')",
				"--%}",
			},
			1,
			{
				variables = {},
				request = {
					method = "GET",
					url = "http://host",
					body = "{\t'name': 'John'}",
					script = "print('Hey ...')",
				},
			}
		)
	end)

	it("method url with json-body from file", function()
		check(
			{
				">curl  http://host",
				"-d @/from/file.json",
			},
			1,
			{
				variables = {},
				request = {
					method = "GET",
					url = "http://host",
					body = "@/from/file.json",
				},
			}
		)
	end)
end)
