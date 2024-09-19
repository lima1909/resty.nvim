---@diagnostic disable: need-check-nil

local assert = require("luassert")
local p = require("resty.parser.parserng")
local format = require("resty.output.format")

describe("parse:", function()
	it("parse line variables", function()
		local k, v, e = p._parse_line_variable("@key=value")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value", v)

		k, v, e = p._parse_line_variable("@key=value # comment")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value ", v)

		k, v, e = p._parse_line_variable("@k_e-y = va_lu-e  2")
		assert.is_nil(e)
		assert.are.same("k_e-y", k)
		assert.are.same("va_lu-e  2", v)

		k, v, e = p._parse_line_variable("@key={{$USER}}")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("{{$USER}}", v)

		k, v, e = p._parse_line_variable("@key=value # comment")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value ", v)

		-- var with spacs
		k, v, e = p._parse_line_variable("@key=value  foo")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value  foo", v)

		-- errors
		_, _, e = p._parse_line_variable("@={{$USER}}")
		assert.is_not_nil(e)
		assert.are.same("variable key is missing", e.message)
		assert.are.same(1, e.col)

		k, _, e = p._parse_line_variable("@key")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		assert.are.same("equal char is missing", e.message)
		assert.are.same(4, e.col)

		k, _, e = p._parse_line_variable("@key=")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		assert.are.same("variable value is missing", e.message)
		assert.are.same(5, e.col)
	end)

	it("parse line method url", function()
		local r, e = p._parse_line_method_url("GET http://lo-cal_host")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://lo-cal_host" }, r)

		r, e = p._parse_line_method_url("GET http://lo-cal_host #comment")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://lo-cal_host" }, r)

		r, e = p._parse_line_method_url("GET http://localhost HTTP/1")
		assert.are.same({ method = "GET", url = "http://localhost", http_version = "HTTP/1" }, r)
		assert.is_nil(e)

		r, e = p._parse_line_method_url("GET http://localhost?k1=v1&k2=v2")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://localhost?k1=v1&k2=v2" }, r)

		r, e = p._parse_line_method_url("GET http://{{host}}")
		assert.is_nil(e)
		assert.are.same({ method = "GET", url = "http://{{host}}" }, r)

		--
		-- error or hints
		r, e = p._parse_line_method_url("Foo http://127.0.0.1:8080")
		assert.is_not_nil(e)
		assert.are.same(e.message, "unknown http method: Foo")
		assert.are.same(1, e.col)
		assert.are.same({ method = "Foo", url = "http://127.0.0.1:8080" }, r)

		r, e = p._parse_line_method_url("GET http://localhost HTTP/1  foo")
		assert.is_not_nil(e)
		assert.are.same(e.message, "invalid input after the request definition: foo")
		assert.are.same(29, e.col)
	end)

	it("parse line header and query", function()
		local k, v, is, e = p._parse_line_header_query("accept: application/json")
		assert.is_nil(e)
		assert.are.same(p.is_header, is)
		assert.are.same("accept", k)
		assert.are.same("application/json", v)

		k, v, is, e = p._parse_line_header_query("accept: application/json # my comment")
		assert.is_nil(e)
		assert.are.same(p.is_header, is)
		assert.are.same("accept", k)
		assert.are.same("application/json ", v)

		k, v, is, e = p._parse_line_header_query("f_o-o: a=b")
		assert.is_nil(e)
		assert.are.same(p.is_header, is)
		assert.are.same("f_o-o", k)
		assert.are.same("a=b", v)

		k, v, is, e = p._parse_line_header_query("foo: a; b")
		assert.is_nil(e)
		assert.are.same(p.is_header, is)
		assert.are.same("foo", k)
		assert.are.same("a; b", v)

		k, v, is, e = p._parse_line_header_query("id = 42")
		assert.is_nil(e)
		assert.are.same(p.is_query, is)
		assert.are.same("id", k)
		assert.are.same("42", v)

		-- error or hints
		k, v, is, e = p._parse_line_header_query("1id  ")
		assert.are.same(0, is)
		assert.is_nil(k)
		assert.is_nil(v)
		assert.are.same("valid header or query key is missing", e.message)

		k, v, is, e = p._parse_line_header_query("ID  ")
		assert.are.same(0, is)
		assert.is_nil(k)
		assert.is_nil(v)
		assert.are.same("valid header or query key is missing", e.message)
		assert.are.same(1, e.col)

		k, v, is, e = p._parse_line_header_query("id  ")
		assert.are.same(0, is)
		assert.are.same("id", k)
		assert.is_nil(v)
		assert.are.same("invalid delimiter: ''. Only supported ':' for headers or '=' for queries", e.message)
		assert.are.same(1, e.col)

		k, v, is, e = p._parse_line_header_query("id = ")
		assert.are.same(p.is_query, is)
		assert.are.same("id", k)
		assert.is_nil(v)
		assert.are.same("query value is missing", e.message)
		assert.are.same(5, e.col)
	end)

	it("json", function()
		local s = os.clock()
		local _ = vim.json.decode('{"name": "Pe{ter", "boy": true, "age": 34}')
		local e = os.clock() - s
		print("time json decode: " .. format.duration(e))
	end)

	it("replace variables", function()
		local s = os.clock()
		local line, replaced = p._replace_variable("abc: {{$USER}}, {{var}}, {{> echo -n 'yeh'}}", { var = "from var" })
		local e = os.clock() - s

		print("time replace line: " .. format.duration(e))
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
			-- "GET http://{{host}}:7171?myid=9&ot_he-r=a # comment ",
			"GET http://{{host}}:7171 # comment ",
			"",
			"accept: application/json # comment",
			"foo: =bar; blub",
			"",
			"qid = {{id}} # comment",
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

		assert.are.same({ host = "my-h_ost", id = "42", os_user = os_user }, r.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json ",
				foo = "=bar; blub",
			},
			method = "GET",
			query = {
				qid = "42 ",
				-- myid = "9",
				-- ["ot_he-r"] = "a",
			},
			script = '--{%  local json = ctx.json_body()  ctx.set("id", json.data.id)--%}',
			url = "http://my-h_ost:7171",
		}, r.request)
		assert.are.same({
			{ from = "$USER", to = os_user, type = "env" },
			{ from = "host", to = "my-h_ost", type = "var" },
			{ from = "id", to = "42", type = "var" },
		}, r.replacements)

		print("time parse request: " .. format.duration(r.duration))
	end)

	it("parse ng with global variables", function()
		local input = {
			"",
			"@host = g_host_7",
			"@baz = ba r",
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

		local r = p.parse(input, 7)

		assert.are.same({ host = "l_host_1", baz = "ba r" }, r.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json ",
				foo = "=bar; blub",
			},
			method = "GET",
			query = {
				baz = "ba r",
			},
			script = '--{%  local json = ctx.json_body()  ctx.set("id", json.data.id)--%}',
			url = "http://l_host_1:7171",
		}, r.request)
		assert.are.same({
			{ from = "host", to = "l_host_1", type = "var" },
			{ from = "baz", to = "ba r", type = "var" },
		}, r.replacements)

		print("time parse request: " .. format.duration(r.duration))
	end)
end)
