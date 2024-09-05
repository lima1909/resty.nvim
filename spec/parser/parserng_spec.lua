local assert = require("luassert")
local p = require("resty.parser.parserng")

describe("parse:", function()
	-- it("script", function()
	-- 	local lines = {
	-- 		"--{%",
	-- 		"  local body = ctx.json_body()",
	-- 		'  ctx.set("login.token", body.token)',
	-- 		"--%}",
	-- 	}
	-- 	local l, script = p.parse_body(p.line_iter(lines), p.Script)
	-- 	assert.are.same('--{%  local body = ctx.json_body()  ctx.set("login.token", body.token)--%}', script)
	-- end)

	it("with script", function()
		local input = [[
# comment
@k=v
@k2=v2


POST http://host

# application: application/json

--{%
  local body = ctx.json_body()
  ctx.set("login.token", body.token)
--%}

]]
		local r = p.parse(input)

		assert.are.same({
			variables = { k = "v", k2 = "v2" },
			request = {
				method = "POST",
				url = "http://host",
				script = '--{%  local body = ctx.json_body()  ctx.set("login.token", body.token)--%}',
			},
		}, r)
	end)

	it("parse two variables with more lines ", function()
		local input = {
			"@key1=value1",
			"@key2=value2",
			"",
			"GET http://host",
			"# accept: application/json",
			"",
			"# id=7",
			"",
			"{",
			' "name": "me" ',
			"}",
			"",
		}
		local start_time = os.clock()
		local parse = p.parse(input)
		print("Time: " .. require("resty.output.format").duration(os.clock() - start_time))

		assert.are.same({
			variables = { key1 = "value1", key2 = "value2" },
			request = {
				method = "GET",
				url = "http://host",
				body = '{ "name": "me" }',
				-- query = {},
				-- headers = {},
			},
		}, parse)
	end)
end)

-- describe("iter", function()
-- 	it("not skipping the line", function()
-- 		assert.is_false(p.ignore_line("", p.with_blank_lines))
-- 		assert.is_false(p.ignore_line(" #", p.with_blank_lines))
-- 		assert.is_false(p.ignore_line("@key=value", p.with_blank_lines))
-- 	end)
--
-- 	it("skip line", function()
-- 		assert.is_true(p.ignore_line(""))
-- 		assert.is_true(p.ignore_line(" "))
-- 		assert.is_true(p.ignore_line("#"))
-- 		assert.is_true(p.ignore_line("# comment"))
-- 	end)
--
-- 	it("skip blank lines", function()
-- 		assert.is_true(p.ignore_line("", { ignore_blank_lines = true }))
-- 		assert.is_true(p.ignore_line(" ", { ignore_blank_lines = true }))
-- 		assert.is_true(p.ignore_line("\t", { ignore_blank_lines = true }))
-- 	end)
-- end)

-- describe("parse json :", function()
-- 	it("empty or not a json", function()
-- 		local line, json = p.parse_json(p.line_iter({}))
-- 		assert.is_nil(line)
-- 		assert.is_nil(json)
--
-- 		line, json = p.parse_json(p.line_iter({ "" }))
-- 		assert.is_nil(line)
-- 		assert.is_nil(json)
-- 	end)
--
-- 	it("is json", function()
-- 		local line, json = p.parse_json(p.line_iter({ "{" }))
-- 		assert.is_nil(line)
-- 		assert.are.same("{", json)
--
-- 		line, json = p.parse_json(p.line_iter({ "{", "" }))
-- 		assert.is_nil(line)
-- 		assert.are.same("{", json)
--
-- 		--
-- 		line, json = p.parse_json(p.line_iter({ "{ }" }))
-- 		assert.is_nil(line)
-- 		assert.are.same("{ }", json)
--
-- 		line, json = p.parse_json(p.line_iter({ "{ }", " " }))
-- 		assert.is_nil(line)
-- 		assert.are.same("{ } ", json)
--
-- 		--
-- 		line, json = p.parse_json(p.line_iter({ "{", '"name": "foo"', "}" }))
-- 		assert.are.same("}", line)
-- 		assert.are.same('{"name": "foo"}', json)
--
-- 		line, json = p.parse_json(p.line_iter({ "{", ' "name": "foo" ', "}", "\t" }))
-- 		assert.are.same("}", line)
-- 		assert.are.same('{ "name": "foo" }', json)
--
-- 		line, json = p.parse_json(p.line_iter({ "{", ' "name": "foo" # comment', "}", " \t" }))
-- 		assert.are.same("}", line)
-- 		assert.are.same('{ "name": "foo" }', json)
-- 	end)
-- end)

-- describe("parse variables:", function()
-- 	it("parse no variable", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "GET http://host" }))
-- 		assert.are.same({}, vars)
-- 		assert.are.same("GET http://host", line)
-- 	end)
--
-- 	it("parse one variable", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "@key1=value1" }))
-- 		assert.are.same({ key1 = "value1" }, vars)
-- 		assert.is_nil(line)
-- 	end)
--
-- 	it("parse two variables", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "@key1=value1", "@key2=value2" }))
-- 		assert.are.same({ key1 = "value1", key2 = "value2" }, vars)
-- 		assert.is_nil(line)
-- 	end)
--
-- 	it("parse two variables with more lines ", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "@key1=value1", "@key2=value2", "GET http://host" }))
-- 		assert.are.same({ key1 = "value1", key2 = "value2" }, vars)
-- 		assert.are.same("GET http://host", line)
-- 	end)
--
-- 	it("parse two variables with comment", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "@key1=value1", "# comment", "@key2=value2 # comment" }))
-- 		assert.are.same({ key1 = "value1", key2 = "value2" }, vars)
-- 		assert.is_nil(line)
-- 	end)
--
-- 	it("parse two variables with comment and blanked line", function()
-- 		local line, vars = p.parse_variable(p.line_iter({ "@key1=value1", " ", "# comment", "@key2=value2 # comment" }))
-- 		assert.are.same({ key1 = "value1", key2 = "value2" }, vars)
-- 		assert.is_nil(line)
-- 	end)
-- end)
--
-- describe("parse method and url:", function()
-- 	it("only method and url", function()
-- 		local line, mu = p.parse_method_url(p.line_iter({ "GET http://host" }))
-- 		assert.are.same({ method = "GET", url = "http://host" }, mu)
-- 		assert.are.same("GET http://host", line)
-- 	end)
--
-- 	it("method and url and an other line", function()
-- 		local line, mu = p.parse_method_url(p.line_iter({ "GET http://host", "accept: application/json" }))
-- 		assert.are.same({ method = "GET", url = "http://host" }, mu)
-- 		assert.are.same("GET http://host", line)
-- 	end)
-- end)
--
