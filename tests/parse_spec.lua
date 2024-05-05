describe("parser", function()
	local p = require("resty.parser")
	local assert = require("luassert")

	it("parse one", function()
		local input = [[
### first test
Get https://httpbin.org/get 

accept: application/json  
Authorization: Bearer mytoken123

]]

		local result = p.parse(input)
		print(vim.inspect(result))
		assert.are.same(result.first_test, {
			start_at = 1,
			method = "GET",
			url = "https://httpbin.org/get",
			header = { "accept: application/json", "Authorization: Bearer mytoken123" },
		})
	end)
end)
