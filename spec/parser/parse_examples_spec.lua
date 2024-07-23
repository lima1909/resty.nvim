local assert = require("luassert")
local p = require("resty.parser2")

describe("examples parser:", function()
	local input = [[

@host= myhost
@port= 8080

###

GET http://{{host}}:{{port}}


###

@port= 9090

get http://{{host}}:{{port}}

###

POST http://host

accept: application/json  

filter = id = "42" 

{
	"name": "john",
	"valid": true,
}



###
@id = "42"

GET http://host

filter = id = {{id}} 
]]
	local function check(selected, expected)
		local r = p.new():parse(input, selected)

		assert.is_false(r:has_errors(), vim.inspect(r.errors), "has error")
		assert.are.same(r.readed_lines, expected.readed_lines, "compare readed_lines")
		assert.are.same(r.variables, expected.variables, "compare global_variables")
		assert.are.same(r.current_state.id, expected.state, "compare state")
		assert.are.same(r.request, expected.request or {}, "compare request")
	end

	it("GET with global variables", function()
		check(5, {
			readed_lines = 9,
			variables = { host = "myhost", port = "8080" },
			state = p.STATE_METHOD_URL.id,
			request = {
				method = "GET",
				url = "http://myhost:8080",
				headers = {},
				query = {},
			},
		})
	end)

	it("GET with global and local variables", function()
		check(11, {
			readed_lines = 15,
			variables = { host = "myhost", port = "9090" },
			state = p.STATE_METHOD_URL.id,
			request = {
				method = "GET",
				url = "http://myhost:9090",
				headers = {},
				query = {},
			},
		})
	end)

	it("post with body", function()
		check(16, {
			readed_lines = 30,
			variables = { host = "myhost", port = "8080" },
			state = p.STATE_BODY.id,
			request = {
				method = "POST",
				url = "http://host",
				headers = { accept = "application/json" },
				query = { filter = 'id = "42"' },
				body = {
					"{",
					'	"name": "john",',
					'	"valid": true,',
					"}",
				},
			},
		})
	end)

	it("replace id", function()
		check(31, {
			readed_lines = 37,
			variables = { host = "myhost", port = "8080", id = '"42"' },
			state = p.STATE_HEADERS_QUERY.id,
			request = {
				method = "GET",
				url = "http://host",
				headers = {},
				query = { filter = 'id = "42"' },
			},
		})
	end)
end)
