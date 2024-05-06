Run = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), true)
	-- ### my
	return lines
end

print(vim.inspect(Run()))
