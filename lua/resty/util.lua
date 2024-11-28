local M = {}

M.input_to_lines = function(input)
	if type(input) == "table" then
		return input
	elseif type(input) == "string" then
		return vim.split(input, "\n")
	else
		error("only string or string array are supported as input. Got: " .. type(input), 0)
	end
end

M.get_lines_and_row_from_current_buf = function(bufnr)
	bufnr = bufnr or 0

	local start_line = vim.fn.getpos("'<")[2] -- 2 = line number, 3 = columns number
	vim.fn.setpos("'<", { 0, 0, 0, 0 }) -- reset the start pos

	local lines, row

	-- VISUAL mode
	if start_line > 0 then
		local end_line = vim.fn.getpos("'>")[2]
		vim.fn.setpos("'>", { 0, 0, 0, 0 }) -- reset
		lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
		row = 1
	-- NORMAL mode
	else
		local winnr = vim.api.nvim_get_current_win()
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
		row = vim.api.nvim_win_get_cursor(winnr)[1]
	end

	return lines, row
end

M.split_string_into_lines = function(str)
	local lines = {}
	for line in str:gmatch("[^\n]+") do
		table.insert(lines, line)
	end
	return lines
end

-- M.show_debug_info = function()
-- 	-- local winnr = vim.api.nvim_get_current_win()
-- 	-- local row = vim.api.nvim_win_get_cursor(winnr)[1]
-- 	-- local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
--
-- 	local lines, row = M.get_lines_and_row_from_current_buf()
-- 	local result = require("resty.parser").parse(lines, row)
--
-- 	local str = vim.inspect(result)
-- 	local result_lines = M.split_string_into_lines(str)
--
-- 	local buf = vim.api.nvim_create_buf(false, true)
-- 	vim.api.nvim_buf_set_lines(buf, 0, -1, false, result_lines)
--
-- 	local width = vim.api.nvim_get_option("columns")
-- 	local height = vim.api.nvim_get_option("lines")
--
-- 	local win_width = math.ceil(width * 0.5)
-- 	local win_height = math.ceil(height * 0.8)
-- 	local wrow = math.ceil(1 * 0.5) - 1
-- 	-- local col = math.ceil((width - win_width) * 0.5)
-- 	local wcol = math.ceil(width * 0.5)
--
-- 	local win = vim.api.nvim_open_win(buf, false, {
-- 		relative = "editor",
-- 		width = win_width,
-- 		height = win_height,
-- 		row = wrow,
-- 		col = wcol,
-- 		style = "minimal",
-- 		border = "single",
-- 	})
-- 	vim.api.nvim_set_current_win(win)
--
-- 	vim.api.nvim_buf_set_keymap(
-- 		buf,
-- 		"n",
-- 		"q",
-- 		":lua vim.api.nvim_win_close(" .. win .. ", true)<CR>",
-- 		{ noremap = true, silent = true }
-- 	)
-- 	vim.api.nvim_buf_set_keymap(
-- 		buf,
-- 		"n",
-- 		"<Esc>",
-- 		":lua vim.api.nvim_win_close(" .. win .. ", true)<CR>",
-- 		{ noremap = true, silent = true }
-- 	)
-- end
--
M.read_file = function(path)
	local fd = vim.loop.fs_open(path, "r", 438)
	if not fd then
		error("File not found: " .. path, 0)
	end

	local stat = vim.loop.fs_fstat(fd)
	local content = vim.loop.fs_read(fd, stat.size, 0)
	vim.loop.fs_close(fd)

	return content
end

return M
