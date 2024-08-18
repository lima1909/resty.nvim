P = function(tab)
	print(vim.inspect(tab))
end

local parser = require("resty.parser")
local output = require("resty.output")
local diagnostic = require("resty.diagnostic")

local default_config = {
	output = {
		body_pretty_print = false,
	},
	response = {
		with_folding = true,
		bufname = "resty_response",
	},
}

local M = {
	output = output.new(default_config),
	last_parser_result = nil,
}

M.setup = function(user_configs)
	M.config = vim.tbl_deep_extend("force", default_config, user_configs)
	M.output = output.new(M.config)
end

_G._resty_select_window = function(win_id)
	M.output:select_window(win_id)
end

M.last = function()
	if M.last_parser_result then
		M.output:exec_and_show_response(M.last_parser_result)
	else
		error("No last request found. Run first [Resty run]", 0)
	end
end

M.run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local winnr = vim.api.nvim_get_current_win()
	local row = vim.api.nvim_win_get_cursor(winnr)[1]

	local parser_result = parser.parse(lines, row)
	if diagnostic.show(0, parser_result) then
		return
	end

	-- save the last result
	M.last_parser_result = parser_result
	M.output:exec_and_show_response(M.last_parser_result)
end

--[[ M.view = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	local req_defs = parser.parse(lines)

	-- load the view and execute the selection
	require("resty.select").view({}, req_defs.definitions, function(def)
		exec_and_show_response(def)
	end)
end 



package.loaded["resty"] = nil
package.loaded["resty.output"] = nil
package.loaded["resty.output.winbar"] = nil
	
]]

return M
