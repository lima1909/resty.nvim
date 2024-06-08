local p = require("resty.parser")
local assert = require("luassert")

describe("globals:", function()
	it("variables", function()
		local tt = {
			{ input = "", expected = {} },
			{ input = "@host= myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host =myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host = myhost", expected = { ["host"] = "myhost" } },
			{ input = "@host = myhost \n@port=1234", expected = { ["host"] = "myhost", ["port"] = "1234" } },
		}

		for _, tc in ipairs(tt) do
			local result = p.prepare_parse(tc.input, 1)
			assert.is_false(result:has_errors())
			local r = result.result
			assert.are.same(r.global_variables, tc.expected)
		end
	end)

	it("parse errors by global variables", function()
		local tt = {
			{ input = "@host", error_msg = "expected char '='" },
			{ input = "@", error_msg = "expected char '='" },
			{ input = "@=my-host", error_msg = "an empty key" },
			{ input = "@host=", error_msg = "an empty value" },
			{ input = "@host=my\n@host=other", error_msg = "already exist" },
		}

		for _, tc in ipairs(tt) do
			local result = p.prepare_parse(tc.input, 1)
			assert.is_true(result:has_errors())
			assert.are.same(1, #result.errors)
			local err_msg = result.errors[1].message
			assert(err_msg:find(tc.error_msg), err_msg)
		end
	end)
end)

-- ----------------------------------------------
describe("requests:", function()
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
			{ input = "###\nGET http://host", selected = 2, result = { { 2, "GET http://host" } }, readed_lines = 2 },
			{ input = "###\nGET http://host", selected = 1, result = { { 2, "GET http://host" } }, readed_lines = 2 },

			-- more than one request
			{ input = requests, selected = 0, result = nil, readed_lines = 0 },
			{ input = requests, selected = 2, result = { { 2, "GET http://host" } }, readed_lines = 3 },
			{ input = requests, selected = 4, result = { { 5, "GET http://my-host" } }, readed_lines = 5 },
			{ input = requests, selected = 9, result = { { 7, "GET http://other-host" } }, readed_lines = 9 },
		}

		for _, tc in pairs(tt) do
			local result = p.prepare_parse(tc.input, tc.selected)
			assert.is_false(result:has_errors())
			local r = result.result
			assert.are.same(tc.result, r.req_lines)
			assert.are.same(tc.readed_lines, r.readed_lines)
		end
	end)

	it("requests with local variables", function()
		local r = p.prepare_parse(
			[[
###

@host=myhost

GET http://{{host}}
]],
			2
		)
		assert.is_false(r:has_errors())
		assert.are.same({ { 3, "@host=myhost" }, { 5, "GET http://{{host}}" } }, r.result.req_lines)
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
describe("requests with global variables:", function()
	it("find selected requests", function()
		local input = [[

@host= myhost
@port= 8080

###

GET http://{{host}}:{{port}}


###
GET http://new-host
]]
		local r = p.prepare_parse(input, 6)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same({ ["host"] = "myhost", ["port"] = "8080" }, result.global_variables)
		assert.are.same({ { 7, "GET http://{{host}}:{{port}}" } }, result.req_lines)
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
		local r = p.prepare_parse(input, 6)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same({ ["host"] = "myhost" }, result.global_variables)
		assert.are.same({
			{ 5, "@port= 8080" },
			{ 7, "GET http://{{host}}:{{port}}" },
			{ 10, 'filter = id = "42" ' },
		}, result.req_lines)
		assert.are.same(12, result.readed_lines)
	end)
end)

-- ----------------------------------------------
describe("create a request:", function()
	it("substitute global and local variables", function()
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
		local r = p.parse(input, 5)

		assert.is_false(r:has_errors())
		local result = r.result

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

	it("substitute global variables", function()
		local input = [[
@host= myhost
@port= 8080
@full_name={{host}}:{{port}}

###
GET http://{{full_name}}

]]
		local r = p.parse(input, 5)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same({
			req = {
				method = "GET",
				url = "http://myhost:8080",
				query = {},
				headers = {},
			},
		}, result)
	end)

	it("substitute local variables", function()
		local input = [[
@host= myhost
@port= 8080

###

@full_name={{host}}:{{port}}

GET http://{{full_name}}

]]
		local r = p.parse(input, 5)

		assert.is_false(r:has_errors())
		local result = r.result

		assert.are.same({
			req = {
				method = "GET",
				url = "http://myhost:8080",
				query = {},
				headers = {},
			},
		}, result)
	end)

	it("define double query", function()
		local input = [[
###
GET http://host

foo=bar
foo=baz
]]
		local r = p.parse(input, 3)

		assert.is_true(r:has_errors())
		assert.are.same(1, #r.errors)
		local err_msg = r.errors[1].message
		assert(err_msg:find("'foo' already exist"))
	end)

	it("define double headers", function()
		local input = [[
###
GET http://host

foo:bar
foo:baz
]]
		local r = p.parse(input, 3)

		assert.is_true(r:has_errors())
		assert.are.same(1, #r.errors)
		local err_msg = r.errors[1].message
		assert(err_msg:find("'foo' already exist"))
	end)
end)
