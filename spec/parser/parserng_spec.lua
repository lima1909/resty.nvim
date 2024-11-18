---@diagnostic disable: need-check-nil

local assert = require("luassert")
local p = require("resty.parser")
local result = require("resty.parser.result")
local format = require("resty.output.format")

describe("parse:", function()
	local function parse(input, selected, opts)
		return p.parse("GET http://host\n" .. input, selected, opts)
	end

	local function parse_var(input, selected, opts)
		return p.parse(input .. "\nGET http://host", selected, opts)
	end

	it("json", function()
		local s = vim.loop.hrtime()
		local _ = vim.json.decode('{"name": "Pe{ter", "boy": true, "age": 34}')
		local e = vim.loop.hrtime() - s
		print("time json decode: " .. format.duration_to_str(e))
	end)

	it("replace variables", function()
		local r = result.new()
		r.variables = { var = "from var" }
		local line = r:replace_variable("abc: {{$USER}}, {{var}}, {{> echo -n 'yeh'}}")

		assert.are.same("abc: " .. os.getenv("USER") .. ", from var, yeh", line)
		assert.are.same({ from = "$USER", to = os.getenv("USER"), type = "env" }, r.replacements[1])
		assert.are.same({ from = "var", to = "from var", type = "var" }, r.replacements[2])
		assert.are.same({ from = "> echo -n 'yeh'", to = "yeh", type = "cmd" }, r.replacements[3])
	end)

	it("replace prompt variables", function()
		local r = result.new({ is_in_execute_mode = false })
		local line = r:replace_variable("abc: {{: my prompt}}")
		assert.is_false(r:has_diag())
		assert.are.same("abc: {{: my prompt}}", line)
	end)

	it("get replace variable str", function()
		local txt, lnum = p.get_replace_variable_str({ "no replace" }, 1, 0)
		assert.is_nil(txt)
		assert.is_nil(lnum)

		txt, lnum = p.get_replace_variable_str({ "http://{{host}}" }, 1, 10)
		assert.are.same("no value found for key: host", txt)
		assert.is_nil(lnum)

		txt, lnum = p.get_replace_variable_str({ "http://{{: host}}" }, 1, 10)
		assert.are.same("prompt variables are not supported for a preview", txt)
		assert.is_nil(lnum)

		txt, lnum = p.get_replace_variable_str({ "@host=my", "http://{{host}}" }, 2, 10)
		assert.are.same("[1] host = my", txt)
		assert.are.same(1, lnum)
	end)

	it("parse request definition", function()
		local r = p.parse("GET http://localhost")
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://localhost" }, r.request)

		r = p.parse("GET http://127.0.0.1:8181 #comment")
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://127.0.0.1:8181" }, r.request)

		r = p.parse("GET http://lo-cal_host HTTP/1")
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://lo-cal_host", http_version = "HTTP/1" }, r.request)

		r = p.parse("GET http://localhost HTTP/1 # comment")
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://localhost", http_version = "HTTP/1" }, r.request)

		r = p.parse("GET http://{{host}}:{{port}}", 1, { replace_variables = false })
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://{{host}}:{{port}}" }, r.request)

		r = p.parse("GET http://localhost?k1=v1&k2=v2")
		assert.is_false(r:has_diag())
		assert.are.same({ method = "GET", url = "http://localhost?k1=v1&k2=v2" }, r.request)
	end)

	it("parse request definition errors", function()
		local r = p.parse("GET")
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same(d.message, "white space after http method is missing")
		assert.are.same(3, d.end_col)
		assert.are.same({}, r.request)

		r = p.parse("GET ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "url is missing")
		assert.are.same(4, d.end_col)
		assert.are.same({}, r.request)

		r = p.parse(":")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "http method is missing or doesn't start with a letter")
		assert.are.same(0, d.end_col)

		r = p.parse("GEThttp ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "unknown http method and missing url")
		assert.are.same(8, d.end_col)

		r = p.parse("Foo: ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "this is not a valid http method")
		assert.are.same(3, d.end_col)

		r = p.parse("Foo http://127.0.0.1:8080")
		assert.is_false(r:has_error())
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "unknown http method")
		assert.are.same(3, d.end_col)
		assert.are.same({ method = "Foo", url = "http://127.0.0.1:8080" }, r.request)

		r = p.parse("GET http://localhost HTTP/1.0  foo")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same(d.message, "invalid input after the request definition: 'foo', maybe spaces?")
		assert.are.same(31, d.end_col)
		assert.are.same({ method = "GET", url = "http://localhost", http_version = "HTTP/1.0" }, r.request)
	end)

	it("parse variables", function()
		local r = parse_var("@key=value")
		assert.is_false(r:has_diag())
		assert.are.same({ key = "value" }, r.variables)

		r = parse_var('@echo = {{>echo -n "1234"}}')
		assert.is_false(r:has_diag())
		assert.are.same({ echo = "1234" }, r.variables)

		r = parse_var("@k = v")
		assert.is_false(r:has_diag())
		assert.are.same({ k = "v" }, r.variables)

		r = parse_var("@key=value # comment")
		assert.is_false(r:has_diag())
		assert.are.same({ key = "value" }, r.variables)

		r = parse_var("@k_e-y = va_lu-e2")
		assert.is_false(r:has_diag())
		assert.are.same({ ["k_e-y"] = "va_lu-e2" }, r.variables)

		r = parse_var("@key={{$USER}}", 1, { replace_variables = false })
		assert.is_false(r:has_diag())
		assert.are.same({ key = "{{$USER}}" }, r.variables)

		r = parse_var("@key={{>value}}", 1, { replace_variables = false })
		assert.is_false(r:has_diag())
		assert.are.same({ key = "{{>value}}" }, r.variables)

		r = parse_var("@key={{:value}}", 1, { replace_variables = false })
		assert.is_false(r:has_diag())
		assert.are.same({ key = "{{:value}}" }, r.variables)

		r = parse_var("@key=value # comment")
		assert.is_false(r:has_diag())
		assert.are.same({ key = "value" }, r.variables)

		r = parse_var("@host = host.org")
		assert.is_false(r:has_diag())
		assert.are.same({ host = "host.org" }, r.variables)

		r = parse_var("@key=value # comment\n@host = host.org")
		assert.is_false(r:has_diag())
		assert.are.same({ key = "value", host = "host.org" }, r.variables)

		r = parse_var("# comment \n@key=value \n	\n@host = host.org")
		assert.is_false(r:has_diag())
		assert.are.same({ key = "value", host = "host.org" }, r.variables)

		r = parse_var("@key=value\n@host = host.org\nfoo=bar")
		assert.are.same({ key = "value", host = "host.org" }, r.variables)

		-- cfg variable
		r = parse_var("@cfg.insecure = true")
		assert.is_false(r:has_diag())
		assert.are.same({ insecure = true, method = "GET", url = "http://host" }, r.request)

		r = parse_var("@cfg.raw = --foo,--bar")
		assert.is_false(r:has_diag())
		assert.are.same({ raw = { "--foo", "--bar" }, method = "GET", url = "http://host" }, r.request)
	end)

	it("parse variables errors", function()
		local r = p.parse("@")
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("valid variable key is missing", d.message)

		r = p.parse("@1a")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("valid variable key is missing", d.message)
		assert.are.same(1, d.end_col)

		r = p.parse("@key")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("variable delimiter is missing", d.message)
		assert.are.same(4, d.end_col)

		r = p.parse("@key=")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("variable value is missing", d.message)
		assert.are.same(5, d.end_col)

		r = parse_var("@key={{x}}", 1, { replace_variables = true })
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("no value found for key: x", d.message)

		r = parse_var("@key={{}}", 1, { replace_variables = true })
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("no key found", d.message)

		r = parse_var("@cfg.invalid = true")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("unknown configuration key", d.message)
		assert.are.same(11, d.end_col)
	end)

	it("parse header", function()
		local r = parse("accept: application/json")
		assert.is_false(r:has_diag())
		assert.are.same({ accept = "application/json" }, r.request.headers)

		r = parse("Content-type: application/json ; charset=UTF-8")
		assert.is_false(r:has_diag())
		assert.are.same({ ["Content-type"] = "application/json ; charset=UTF-8" }, r.request.headers)

		r = parse("accept: {{var}}", 1, { replace_variables = false })
		assert.is_false(r:has_diag())
		assert.are.same({ accept = "{{var}}" }, r.request.headers)

		r = parse("accept: application/json # my comment")
		assert.is_false(r:has_diag())
		assert.are.same({ accept = "application/json" }, r.request.headers)

		r = parse("f_o-o: a=b")
		assert.is_false(r:has_diag())
		assert.are.same({ ["f_o-o"] = "a=b" }, r.request.headers)

		r = parse("foo: a; b")
		assert.is_false(r:has_diag())
		assert.are.same({ foo = "a; b" }, r.request.headers)

		r = parse("foo: {{> echo -n 'a; b'}}")
		assert.is_false(r:has_diag())
		assert.are.same({ foo = "a; b" }, r.request.headers)
	end)

	it("parse header errors", function()
		local r = parse("ID  ")
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("header: ':' or query: '=' delimiter is missing", d.message)
		assert.are.same(4, d.end_col)

		r = parse("id : ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("header value is missing", d.message)
		assert.are.same(5, d.end_col)

		r = parse("id # ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("header: ':' or query: '=' delimiter is missing", d.message)
		assert.are.same(3, d.end_col)

		-- is not a header, error on the end of the parsing
		r = parse("1id  ")
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("invalid input, this and the following lines are ignored", d.message)
		assert.are.same(0, d.col)
		assert.are.same(5, d.end_col)

		r = parse("foo: a\nfoo:b")
		assert.are.same({ ["foo"] = "b" }, r.request.headers)
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("overwrite header key: foo", d.message)
		assert.are.same(0, d.col)
		assert.are.same(3, d.end_col)
		assert.are.same(2, d.lnum)
	end)

	it("parse query", function()
		local r = parse("q=10%3A30")
		assert.is_false(r:has_diag())
		assert.are.same({ q = "10%3A30" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id = 42")
		assert.are.same({ id = "42" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id=ab%2042")
		assert.are.same({ id = "ab%2042" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id = {{id}}", 1, { replace_variables = false })
		assert.are.same({ id = "{{id}}" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id = {{id}}# comment", 1, { replace_variables = false })
		assert.are.same({ id = "{{id}}" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id = 42 # comment")
		assert.are.same({ id = "42" }, r.request.query)
		assert.are.same("http://host", r.request.url)

		r = parse("id = {{> echo -n '42'}}")
		assert.are.same({ id = "42" }, r.request.query)
		assert.are.same("http://host", r.request.url)
	end)

	it("parse query errors", function()
		local r = parse("id = ")
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("query value is missing", d.message)
		assert.are.same(5, d.end_col)

		r = parse("foo= a\nfoo=b")
		assert.are.same({ foo = "b" }, r.request.query)
		assert.are.same("http://host", r.request.url)
		assert.is_true(r:has_diag())
		d = r.diagnostics[1]
		assert.are.same("overwrite query key: foo", d.message)
		assert.are.same(0, d.col)
		assert.are.same(3, d.end_col)
		assert.are.same(2, d.lnum)
	end)

	it("parse json body", function()
		local r = parse('{ "name": "me" }')
		assert.is_false(r:has_diag())
		assert.are.same('{ "name": "me" }', r.request.body)

		r = parse('\n{ "name": "me" }')
		assert.is_false(r:has_diag())
		assert.are.same('{ "name": "me" }', r.request.body)

		r = parse('# comment \n{ "name": "me" }')
		assert.is_false(r:has_diag())
		assert.are.same('{ "name": "me" }', r.request.body)

		r = parse('\n{ "name": "me" }\n')
		assert.is_false(r:has_diag())
		assert.are.same('{ "name": "me" }', r.request.body)

		r = parse('\n{ "name": "me" }\n# comment')
		assert.is_false(r:has_diag())
		assert.are.same('{ "name": "me" }', r.request.body)

		r = parse('{\n  "name": "me" \n}\n')
		assert.is_false(r:has_diag())
		assert.are.same('{  "name": "me" }', r.request.body)
	end)

	it("parse json body from file", function()
		local r = parse("<  ./spec/parser/test.json")
		assert.is_false(r:has_diag())
		assert.are.same("./spec/parser/test.json", r.request.body)
		assert.are.same("./spec/parser/test.json", p._file_path_buffer)

		r = parse("<  ./spec/parser/not-exist.json")
		assert.is_true(r:has_diag())
		assert.is_nil(r.request.body)
		assert.are.same("./spec/parser/test.json", p._file_path_buffer)
	end)

	it("parse script body", function()
		local r = parse("--{%\n--%}")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse("\n--{%\n--%}")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse("# comment \n--{%\n--%}")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse("\n--{%\n--%}\n")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse("\n--{%\n--%}\n# comment")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse([[
--{%
  local json = ctx.json_body()
  ctx.set("id", json.data.id)
--%}

]])
		assert.is_false(r:has_diag())
		assert.are.same('  local json = ctx.json_body()\n  ctx.set("id", json.data.id)', r.request.script)

		-- error
		r = parse([[
--{%
  local json = ctx.json_body()
]])
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("missing end of script", d.message)
		assert.are.same(0, d.col)
		assert.are.same(3, d.lnum)
	end)

	it("parse script body for treesitter-http post script", function()
		local r = parse("\n> {%\n%}")
		assert.is_false(r:has_diag())
		assert.are.same("", r.request.script)

		r = parse([[
> {%
  local json = ctx.json_body()
  ctx.set("id", json.data.id)
%}

]])
		assert.is_false(r:has_diag())
		assert.are.same('  local json = ctx.json_body()\n  ctx.set("id", json.data.id)', r.request.script)

		-- error
		r = parse([[
> {%
  local json = ctx.json_body()
]])
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("missing end of script", d.message)
		assert.are.same(0, d.col)
		assert.are.same(3, d.lnum)
	end)

	it("parse ng", function()
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
			"foo: =bar; blub   # {{:dummy}}", -- please ignore the :dummy variable
			"",
			"foo%3Abar=value", -- is foo followed by a column : encoded
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
			"",
		}

		local r = p.parse(input, 1, { replace_variables = false })

		assert.is_false(r:has_diag())
		assert.are.same({ host = "my-h_ost", id = "42", os_user = "{{$USER}}" }, r.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json",
				foo = "=bar; blub",
			},
			method = "GET",
			script = '  local json = ctx.json_body()\n  ctx.set("id", json.data.id)',
			url = "http://{{host}}:7171?myid={{id}}&ot_he-r=a&foo%3Abar=value",
		}, r.request)
		assert.are.same({}, r.replacements)

		print("time parse request: " .. format.duration_to_str(r.duration))

		-- with replace variables
		r = p.parse(input)
		assert.are.same({
			{ from = "$USER", to = os.getenv("USER"), type = "env" },
			{ from = "host", to = "my-h_ost", type = "var" },
			{ from = "id", to = "42", type = "var" },
		}, r.replacements)

		print("time parse request: " .. format.duration_to_str(r.duration))
	end)

	it("with global variables", function()
		local input = {
			"",
			"@host = g_host_7",
			"@baz = bar",
			"",
			"@cfg.insecure = true",
			"@cfg.= blub",
			"",
			"###",
			"@host = l_host_1",
			"",
			"GET http://{{host}}:7171 # comment ",
			"",
			"accept: application/json # comment",
			"accept-charset: utf-8",
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

		local r = p.parse(input, 10, { replace_variables = false })

		assert.is_false(r:has_diag())
		assert.are.same({ host = "l_host_1", baz = "bar", ["cfg."] = "blub" }, r.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json",
				["accept-charset"] = "utf-8",
				foo = "=bar; blub",
			},
			query = { baz = "{{baz}}" },
			method = "GET",
			script = '  local json = ctx.json_body()\n  ctx.set("id", json.data.id)',
			url = "http://{{host}}:7171",
			insecure = true,
		}, r.request)
		assert.are.same({}, r.replacements)

		print("time parse request: " .. format.duration_to_str(r.duration))

		-- with replace variables
		r = p.parse(input, 10)
		assert.are.same({
			{ from = "host", to = "l_host_1", type = "var" },
			{ from = "baz", to = "bar", type = "var" },
		}, r.replacements)

		print("time parse request: " .. format.duration_to_str(r.duration))
	end)

	it("with check json body", function()
		local input = {
			"",
			"@cfg.check_json_body = true",
			"",
			"POST http://host:7171 ",
			"",
			"{ ",
			'"name" "me"',
			"}",
			"",
		}

		local r = p.parse(input)
		assert.is_true(r:has_diag())
		assert.are.same({
			{
				col = 0,
				end_col = 0,
				end_lnum = 7,
				lnum = 5,
				message = "json parsing error: Expected colon but found T_STRING at character 10",
				severity = 1,
			},
		}, r.diagnostics)
	end)

	it("without request", function()
		local input = [[
@host={{$HOST}}

###
@myhost={{$HOST}}
@port=2112

GET http://myhost
application: json
id = 5

###
id = 3

]]

		local r = p.parse(input, 12, { replace_variables = false })
		assert.is_true(r:has_diag())
		assert.are.same({
			{ col = 0, end_col = 2, lnum = 11, message = "unknown http method", severity = 3 },
			{ col = 0, end_col = 4, lnum = 11, message = "url must start with http", severity = 1 },
		}, r.diagnostics)
		assert.are.same({ host = "{{$HOST}}" }, r.variables)
		assert.are.same({
			method = "id",
			url = "=",
			http_version = "3",
		}, r.request)
		assert.are.same({}, r.replacements)
		assert.are.same({
			["area"] = { starts = 12, ends = 14 },
			request = 12,
			variables = { host = 1, starts = 1, ends = 1 },
			headers_query = {},
		}, r.meta)
	end)

	it("only (global) variables", function()
		local r = p.parse({ "", "@id = 7", "" }, 1, { is_in_execute_mode = false })
		assert.is_false(r:has_diag())
		assert.are.same({ id = "7" }, r.variables)

		r = p.parse({ "", "@id = 7", "###" }, 1, { is_in_execute_mode = false })
		assert.is_false(r:has_diag())
		assert.are.same({ id = "7" }, r.variables)
	end)
end)

describe("parse errors:", function()
	it("general - errors", function()
		local input = {
			"",
			"@id = ",
			"@foo=",
			"",
			"GETT http://host:7171",
			"",
			"accept :  ",
		}

		local r = p.parse(input)
		assert.is_true(r:has_diag())
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
				end_col = 5,
				lnum = 2,
				message = "variable value is missing",
				severity = 1,
			},
			{
				col = 0,
				end_col = 4,
				lnum = 4,
				message = "unknown http method",
				severity = 3,
			},
			{
				col = 0,
				end_col = 10,
				lnum = 6,
				message = "header value is missing",
				severity = 1,
			},
		}, r.diagnostics)
		assert.are.same({ method = "GETT", url = "http://host:7171" }, r.request)
	end)

	it("missing URL in request", function()
		local input = {
			"###",
			"@id = 7",
			"",
		}

		local r = p.parse(input, 1)
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("no request URL found", d.message)
		assert.are.same(1, d.lnum)
		assert.are.same(2, d.end_lnum)
	end)

	it("in global variable area - missing URL", function()
		local input = {
			"@id = 7",
			"",
		}

		local r = p.parse(input)
		assert.is_true(r:has_diag())
		local d = r.diagnostics[1]
		assert.are.same("no request URL found. please set the cursor to an valid request", d.message)
		assert.are.same(0, d.lnum)
		assert.are.same(1, d.end_lnum)
	end)
end)
