local assert = require("luassert")
local p = require("resty.parser.parserng")
local format = require("resty.output.format")
-- local var = require("resty.parser.variables")

describe("parse:", function()
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
		p.parse_request("@key=val")
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
			"GET http://{{host}}?myid=9&other=a # comment ",
			"",
			"accept: application/json # comment",
			"foo: =bar; blub",
			"",
			"id = {{id}} # comment",
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

		local s = os.clock()

		local r = p.parse_request(input)

		local e = os.clock() - s

		assert.are.same({ host = "my-h_ost", id = "42", os_user = os_user }, r.variables)
		assert.are.same({
			body = '{ "name": "me" }',
			headers = {
				accept = "application/json ",
				foo = "=bar; blub",
			},
			method = "GET",
			query = {
				id = "42 ",
			},
			script = '--{%  local json = ctx.json_body()  ctx.set("id", json.data.id)--%}',
			url = "http://my-h_ost?myid=9&other=a",
		}, r.request)
		assert.are.same({
			{ from = "$USER", to = os_user, type = "env" },
			{ from = "host", to = "my-h_ost", type = "var" },
			{ from = "id", to = "42", type = "var" },
		}, r.replacements)

		print("time parse request: " .. format.duration(e))
	end)
end)
