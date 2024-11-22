local assert = require("luassert")
local p = require("resty.parser")
local f = require("resty.output.format")
local exec = require("resty.exec")

describe("examples parser:", function()
	describe("one input", function()
		local input = [[

@host= myhost
@port= 8080

###

GET http://{{host}}:{{port}}


###

@port= 9090

GET http://{{host}}:{{port}}

###

POST http://host

accept: application/json  

filter = id = "42" 

{
	"name": "john",
	"valid": true
}



###
@id = "42"

GET http://host

filter = id = {{id}} 
]]
		local function check(selected, expected)
			local r = p.parse(input, selected)
			print("-- " .. f.duration_to_str(r.duration))

			assert.is_false(r:has_diag(), "has error")
			assert.are.same(r.variables, expected.variables, "compare global_variables")
			assert.are.same(r.request, expected.request or {}, "compare request")
		end

		it("GET with global variables", function()
			check(5, {
				variables = { host = "myhost", port = "8080" },
				request = {
					method = "GET",
					url = "http://myhost:8080",
				},
			})
		end)

		it("GET with global and local variables", function()
			check(11, {
				variables = { host = "myhost", port = "9090" },
				request = {
					method = "GET",
					url = "http://myhost:9090",
				},
			})
		end)

		it("post with body", function()
			check(16, {
				variables = { host = "myhost", port = "8080" },
				request = {
					method = "POST",
					url = "http://host",
					query = { filter = 'id = "42"' },
					headers = { accept = "application/json" },
					body = '{	"name": "john",	"valid": true}',
				},
			})
		end)

		it("replace id", function()
			check(31, {
				variables = { host = "myhost", port = "8080", id = '"42"' },
				request = {
					method = "GET",
					url = "http://host",
					query = { filter = 'id = "42"' },
				},
			})
		end)
	end)

	describe("variables", function()
		it("aggregate variables", function()
			local input = [[
@host= myhost
@port= 8080
@full_name={{host}}:{{port}}

GET http://{{full_name}}

]]

			local r = p.parse(input, 1)
			assert.are.same({ host = "myhost", port = "8080", full_name = "myhost:8080" }, r.variables)
			assert.are.same("http://myhost:8080", r.request.url)
		end)

		it("substitute global and local variables", function()
			local input = [[
@host= myhost
@port= 8080
@token =Bearer mytoken123
@filter = id = "42" and age > 42 

GET http://{{host}}:{{port}}

accept: application/json
Authorization: {{token}} 

filter = {{filter}} # a comment
include = sub, *  

]]

			local r = p.parse(input, 1)
			assert.are.same(
				{ host = "myhost", port = "8080", token = "Bearer mytoken123", filter = 'id = "42" and age > 42' },
				r.variables
			)
			assert.are.same("http://myhost:8080", r.request.url)
			assert.are.same({ accept = "application/json", Authorization = "Bearer mytoken123" }, r.request.headers)
			assert.are.same({ filter = 'id = "42" and age > 42', include = "sub, *" }, r.request.query)
		end)
	end)

	describe("global variables", function()
		it("global variables", function()
			local input = [[
GET https://reqres.in/api/users/2

--{%
  local json = ctx.json_body()
  ctx.set("id", json.data.id)
--%}
]]

			local r = p.parse(input, 1)
			local gvars = exec.script(r.request.script, { ["body"] = '{"data" : { "id": 42 }}' })
			assert.are.same({ ["id"] = "42" }, gvars)

			p.set_global_variables(gvars)
			assert.are.same({ ["id"] = "42" }, r.global_variables)
		end)
	end)
end)
