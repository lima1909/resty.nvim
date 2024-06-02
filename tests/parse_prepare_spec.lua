local p = require("resty.parser2")
local assert = require("luassert")

describe("parse globals:", function()
	it("global variables", function()
		local tt = {
			{ input = "", expected = {} },
			{ input = "@host= myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host =myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host = myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host = myhost \n@port=1234", expected = { ["host"] = "myhost", ["port"] = "1234" } },
		}

		for _, tc in ipairs(tt) do
			local result = p.prepare_parse(tc.input, 1)
			assert.are.same(result.global_variables, tc.expected)
		end
	end)

	it("parse errors by global variables", function()
		local tt = {
			{ input = "@host", error_msg = "expected char '='" },
			{ input = "@", error_msg = "expected char '='" },
			{ input = "@=my-host", error_msg = "an empty key" },
			{ input = "@host=", error_msg = "an empty value" },
		}

		for _, tc in ipairs(tt) do
			local result, err = pcall(p.prepare_parse, tc.input, 1)
			assert(not result)
			assert(err:find(tc.error_msg), err)
		end
	end)
end)

-- ----------------------------------------------
describe("parse requests:", function()
	it("find selected requests", function()
		local requests = [[
###
GET http://host

###
GET http://my-host
###
GET http://other-host


###
GET https://host
]]

		local tt = {
			{ input = "###\nGET http://host", selected = 0, result = nil, readed_lines = 0 },
			{ input = "###\nGET http://host", selected = 2, result = { "GET http://host" }, readed_lines = 2 },
			{ input = "###\nGET http://host", selected = 1, result = { "GET http://host" }, readed_lines = 2 },

			-- more than one request
			{ input = requests, selected = 0, result = nil, readed_lines = 0 },
			{ input = requests, selected = 2, result = { "GET http://host" }, readed_lines = 3 },
			{ input = requests, selected = 4, result = { "GET http://my-host" }, readed_lines = 5 },
			{ input = requests, selected = 9, result = { "GET http://other-host" }, readed_lines = 9 },
		}

		for _, tc in pairs(tt) do
			local result = p.prepare_parse(tc.input, tc.selected)
			assert.are.same(tc.result, result.req_lines)
			assert.are.same(tc.readed_lines, result.readed_lines)
		end
	end)

	it("requests with local variables", function()
		local result = p.prepare_parse(
			[[
###

@host=myhost

GET http://{{host}}
]],
			2
		)
		assert.are.same({ "@host=myhost", "GET http://{{host}}" }, result.req_lines)
	end)

	it("parse error, selected row to big", function()
		local result, err = pcall(
			p.prepare_parse,
			[[
###
GET http://host

###
GET http://my-host

---

ignored

]],
			999
		)

		assert(not result)
		assert(err:find("the selected row: 999"))
	end)
end)

-- ----------------------------------------------
describe("parse requests with global variables:", function()
	it("find selected requests", function()
		local input = [[

@host= myhost
@port= 8080

###

GET http://{{host}}:{{port}}


###
GET http://new-host
]]
		local result = p.prepare_parse(input, 6)

		assert.are.same({ ["host"] = "myhost", ["port"] = "8080" }, result.global_variables)
		assert.are.same({ "GET http://{{host}}:{{port}}" }, result.req_lines)
		assert.are.same(9, result.readed_lines)
	end)

	it("read one request", function()
		local input = [[
@host= myhost

###

@port= 8080

GET http://{{host}}:{{port}}


filter = id = "42" 
# comment
]]
		local result = p.prepare_parse(input, 6)

		assert.are.same({ ["host"] = "myhost" }, result.global_variables)
		assert.are.same({
			"@port= 8080",
			"GET http://{{host}}:{{port}}",
			'filter = id = "42" ',
		}, result.req_lines)
		assert.are.same(12, result.readed_lines)
	end)
end)

-- ----------------------------------------------
describe("parse and create a request:", function()
	it("parse and create request", function()
		local input = [[
@host= myhost
@token =Bearer mytoken123
@filter = id = "42" and age > 42 

###

@port= 8080

GET http://{{host}}:{{port}}

accept: application/json  
Authorization: {{token}} 

filter = {{filter}}
include = sub, *  
]]
		local result = p.parse(input, 5)

		assert.are.same({
			req = {
				method = "GET",
				url = "http://myhost:8080",
				query = {
					filter = 'id = "42" and age > 42',
					include = "sub, *",
				},
				headers = {
					accept = "application/json",
					Authorization = "Bearer mytoken123",
				},
			},
		}, result)
	end)
end)
