local M = {}

local curl = require("plenary.curl")
local parser = require("resty.parser")

--[[

### test
Get https://httpbin.org/get 

---

]]

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)

	local definitions = parser.parse(lines)
	-- print(vim.inspect(definitions))
	local def = definitions.test -- TODO: change the name 'test' to the parsed name

	local response = curl.request(def.req)
	assert(response.status == 200, "Expect status code 200, got: " .. response.status)
	print(vim.inspect(response))
end

-- M.run()

return M
