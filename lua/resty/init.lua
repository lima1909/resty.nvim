P = function(tab)
	print(vim.inspect(tab))
end

local parser = require("resty.parser")
local f = require("resty.parser.favorite")
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
	local start_line = vim.fn.getpos("'<")[2] -- 2 = line number, 3 = columns number
	vim.fn.setpos("'<", { 0, 0, 0, 0 }) -- reset the start pos

	-- VISUAL mode
	if start_line > 0 then
		local end_line = vim.fn.getpos("'>")[2]
		vim.fn.setpos("'>", { 0, 0, 0, 0 }) -- reset
		local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
		M._run(lines)
	-- NORMAL mode
	else
		local winnr = vim.api.nvim_get_current_win()
		local row = vim.api.nvim_win_get_cursor(winnr)[1]
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
		M._run(lines, row)
	end
end

M.favorite = function(favorite, bufnr)
	bufnr = f.get_current_bufnr(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

	if favorite then
		local row = f.find_favorite(lines, favorite)
		if row then
			M._run(lines, row)
		else
			print("Favorite: '" .. favorite .. "' not found", 0)
		end
	else
		local favorites = f.find_all_favorites(lines)
		print("Favorites: " .. vim.inspect(favorites))
	end
end

M._run = function(lines, row)
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
