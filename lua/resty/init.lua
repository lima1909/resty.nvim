local parser = require("resty.parser")
local exec = require("resty.exec")
local response = require("resty.response")

local M = {}

_Last_req_def = nil

_G._resty_show_response = function(selection)
	M.output:show(selection)
end

local exec_and_show_response = function(req_def)
	local result = exec.curl(req_def)
	_Last_req_def = req_def

	M.output = response.new(req_def, result)
	M.output:show()
end

M.last = function()
	if _Last_req_def then
		exec_and_show_response(_Last_req_def)
	else
		error("No last request found. Run first [Resty run]")
	end
end

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local req_def = parser.parse(lines, row)

	exec_and_show_response(req_def)
end

M.diagnostic = function()
	local bufnr = 0
	local ns = vim.api.nvim_create_namespace("resty_diagnostics")
	local diagnostics = {
		{
			col = 0,
			lnum = 5,
			severity = vim.diagnostic.severity.WARN,
			message = "My custom diagnostic message",
		},
		{
			col = 0,
			lnum = 6,
			severity = vim.diagnostic.severity.INFO,
			message = "Info from me",
		},
	}
	vim.diagnostic.set(ns, bufnr, diagnostics)
end

--[[ M.view = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local req_defs = parser.parse(lines)

	-- load the view and execute the selection
	require("resty.select").view({}, req_defs.definitions, function(def)
		exec_and_show_response(def)
	end)
end ]]

return M
