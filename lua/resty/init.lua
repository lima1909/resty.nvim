local M = {}

local curl = require("plenary.curl")
local parser = require("resty.parser")

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local definitions = parser.parse(lines)

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local found_def

	for name, d in pairs(definitions) do
		if d.start_at <= row and d.end_at >= row then
			found_def = name
			break
		end
	end

	local def = definitions[found_def]
	assert(def, "The cursor pointed not to a valid request definition")

	return curl.request(def.req)
end

return M
