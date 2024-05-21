local parser = require("resty.parser")
local exec = require("resty.exec")
local output = require("resty.output")

local M = {}

_Last_req_def = nil

local exec_and_show_response = function(req_def)
	local response, milliseconds = exec.curl(req_def)
	_Last_req_def = req_def

	output.show_response(req_def, response, milliseconds)
end

M.last = function()
	if _Last_req_def then
		exec_and_show_response(_Last_req_def)
	else
		error("No last request found. Run first [Resty run]")
	end
end

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local definitions = parser.parse(lines)

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local found_def

	for _, d in pairs(definitions) do
		if d.start_at <= row and d.end_at >= row then
			found_def = d
			break
		end
	end

	assert(found_def, "The cursor position: " .. row .. " is not in a valid range for a request definition")

	exec_and_show_response(found_def)
end

M.view = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local req_defs = parser.parse(lines)

	-- load the view and execute the selection
	require("resty.select").view({}, req_defs, function(def)
		exec_and_show_response(def)
	end)
end

return M
