function MyInsertCompletion(findstart, base)
	print("..." .. tostring(findstart))
	if findstart == 1 then
		-- Return the start position for completion
		local line = vim.fn.getline(".")
		local start = vim.fn.col(".") - 1
		while start > 0 and line:sub(start, start):match("%w") do
			start = start - 1
		end
		return start
	else
		-- Return a list of matches
		local suggestions = { "apple", "banana", "cherry", "date", "elderberry" }
		return vim.tbl_filter(function(val)
			return vim.startswith(val, base)
		end, suggestions)
	end
end

-- Set the omnifunc to your custom completion function
vim.bo.omnifunc = "v:lua.MyInsertCompletion"
-- To use the custom completion in insert mode, type: Ctrl-X Ctrl-O
--
--
--

local M = {}

M.skip_line = function(line, skip_blank_line)
	if vim.startswith(line, "#") == true then
		return true
	elseif skip_blank_line == true then
		local m = line:match("^%s*$")
		return m ~= nil and #m >= 0
	end

	return false
end

M.is_blank_line = function(line)
	local m = line:match("^%s*$")
	return m ~= nil and #m >= 0
end

M.line_iter = function(lines, cursor)
	local iter = {
		cursor = cursor or 1,
		lines = lines,

		-- returns the current line or nil, if no more lines left
		-- skips all lines, which starts with a comment char or ignore blank lines, if the option is set
		current_line = function(self, skip_blank_line)
			local line = self.lines[self.cursor]
			if not line then
				return nil
			end

			while vim.startswith(line, "#") == true or (skip_blank_line and skip_blank_line(line) == true) do
				self.cursor = self.cursor + 1
				line = self.lines[self.cursor]
				if not line then
					return nil
				end
			end

			-- cut comment from the current line
			local pos = string.find(line, "#")
			if pos then
				line = line:sub(1, pos - 1)
			end

			return line
		end,

		next = function(self, skip_blank_line)
			self.cursor = self.cursor + 1
			return self:current_line(skip_blank_line)
		end,
	}

	return setmetatable(iter, { __index = iter })
end

-- parse definition:
--	return current line and current selected json
--	line == nil -> no more lines left
--	json == nil -> no json found
--
M.parse_json = function(iter)
	local line = iter:current_line(M.is_blank_line)
	-- end of lines and no json
	if not line then
		return nil, nil
	end

	if not vim.startswith(line, "{") then
		-- line, but not a json
		return line, nil
	end

	local json = ""
	while true do
		json = json .. line
		line = iter:next()
		if not line then
			-- no more lines, but a json
			return nil, json
		elseif M.is_blank_line(line) then
			-- more lines and json
			return line, json
		end
	end
end

function M.parse_variable(iter)
	local line = iter:current_line(M.is_blank_line)
	-- end of lines and no variables
	if not line then
		return nil, nil
	end

	local kv = require("resty.parser.key_value")
	local r = kv.parse_variable(line)
	if not r then
		-- line, but not a variable
		return line, nil
	end

	local variables = {}
	while true do
		variables[r.k] = r.v

		line = iter:next(M.is_blank_line)
		if not line then
			-- no more lines, but a json
			return nil, variables
		end

		r = kv.parse_variable(line)
		if not r then
			return line, variables
		end
	end
end

function M.parse_method_url(iter)
	local line = iter:current_line()
	-- end of lines and no variables
	if not line then
		return nil, nil
	end

	local mu = require("resty.parser.method_url")
	local r = mu.parse_method_url(line)
	if not r then
		-- line, but not a variable
		return line, nil
	end

	return iter:next(), r
end

function M.parse(iter)
	local parse = {}
	local line

	line, parse.variables = M.parse_variable(iter)
	line, parse.request = M.parse_method_url(iter)
	line, parse.request.body = M.parse_json(iter)

	return line, parse
end

return M
