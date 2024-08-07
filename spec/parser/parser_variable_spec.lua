local assert = require("luassert")
local p = require("resty.parser.variables")

describe("variables parser", function()
	local variables = { ["host"] = "my-host" }

	it("variable", function()
		local line, replaced = p.replace_variable(variables, "host={{host}}")
		assert.are.same("host=my-host", line)
		assert.are.same(p.TypeVar, replaced[1].type)
	end)

	it("command", function()
		local line, replaced = p.replace_variable(variables, "user={{> echo -n 'me'}}")
		assert.are.same("user=me", line)
		assert.are.same(p.TypeCmd, replaced[1].type)
	end)

	it("environment", function()
		local line, replaced = p.replace_variable(variables, "user={{$user}}")
		assert.are.same("user=" .. os.getenv("USER"), line)
		assert.are.same(p.TypeEnv, replaced[1].type)
	end)

	it("environmen and tcommand", function()
		local line, replaced = p.replace_variable(variables, "user={{$user}} and host={{> echo -n 'myhost'}}")
		assert.are.same("user=" .. os.getenv("USER") .. " and host=myhost", line)
		assert.are.same(p.TypeEnv, replaced[1].type)
		assert.are.same(p.TypeCmd, replaced[2].type)
	end)
end)
