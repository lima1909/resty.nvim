describe("curl", function()
	-- https://github.com/nvim-lua/plenary.nvim/blob/master/tests/plenary/curl_spec.lua
	local curl = require("plenary.curl")
	local assert = require("luassert")

	it("curl ge", function()
		local url = "https://httpbin.org/get"
		url = "https://api-101.glitch.me/customer?id=1"
		url = "https://jsonplaceholder.typicode.com/comments" -- ?postId=1"
		-- url = "https://api.restful-api.dev/objects?id=3&id=5&id=10"

		local query = { postId = 1 }

		local res = curl.request({
			url = url,
			method = "GET",
			query = query,
		}, { headers = {
			content_type = "application/xml",
		} })
		-- assert.are.same(200, res.status)
		print(vim.inspect(res.body))
	end)
end)
