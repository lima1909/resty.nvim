local M = {}

-- returns the next NOT blank or commented line
--
function M:_next_not_ignored_line()
	local len = #self.lines
	for i = self.cursor, len do
		local line = self.lines[i]

		-- ignore this lines
		if #line == 0 or line:sub(1, 1) == "#" or line:match("^%s") then
			self.cursor = i + 1
		else
			return line
		end
	end

	return nil
end

--- One previewed line, without increment the cursor
---
---@return string|nil line: the line or nil
function M:peek()
	self:_next_not_ignored_line()
	return self.lines[self.cursor]
end

--- Reads the next not empty or commented line and check the type
---
---@param check function check the line contains the desired type
---@return string|nil line: if nil, this is the end of the lines
---@return boolean check_ok: false: it not the searched line; true: find the correct line
function M:next(check)
	local line = self:_next_not_ignored_line()
	if not line then
		return nil, false
	end

	if check(line) == false then
		return line, false
	end

	-- cut comment from the current line
	local pos = string.find(line, "#")
	if pos then
		line = line:sub(1, pos - 1)
	end

	self.cursor = self.cursor + 1
	return line, true
end

function M.new(input)
	local u = require("resty.util")
	M.lines = u.input_to_lines(input)
	M.cursor = 1

	return M
end

return M
