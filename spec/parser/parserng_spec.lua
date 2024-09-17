local assert = require("luassert")
local p = require("resty.parser.parserng")
local format = require("resty.output.format")

describe("parse:", function()
	-- it("foo", function()
	-- local dummy = "^([%a]+)[%s]*([%d]+)[%s]*([%w%c%p%s%x]*)"
	-- local s = os.clock()
	-- local m, d, c = string.match("GET 3     comment | {	", dummy)
	-- m = m:upper()
	-- local found = false
	-- if methods[m] then
	-- 	found = true
	-- end
	-- local e = os.clock() - s
	-- print("--" .. tostring(found) .. " " .. format.duration(e))
	-- print("digit: " .. d)
	-- print("comment: -" .. c .. "-")
	--
	-- local dummy = "(?[%w-_=&]*)"
	-- local r = string.match("k=v&k2=v2", dummy)
	-- 	local dummy = "(.*)"
	-- 	local r = string.match("", dummy)
	-- 	print("--" .. tostring(r) .. "--")
	-- end)

	it("parse pure variables", function()
		local k, v, e = p._parse_line_variable("@key=value")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value", v)

		k, v, e = p._parse_line_variable("@k_e-y = va_lu-e2")
		assert.is_nil(e)
		assert.are.same("k_e-y", k)
		assert.are.same("va_lu-e2", v)

		k, v, e = p._parse_line_variable("@key={{$USER}}")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("{{$USER}}", v)

		k, v, e = p._parse_line_variable("@key=value # comment")
		assert.is_nil(e)
		assert.are.same("key", k)
		assert.are.same("value", v)
		--
		-- errors
		_, _, e = p._parse_line_variable("@={{$USER}}")
		assert.is_not_nil(e)
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same("variable key is missing", e.message)

		k, _, e = p._parse_line_variable("@key")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same("equal char is missing", e.message)

		k, _, e = p._parse_line_variable("@key=")
		assert.are.same("key", k)
		assert.is_not_nil(e)
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same("variable value is missing", e.message)

		k, v, e = p._parse_line_variable("@key=value  foo")
		assert.are.same("key", k)
		assert.are.same("value", v)
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same("invalid input after the request definition: foo", e.message)
	end)

	it("parse pure method url", function()
		local r, e = p._parse_line_method_url("GET http://lo-cal_host")
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
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same(e.message, "unknown http method: Foo")
		assert.are.same({ method = "Foo", url = "http://127.0.0.1:8080" }, r)

		r, e = p._parse_line_method_url("GET http://localhost HTTP/1  foo")
		assert.is_not_nil(e)
		---@diagnostic disable-next-line: need-check-nil
		assert.are.same(e.message, "invalid input after the request definition: foo")
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

	it("dummy - load require", function()
		p.new("@key=val"):parse_request()
	end)

	it("parse ng", function()
		local os_user = os.getenv("USER")

		local input = {
			"",
			"@os_user={{$USER}} # comment",
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
end)
