local assert = require("luassert")
local p = require("resty.parser.parserng")
local format = require("resty.output.format")

describe("parse:", function()
	-- it("script", function()
	-- 	local lines = {
	-- 		"--{%",
	-- 		"  local body = ctx.json_body()",
	-- 		'  ctx.set("login.token", body.token)',
	-- 		"--%}",
	-- 	}
	-- 	local parser = p.new(lines)
	-- 	parser.parsed.request = {}
	--
	-- 	local l = parser:_parse_script_body()
	-- 	assert.is_nil(l)
	-- 	local script = parser.parsed.request.script
	-- 	assert.are.same('--{%  local body = ctx.json_body()  ctx.set("login.token", body.token)--%}', script)
	-- end)

	it("bar order", function()
		local input = [[
GET http://host

{
  "with": true
}

accept: application/json

]]
		local r = p.parse_request(input)

		assert.are.same({
			variables = {},
			request = {
				method = "GET",
				url = "http://host",
				query = {},
				-- headers = { accept = "application/json" },
				headers = {},
				body = '{  "with": true}',
			},
		}, r)
	end)

	it("with script", function()
		local input = [[
# comment
@k	= v # comment
@k2=v2


POST http://host

accept: application/json

--{%
  local body = ctx.json_body()
  ctx.set("login.token", body.token)
--%}

]]
		local r = p.parse_request(input)

		assert.are.same({
			variables = { k = "v", k2 = "v2" },
			request = {
				method = "POST",
				url = "http://host",
				script = '--{%  local body = ctx.json_body()  ctx.set("login.token", body.token)--%}',
				query = {},
				headers = { accept = "application/json" },
			},
		}, r)
	end)

	it("parse two variables with more lines ", function()
		local input = {
			"@key1=value1",
			"@id = 7",
			"",
			"GET http://host",
			"",
			"accept: application/json",
			"foo: =bar",
			"",
			"id = 7",
			"",
			"# comment",
			"{",
			' "name": "me" ',
			"}",
			"",
		}
		local start_time = os.clock()
		local parse = p.parse_request(input)
		local time = format.duration(os.clock() - start_time)
		print("Time: " .. time)

		assert.are.same({
			variables = { key1 = "value1", id = "7" },
			request = {
				method = "GET",
				url = "http://host",
				body = '{ "name": "me" }',
				query = { id = "7" },
				headers = { accept = "application/json", foo = "=bar" },
			},
		}, parse)
	end)
end)
