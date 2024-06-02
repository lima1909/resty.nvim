describe("parse:", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("error for empty input", function()
		local input = [[
		]]

		local _, err = pcall(p.parse, input, 1)
		assert(err:find("no request found"))
	end)

	it("error for empty request", function()
		local input = [[
### 
		]]

		local _, err = pcall(p.parse, input, 1)
		assert(err:find("expected two parts: method and url"))
	end)

	it("one request", function()
		local input = [[
### 
Get https://httpbin.org/get 

accept: application/json  
Authorization: Bearer mytoken123

filter = id = "42" and age > 42
include = sub, *  

]]

		local result = p.parse(input, 2)
		assert.are.same(result, {
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

		local result = p.parse(input, 1)
		assert.are.same(result, {
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
### 
Get https://httpbin.org/get 

---

head:val

query=val

]]

		local result = p.parse(input, 1)
		assert.are.same(result, {
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
### 
GET   https://jsonplaceholder.typicode.com/comments
 
---
]]

		local result = p.parse(input, 1)
		assert.are.same(result, {
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
### 
GET   https://jsonplaceholder.typicode.com/comments

foo: bar=
]]

		local result = p.parse(input, 2)
		assert.are.same(result, {
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
### 
GET   https://jsonplaceholder.typicode.com/comments

### 
GET https://httpbin.org/get 

]]

		local result = p.parse(input, 2)
		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})

		result = p.parse(input, 5)
		assert.are.same(result, {
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
### 
GET   https://jsonplaceholder.typicode.com/comments

#foo: bar
# foo: bar

# foo = bar
#foo = bar
]]

		local result = p.parse(input, 2)
		assert.are.same(result, {
			req = {
				method = "GET",
				url = "https://jsonplaceholder.typicode.com/comments",
				headers = {},
				query = {},
			},
		})
	end)

	it("replace variable", function()
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
			local property = p.replace_variable(variables, tc.input)
			if tc.expected then
				assert.are.same(tc.expected, property)
			else
				assert.are.same(tc.input, property)
			end
		end
	end)
end)
