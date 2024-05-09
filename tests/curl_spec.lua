describe("curl:", function()
	-- https://github.com/nvim-lua/plenary.nvim/blob/master/tests/plenary/curl_spec.lua
	local curl = require("plenary.curl")
	local assert = require("luassert")
	local p = require("resty.parser")

	it("simple GET request", function()
		local input = [[
### simple get 
Get https://httpbin.org/get 

]]

		local def = p.parse(input).simple_get
		local response = curl.request(def.req)
		assert.are.same(200, response.status)
	end)
end)
