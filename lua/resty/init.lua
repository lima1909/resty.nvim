local parser = require("resty.parser")
local exec = require("resty.exec")
local response = require("resty.response")

local M = {
	ns_diagnostics = vim.api.nvim_create_namespace("resty_diagnostics"),
}

_Last_parser_result = nil

_G._resty_show_response = function(selection)
	M.output:show(selection)
end

local show_diagnostic_if_occurs = function(parser_result)
	local bufnr = 0
	vim.diagnostic.reset(M.ns_diagnostics, bufnr)

	if parser_result:has_errors() then
		vim.diagnostic.set(M.ns_diagnostics, bufnr, parser_result.errors)
		return true
	end

	return false
end

local exec_and_show_response = function(parser_result)
	if show_diagnostic_if_occurs(parser_result) then
		return
	end

	local req_def = parser_result.result
	local result = exec.curl(req_def)

	_Last_parser_result = parser_result

	M.output = response.new(req_def, result)
	M.output:show()
end

M.last = function()
	if _Last_parser_result then
		exec_and_show_response(_Last_parser_result)
	else
		error("No last request found. Run first [Resty run]")
	end
end

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local parser_result = parser.parse(lines, row)

	exec_and_show_response(parser_result)
end

M.diagnostic = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local parser_result = parser.parse(lines, row)

	if show_diagnostic_if_occurs(parser_result) then
		return
	end

	print("No parser errors found ;-)")
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
