describe("parse:", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("empty request", function()
		local input = [[
		]]

		local result = p.parse(input)
		assert.are.same(result, {})
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

		local result = p.parse(input)
		assert.are.same(result[1], {
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
		assert.are.same(result[1], {
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
		assert.are.same(result[1], {
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
		assert.are.same(result[1], {
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

		local result = p.parse(input)
		assert.are.same(result[1], {
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

		local result = p.parse(input)
		assert.are.same(result[1], {
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
		assert.are.same(result[2], {
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
end)
