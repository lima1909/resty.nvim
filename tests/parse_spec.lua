describe("parse:", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("one request definition", function()
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
		})
	end)
end)
