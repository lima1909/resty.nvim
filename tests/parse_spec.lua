describe("parse:", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("empty request", function()
		local input = [[
		]]

		local result = p.parse(input)
		assert.are.same(result.definitions, {})
	end)

	it("only name for request", function()
		local input = [[
### test
		]]

		local status, err = pcall(p.parse, input)
		assert(not status)
		assert(err:find("expected two parts:"))
	end)

	it("one request", function()
		local input = [[
### first test
Get https://httpbin.org/get 

accept: application/json  
Authorization: Bearer mytoken123

filter = id = "42" and age > 42
include = sub, *  

]]

		local req_def_list = p.parse(input)
		local req_def = req_def_list:get_req_def_by_row(2)
		assert.are.same(req_def, {
			start_at = 1,
			end_at = 10,
			name = "first_test",
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {
					accept = "application/json",
					Authorization = "Bearer mytoken123",
				},
				query = {
					filter = 'id = "42" and age > 42',
					include = "sub, *",
				},
			},
		})
	end)

	it("no name request", function()
		local input = [[
### 
Get https://httpbin.org/get 

]]

		local result = p.parse(input)
		assert.are.same(result.definitions[1], {
			start_at = 1,
			end_at = 4,
			name = "noname_1",
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("more chars after the request", function()
		local input = [[
### req
Get https://httpbin.org/get 

---

head:val

query=val

]]

		local result = p.parse(input)
		assert.are.same(result.definitions[1], {
			start_at = 1,
			end_at = 3,
			name = "req",
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("spaces between method and url", function()
		local input = [[
### spaces
GET   https://jsonplaceholder.typicode.com/comments
 
---
]]

		local result = p.parse(input)
		assert.are.same(result.definitions[1], {
			start_at = 1,
			end_at = 3,
			name = "spaces",
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})
	end)

	it("header with eq char", function()
		local input = [[
### eq_char
GET   https://jsonplaceholder.typicode.com/comments

foo: bar=
]]

		local req_def_list = p.parse(input)
		local req_def = req_def_list:get_req_def_by_row(2)
		assert.are.same(req_def, {
			start_at = 1,
			end_at = 5,
			name = "eq_char",
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = { foo = "bar=" },
				query = {},
			},
		})
	end)

	it("multi reqest definitions", function()
		local input = [[
### first
GET   https://jsonplaceholder.typicode.com/comments

### second
GET https://httpbin.org/get 

]]

		local req_def_list = p.parse(input)
		local req_def = req_def_list:get_req_def_by_row(2)
		assert.are.same(req_def, {
			start_at = 1,
			end_at = 3,
			name = "first",
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})

		req_def = req_def_list:get_req_def_by_row(5)
		assert.are.same(req_def, {
			start_at = 4,
			end_at = 7,
			name = "second",
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)

	it("request with comments", function()
		local input = [[
### with comments
GET   https://jsonplaceholder.typicode.com/comments

#foo: bar
# foo: bar

# foo = bar
#foo = bar
]]

		local req_def_list = p.parse(input)
		local req_def = req_def_list:get_req_def_by_row(2)
		assert.are.same(req_def, {
			start_at = 1,
			end_at = 9,
			name = "with_comments",
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})
	end)

	it("replace variable", function()
		local r = require("resty.request")
		local variables = { ["host"] = "my-host" }

		local tt = {
			-- input = output (expected)
			{ input = "host}}" },
			{ input = "host}" },
			{ input = "{{host" },
			{ input = "{host" },
			{ input = "{host}" },
			-- throw an error? an non known variable FOO
			{ input = "{{FOO}}" },
			-- valid replace cases
			{ input = "{{host}}", expected = "my-host" },
			{ input = "http://{{host}}", expected = "http://my-host" },
			{ input = "{{host}}.de", expected = "my-host.de" },
			{ input = "http://{{host}}.de", expected = "http://my-host.de" },
		}

		for _, tc in ipairs(tt) do
			local property = r.replace_variable(variables, tc.input)
			if tc.expected then
				assert.are.same(tc.expected, property)
			else
				assert.are.same(tc.input, property)
			end
		end
	end)

	it("request with variable", function()
		local input = [[
@hostname =httpbin.org
@port = 1234
@host= @hostname:@port

### with_var
Get https://{{hostname}}/get

]]

		local req_def_list = p.parse(input)
		assert.are.same(
			req_def_list.variables,
			{ ["hostname"] = "httpbin.org", ["port"] = "1234", ["host"] = "@hostname:@port" }
		)

		local req_def = req_def_list:get_req_def_by_row(7)
		assert.are.same(req_def, {
			start_at = 5,
			end_at = 8,
			name = "with_var",
			req = {
				method = "GET",
				url = "https://httpbin.org/get",
				headers = {},
				query = {},
			},
		})
	end)
end)
