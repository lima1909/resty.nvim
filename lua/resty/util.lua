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
