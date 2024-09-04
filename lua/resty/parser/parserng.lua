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

M.with_blank_lines = { ignore_blank_lines = false }

M.ignore_line = function(line, opts)
	if vim.startswith(line, "#") then
		return true
	elseif not opts or opts.ignore_blank_lines == true then
		local m = line:match("^%s*$")
		return m ~= nil and #m >= 0
	else
		return false
	end
end

M.line_iter = function(lines, cursor)
	local iter = {
		cursor = cursor or 1,
		lines = lines,

		next = function(self, check, opts)
			local line = self.lines[self.cursor]
			if not line then
				return nil, false
			end

			while M.ignore_line(line, opts) do
				self.cursor = self.cursor + 1
				line = self.lines[self.cursor]
				if not line then
					return nil, false
				end
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
		end,
	}

	return setmetatable(iter, { __index = iter })
end

function M.parse_variable(iter)
	local variables = {}

	while true do
		local line, is_variable = iter:next(function(line)
			return vim.startswith(line, "@")
		end)
		-- end of lines and no variables
		if not line or is_variable == false then
			return line, variables
		end

		-- cut the variable token
		line = string.sub(line, 2)
		local parts = vim.split(line, "=")
		local k = parts[1]
		if not k then
			error("an empty variable name is not allowed: '" .. line .. "'", 0)
		end
		local v = parts[2]
		if not v then
			error("an empty variable value is not allowed: '" .. line .. "'", 0)
		end

		-- CHECK duplicate
		-- if variables[vim.trim(k)] then
		-- error("the variable key: '" .. key .. "' already exist")
		-- end

		variables[vim.trim(k)] = vim.trim(v)
	end
end

function M.parse_method_url(iter)
	local line, is_mu = iter:next(function(l)
		l = string.gsub(l, "^%s+", "") -- trim the spaces in the start
		return l:find(" ") ~= nil
	end)
	-- end of lines and no variables
	if not line or is_mu == false then
		return line, nil
	end

	local parts = vim.split(line, " ")
	if #parts < 2 then
		error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line, 0)
	end

	local method = vim.trim(parts[1])
	if not method:match("^[%aZ]+$") then
		error("invalid method name: '" .. method .. "'. Only letters are allowed", 0)
	end

	return line, {
		method = method:upper(),
		url = vim.trim(parts[2]),
	}
end

function M.parse_headers_query(iter)
	local query = {}
	local headers = {}

	while true do
		local line, is_hq = iter:next(function(l)
			if vim.startswith(l, "{") or vim.startswith(l, "--{%") then
				return false
			end

			return l:match("^[%aZ]+-[%aZ]+:") or l:match("^[%aZ]+-[%aZ]+=")
		end)

		-- end of lines and no variables
		if not line or is_hq == false then
			return line, headers, query
		end

		print("HQ: " .. line)
		return line, headers, query
	end
end

-- parse definition:
--	return not processed line and current selected json
--	line == nil -> no more lines left
--	json == nil -> no json found
M.parse_json = function(iter)
	local line, is_json = iter:next(function(line)
		return vim.startswith(line, "{")
	end)
	if not line or is_json == false then
		return line, nil
	end

	local json = ""
	while true do
		json = json .. line

		line, is_json = iter:next(function(l)
			-- is not blank line
			return l:match("%S") ~= nil
		end, M.with_blank_lines)
		if not line or is_json == false then
			return line, json
		end
	end
end

function M.parse(iter)
	local parse = {}
	local line

	line, parse.variables = M.parse_variable(iter)
	if not line then
		return
	end

	line, parse.request = M.parse_method_url(iter)
	if not line then
		return
	end

	line, parse.request.headers, parse.request.query = M.parse_headers_query(iter)
	if not line then
		return
	end

	line, parse.request.body = M.parse_json(iter)
	if not line then
		return
	end

	return parse
end

return M
