---@diagnostic disable: need-check-nil

local assert = require("luassert")
local p = require("resty.parser.parserng")
local format = require("resty.output.format")

describe("parse:", function()
	it("parse variables", function()
		local k, v, d, e = p.parse_variable("@key=value")
		assert.is_nil(e)
		assert.are.same("=", d)
		assert.are.same("key", k)
		assert.are.same("value", v)

		k, v, _, e = p.parse_variable("@k = v")
		assert.is_nil(e)
		assert.are.same("k", k)
		assert.are.same("v", v)

		k, v, _, e = p.parse_variable("@key=value # comment")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value", v)

		k, v, _, e = p.parse_variable("@k_e-y = va_lu-e2")
		assert.is_nil(e)
		assert.are.same("k_e-y", k)
		assert.are.same("va_lu-e2", v)

		k, v, _, e = p.parse_variable("@key={{$USER}}")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("{{$USER}}", v)

		k, v, _, e = p.parse_variable("@key={{>value}}")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("{{>value}}", v)

		k, v, _, e = p.parse_variable("@key={{:value}}")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("{{:value}}", v)

		k, v, _, e = p.parse_variable("@key=value # comment")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value", v)

		-- cfg variable
		k, v, _, e = p.parse_variable("@cfg.insecure = true")
		assert.is_nil(e)
		assert.are.same("cfg.insecure", k)
		assert.are.same("true", v)

		--
		-- errors
		_, _, _, e = p.parse_variable("@")
		assert.is_not_nil(e)
		assert.are.same("valid variable key is missing", e.message)
		assert.are.same(1, e.end_col)

		_, _, _, e = p.parse_variable("@1a")
		assert.is_not_nil(e)
		assert.are.same("valid variable key is missing", e.message)
		assert.are.same(1, e.end_col)

		k, _, _, e = p.parse_variable("@key")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		assert.are.same("variable delimiter is missing", e.message)
		assert.are.same(4, e.end_col)

		k, _, _, e = p.parse_variable("@key=")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		assert.are.same("variable value is missing", e.message)
		assert.are.same(5, e.end_col)
	end)

	it("parse request definition", function()
		local r, e = p.parse_request_definition("GET http://localhost")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://localhost" }, r)

		r, e = p.parse_request_definition("GET http://127.0.0.1:8181 #comment")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://127.0.0.1:8181" }, r)

		r, e = p.parse_request_definition("GET http://lo-cal_host HTTP/1")
		assert.are.same({ method = "GET", url = "http://lo-cal_host", http_version = "HTTP/1" }, r)
		assert.is_nil(e)

		r, e = p.parse_request_definition("GET http://localhost HTTP/1 # comment")
		assert.are.same({ method = "GET", url = "http://localhost", http_version = "HTTP/1" }, r)
		assert.is_nil(e)

		r, e = p.parse_request_definition("GET http://{{host}}:{{port}}")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://{{host}}:{{port}}" }, r)

		r, e = p.parse_request_definition("GET http://localhost?k1=v1&k2=v2")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://localhost", query = { k1 = "v1", k2 = "v2" } }, r)

		--
		-- error or hints
		r, e = p.parse_request_definition("GET")
		assert.is_not_nil(e)
		assert.are.same(e.message, "white space after http method is missing")
		assert.are.same(3, e.end_col)

		r, e = p.parse_request_definition("GET ")
		assert.is_not_nil(e)
		assert.are.same(e.message, "url is missing")
		assert.are.same(4, e.end_col)

		r, e = p.parse_request_definition("Foo http://127.0.0.1:8080")
		assert.is_not_nil(e)
		assert.are.same(e.message, "unknown http method: Foo")
		assert.are.same(3, e.end_col)
		assert.are.same({ method = "Foo", url = "http://127.0.0.1:8080" }, r)

		r, e = p.parse_request_definition("GET http://localhost HTTP/1  foo")
		assert.is_not_nil(e)
		assert.are.same(e.message, "invalid input after the request definition: foo")
		assert.are.same(29, e.end_col)

		r, e = p.parse_request_definition("GET http://localhostk1=v1&k2=v2")
		assert.is_not_nil(e)
		assert.are.same(e.message, "invalid query in url, must start with a '?'")
		assert.are.same({ method = "GET", url = "http://localhostk1" }, r)
	end)

	it("parse header", function()
		local k, v, d, e = p.parse_header("accept: application/json")
		assert.is_nil(e)
		assert.are.same(":", d)
		assert.are.same("accept", k)
		assert.are.same("application/json", v)

		k, v, _, e = p.parse_header("Content-type: application/json ; charset=UTF-8")
		assert.is_nil(e)
		assert.are.same("Content-type", k)
		assert.are.same("application/json ; charset=UTF-8", v)

		k, v, _, e = p.parse_header("accept: {{var}}")
		assert.is_nil(e)
		assert.are.same("accept", k)
		assert.are.same("{{var}}", v)

		k, v, _, e = p.parse_header("accept: application/json # my comment")
		assert.is_nil(e)
		assert.are.same("accept", k)
		assert.are.same("application/json ", v)

		k, v, d, e = p.parse_header("f_o-o: a=b")
		assert.is_nil(e)
		assert.are.same(":", d)
		assert.are.same("f_o-o", k)
		assert.are.same("a=b", v)

		k, v, _, e = p.parse_header("foo: a; b")
		assert.is_nil(e)
		assert.are.same("foo", k)
		assert.are.same("a; b", v)

		-- -- error or hints
		k, v, _, e = p.parse_header("1id  ")
		assert.is_nil(k)
		assert.is_nil(v)
		assert.are.same("valid header key is missing", e.message)
		assert.are.same(0, e.end_col)

		k, v, _, e = p.parse_header("ID  ")
		assert.are.same("ID", k)
		assert.are.same("header delimiter is missing", e.message)
		assert.are.same(4, e.end_col)

		k, v, d, e = p.parse_header("id : ")
		assert.are.same("id", k)
		assert.is_nil(v)
		assert.are.same(":", d)
		assert.are.same("header value is missing", e.message)
		assert.are.same(5, e.end_col)
	end)

	it("parse query", function()
		local k, v, d, e = p.parse_query("q=10%3A30")
		assert.is_nil(e)
		assert.are.same("=", d)
		assert.are.same("q", k)
		assert.are.same("10%3A30", v)

		k, v, d, e = p.parse_query("id = 42")
		assert.is_nil(e)
		assert.are.same("=", d)
		assert.are.same("id", k)
		assert.are.same("42", v)

		k, v, _, e = p.parse_query("id=ab%2042")
		assert.is_nil(e)
		assert.are.same("id", k)
		assert.are.same("ab%2042", v)

		k, v, _, e = p.parse_query("id = {{id}}")
		assert.is_nil(e)
		assert.are.same("id", k)
		assert.are.same("{{id}}", v)

		k, v, _, e = p.parse_query("id = {{id}}# comment")
		assert.is_nil(e)
		assert.are.same("id", k)
		assert.are.same("{{id}}", v)

		k, v, _, e = p.parse_query("id = 42 # comment")
		assert.is_nil(e)
		assert.are.same("id", k)
		assert.are.same("42", v)

		-- error or hints
		k, v, _, e = p.parse_query("1id  ")
		assert.is_nil(k)
		assert.is_nil(v)
		assert.are.same("valid query key is missing", e.message)
		assert.are.same(0, e.end_col)

		k, v, _, e = p.parse_query("ID  ")
		assert.are.same("ID", k)
		assert.are.same("query delimiter is missing", e.message)
		assert.are.same(4, e.end_col)

		k, v, d, e = p.parse_query("id = ")
		assert.are.same("id", k)
		assert.is_nil(v)
		assert.are.same("=", d)
		assert.are.same("query value is missing", e.message)
		assert.are.same(5, e.end_col)
	end)

	it("json", function()
		local s = os.clock()
		local _ = vim.json.decode('{"name": "Pe{ter", "boy": true, "age": 34}')
		local e = os.clock() - s
		print("time json decode: " .. format.duration(e))
	end)

	it("replace variables", function()
		-- local s = os.clock()
		local line, replaced = p._replace_variable("abc: {{$USER}}, {{var}}, {{> echo -n 'yeh'}}", { var = "from var" })
		-- local e = os.clock() - s

		-- print("time replace line: " .. format.duration(e))
		assert.are.same("abc: " .. os.getenv("USER") .. ", from var, yeh", line)
		assert.are.same({ from = "$USER", to = os.getenv("USER"), type = "env" }, replaced[1])
		assert.are.same({ from = "var", to = "from var", type = "var" }, replaced[2])
		assert.are.same({ from = "> echo -n 'yeh'", to = "yeh", type = "cmd" }, replaced[3])
	end)

	it("parse ng", function()
		local os_user = os.getenv("USER")

		local input = {
			"",
			"@os_user={{$USER}}# comment",
			"@host = my-h_ost",
			"",
			"@id = 42",
			"",
			"GET http://{{host}}:7171?myid={{id}}&ot_he-r=a # comment ",
			"",
			"accept: application/json # comment",
			"foo: =bar; blub",
			"",
			"foo%3Abar=value", -- is foo followed by a column : encoded
			"qid = {{id}} # {{:dummy}}", -- please ignore the :dummy variable
			"",
			"# comment",
			'{ "name": "me" }',
			"",
			"# comment",
			"--{%",
			-- "> {%",
			"  local json = ctx.json_body()",
			'  ctx.set("id", json.data.id)',
			"--%}",
		}

		local r = p.parse(input)

		assert.is_false(r:has_diagnostics())
		assert.are.same({ host = "my-h_ost", id = "42", os_user = os_user }, r.parsed.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json ",
				foo = "=bar; blub",
			},
			method = "GET",
			query = {
				qid = "42",
				["foo%3Abar"] = "value",
				myid = "42",
				["ot_he-r"] = "a",
			},
			script = '--{%  local json = ctx.json_body()  ctx.set("id", json.data.id)--%}',
			url = "http://my-h_ost:7171",
		}, r.parsed.request)
		assert.are.same({
			{ from = "$USER", to = os_user, type = "env" },
			{ from = "host", to = "my-h_ost", type = "var" },
			{ from = "id", to = "42", type = "var" },
			{ from = "id", to = "42", type = "var" },
		}, r.parsed.replacements)

		print("time parse request: " .. format.duration(r.parsed.duration))
	end)

	it("parse ng with global variables", function()
		local input = {
			"",
			"@host = g_host_7",
			"@baz = bar",
			"",
			"@cfg.insecure = true",
			"",
			"###",
			"@host = l_host_1",
			"",
			"GET http://{{host}}:7171 # comment ",
			"",
			"accept: application/json # comment",
			"foo: =bar; blub",
			"",
			"baz = {{baz}}# comment",
			"",
			"# comment",
			'{ "name": "me" }',
			"",
			"# comment",
			"--{%",
			-- "> {%",
			"  local json = ctx.json_body()",
			'  ctx.set("id", json.data.id)',
			"--%}",
		}

		local r = p.parse(input, 10)

		assert.is_false(r:has_diagnostics())
		assert.are.same({ host = "l_host_1", baz = "bar" }, r.parsed.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json ",
				foo = "=bar; blub",
			},
			method = "GET",
			query = {
				baz = "bar",
			},
			script = '--{%  local json = ctx.json_body()  ctx.set("id", json.data.id)--%}',
			url = "http://l_host_1:7171",
			insecure = "true",
		}, r.parsed.request)
		assert.are.same({
			{ from = "host", to = "l_host_1", type = "var" },
			{ from = "baz", to = "bar", type = "var" },
		}, r.parsed.replacements)

		print("time parse request: " .. format.duration(r.parsed.duration))
	end)

	it("parse ng - error", function()
		local input = {
			"",
			"@id = ",
			"",
			"GETT http://host:7171",
			"",
			"accept :  ",
		}

		local r = p.parse(input)
		assert.is_true(r:has_diagnostics())
		assert.are.same({
			{
				col = 0,
				end_col = 6,
				lnum = 1,
				message = "variable value is missing",
				severity = 1,
			},
			{
				col = 0,
				end_col = 4,
				lnum = 3,
				message = "unknown http method: GETT",
				severity = 3,
			},
			{
				col = 0,
				end_col = 10,
				lnum = 5,
				message = "header value is missing",
				severity = 1,
			},
		}, r.parsed.diagnostics)
		assert.are.same({
			headers = {},
			query = {},
			method = "GETT",
			url = "http://host:7171",
		}, r.parsed.request)
	end)

	it("parse ng - error: missing URL", function()
		local input = {
			"",
			"@id = 7",
			"",
		}

		local ok, err = pcall(p.parse, input)
		assert.is_false(ok)
		assert.are.same("no request URL found between row: 1 and 3", err)
	end)
end)
