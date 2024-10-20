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

-- change with: ':let g:resty.diagnostics = v:false'
-- print current value: ':lua print(vim.g.resty.diagnostics)'
vim.g.resty = { diagnostics = true, completion = true, variables_preview = true }

local M = {
	output = output.new(default_config),
	config = default_config,
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

M.run = function(input)
	if input and input:len() > 0 then
		M._run(input)
		return
	end

	local start_line = vim.fn.getpos("'<")[2] -- 2 = line number, 3 = columns number
	vim.fn.setpos("'<", { 0, 0, 0, 0 }) -- reset the start pos

	-- VISUAL mode
	if start_line > 0 then
		local end_line = vim.fn.getpos("'>")[2]
		vim.fn.setpos("'>", { 0, 0, 0, 0 }) -- reset
		local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
		M._run(lines, 1, 0)
	-- NORMAL mode
	else
		local winnr = vim.api.nvim_get_current_win()
		local row = vim.api.nvim_win_get_cursor(winnr)[1]
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
		M._run(lines, row, 0)
	end
end

-- check, is telescope installed for viewing favorites
local has_telescope = pcall(require, "telescope")
local f = require("resty.extension.favorites")

M.favorite = function(favorite, bufnr)
	-- bufnr = f.get_current_bufnr(bufnr)
	bufnr = bufnr or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

	if favorite and #favorite > 0 then
		local row = f.find_favorite(lines, favorite)
		if row then
			M._run(lines, row, bufnr)
		else
			error("Favorite: '" .. favorite .. "' not found", 0)
		end
	elseif has_telescope then
		local favorites = f.find_all_favorites(lines)
		require("resty.extension.favorites_view").show(favorites, lines, function(row)
			M._run(lines, row, bufnr)
		end)
	else
		error("For this action you must install: 'telescope.nvim'", 0)
	end
end

M._run = function(lines, row, bufnr)
	local result = parser.parse(lines, row)
	if diagnostic.check_errors(bufnr, result) then
		return
	end

	-- save the last result
	M.last_parser_result = result
	M.output:exec_and_show_response(M.last_parser_result)
end

--[[
package.loaded["resty"] = nil
package.loaded["resty.output"] = nil
package.loaded["resty.output.winbar"] = nil
]]

return M
