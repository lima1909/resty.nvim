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

filter = id = 42 and age > 42
include = sub, *  

]]

		local result = p.parse(input)
		assert.are.same(result.first_test, {
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
					filter = "id = 42 and age > 42",
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
		assert.are.same(result.noname_1, {
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
		assert.are.same(result.req, {
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
end)
