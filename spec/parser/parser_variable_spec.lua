local assert = require("luassert")
local p = require("resty.parser.variables")

describe("variables parser", function()
	local variables = { ["host"] = "my-host" }

	it("variable", function()
		local replacements = {}
		local line = p.replace_variable(variables, "host={{host}}", replacements)
		assert.are.same("host=my-host", line)
		assert.are.same(p.TypeVar, replacements[1].type)
	end)

	it("global variable", function()
		local replacements = {}
		local line = p.replace_variable(variables, "myid={{id}}", replacements, { ["id"] = "42" })
		assert.are.same("myid=42", line)
		assert.are.same(p.TypeGlobalVar, replacements[1].type)
	end)

	it("global variable with . as seperator", function()
		local replacements = {}
		local line = p.replace_variable(variables, "myid={{my.id}}", replacements, { ["my.id"] = "42" })
		assert.are.same("myid=42", line)
		assert.are.same(p.TypeGlobalVar, replacements[1].type)
	end)

	it("global variable, override variable", function()
		local replacements = {}
		local line = p.replace_variable(variables, "host={{host}}", replacements, { ["host"] = "global-host" })
		assert.are.same("host=global-host", line)
		assert.are.same(p.TypeGlobalVar, replacements[1].type)
	end)

	it("command", function()
		local replacements = {}
		local line = p.replace_variable(variables, "user={{> echo -n 'me'}}", replacements)
		assert.are.same("user=me", line)
		assert.are.same(p.TypeCmd, replacements[1].type)
	end)

	it("environment", function()
		local replacements = {}
		local line = p.replace_variable(variables, "user={{$user}}", replacements)
		assert.are.same("user=" .. os.getenv("USER"), line)
		assert.are.same(p.TypeEnv, replacements[1].type)
	end)

	it("environmen and tcommand", function()
		local replacements = {}
		local line = p.replace_variable(variables, "user={{$user}} and host={{> echo -n 'myhost'}}", replacements)
		assert.are.same("user=" .. os.getenv("USER") .. " and host=myhost", line)
		assert.are.same(p.TypeEnv, replacements[1].type)
		assert.are.same(p.TypeCmd, replacements[2].type)
	end)
end)
