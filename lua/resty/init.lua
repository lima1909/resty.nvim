local parser = require("resty.parser")
local exec = require("resty.exec")
local output = require("resty.response")

local M = {}

_Last_req_def = nil

local exec_and_show_response = function(req_def)
	local response = exec.curl(req_def)
	_Last_req_def = req_def

	M.response = output.new(req_def, response)
	M.response:show()
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
	local found_def = definitions:get_req_def_by_row(row)

	assert(found_def, "The cursor position: " .. row .. " is not in a valid range for a request definition")

	exec_and_show_response(found_def)
end

M.view = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local req_defs = parser.parse(lines)

	-- load the view and execute the selection
	require("resty.select").view({}, req_defs.definitions, function(def)
		exec_and_show_response(def)
	end)
end

_G._resty_show_response = function(selection)
	M.response:show(selection)
end

return M
