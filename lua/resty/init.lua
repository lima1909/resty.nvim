local M = {}

local curl = require("plenary.curl")
local parser = require("resty.parser")

--[[

### test aa
Get https://jsonplaceholder.typicode.com/comments

id=2

---

]]

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local definitions = parser.parse(lines)

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local found_def

	for name, def in pairs(definitions) do
		if def.start_at <= row and def.end_at >= row then
			found_def = name
			break
		end
	end

	local def = definitions[found_def]
	assert(def, "The cursor pointed not to a valid request")

	-- local response = curl.request(def.req)
	-- assert(response.status == 200, "Expect status code 200, got: " .. response.status)
	-- print(vim.inspect(response))

	return curl.request(def.req)
end

-- M.run()

return M
