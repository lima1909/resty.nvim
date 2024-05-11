local M = {}

local curl = require("plenary.curl")
local parser = require("resty.parser")

local function create_buffer()
	local buf = vim.api.nvim_create_buf(true, true)
	-- vim.api.nvim_buf_set_name(buf, "Resty.http")
	vim.api.nvim_set_option_value("filetype", "http", { buf = buf })
	return buf
end

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

	local response = curl.request(def.req)
	local body = vim.split(response.body, "\n")
	-- print(vim.inspect(response))

	local buf = create_buffer()

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "STATUS: " .. response.status })
	vim.api.nvim_buf_set_lines(buf, 1, -1, false, response.headers)
	-- vim.api.nvim_buf_set_lines(buf, #response.headers + 2, -1, false, { "EXIT: " .. response.exit })

	local line_nr = vim.api.nvim_buf_line_count(buf)
	for i, r in ipairs(body) do
		vim.api.nvim_buf_set_lines(buf, line_nr + i, -1, false, { r })
	end

	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
end

return M
