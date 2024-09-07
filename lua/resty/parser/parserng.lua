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
--[[

| input           | starts with                                                    |
|-----------------|----------------------------------------------------------------|
| delimiter       | ### (optional)                                                 |
| comments        | # (optional)                                                   |


* variable        
  - start: with @ (optional)
  - end: not @
* method_url      
  - start: after variable or first, starts with a letter, and 2 or 3 parts 
  - end: only one line
* header or query 
  - start: after method_url, starts with a letter, contains : or = 
  - end: } (json_body), --%} (script_body), END
* json body        
  - start: {
  - end: }        
* script body     
  - start: --{% 
  - end: --%} 


* ignore lines
  - comments (delimiters)
  - blank lines

1) while is_variable  
2) method_url (one line)
3) json_body | script_body | header_query 
	-> header_query -> while header_query -> json_body | script_body | END
	-> json_body    -> while json_body    -> script_body | END
	-> script_body  -> while script_body  -> END


]]
local M = {}

M.Json = {
	start = function(line)
		return line:sub(1, 1) == "{" and #line == 1
	end,
	stop = function(line)
		return line:sub(1, 1) ~= "}"
	end,
	end_line = "}",
}

M.Script = {
	start = function(line)
		return line:sub(1, 4) == "--{%" and #line == 4
	end,
	stop = function(line)
		return line:sub(1, 4) ~= "--%}"
	end,
	end_line = "--%}",
}

local u = require("resty.util")

M.check_type = function(input, linenr)
	local lines = u.input_to_lines(input)
	local line = lines[linenr]

	if not line then
		error("line number: " .. linenr .. " is not valid. Max number is: " .. #lines, 0)
	end

	M.line_iter({ line })
end

function M.parse(input)
	local lines = u.input_to_lines(input)
	local iter = M.line_iter(lines, 1)

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

	local peek = iter:peek()
	-- no more lines
	if not peek then
		return parse
	end

	-- json_body
	if M.Json.start(peek) then
		line, parse.request.body = M.parse_body(iter, M.Json)
		if not line then
			return parse
		end
	-- script_body
	elseif M.Script.start(peek) then
		line, parse.request.script = M.parse_body(iter, M.Script)
		if not line then
			return parse
		end
	-- header_query
	else
		print("- header_query: ")
		-- header_query
	end

	-- line, parse.request.headers, parse.request.query = M.parse_headers_query(iter)
	-- if not line then
	-- 	return
	-- end
	--
	-- line, parse.request.body = M.parse_json(iter)
	-- if not line then
	-- 	return
	-- end

	return parse
end

M.line_iter = function(lines, cursor)
	local iter = {
		cursor = cursor or 1,
		lines = lines,

		-- returns the next NOT blank or comment line
		--
		next_not_ignored_line = function(self)
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
		end,

		-- read the one preview line
		--
		peek = function(self)
			self:next_not_ignored_line()
			return self.lines[self.cursor]
		end,

		-- next not ignored line
		--   - line == nil, this is the end of the lines
		--   - false, it not the searched line
		--   - true find the correct line
		next = function(self, check)
			local line = self:next_not_ignored_line()
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
		end,
	}

	return setmetatable(iter, { __index = iter })
end

function M.parse_variable(iter)
	local variables = {}

	local check = function(l)
		return l:sub(1, 1) == "@"
	end

	while true do
		local line, is_variable = iter:next(check)
		-- end of lines and no variables
		if not line or is_variable == false then
			return line, variables
		end

		-- cut the variable token
		line = string.sub(line, 2)
		local parts = line:gmatch("([^=]+)")
		local k = parts()
		if not k then
			error("an empty variable name is not allowed: '" .. line .. "'", 0)
		end
		local v = parts()
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
		-- l = string.gsub(l, "^%s+", "") -- trim the spaces in the start
		-- return l:find(" ") ~= nil
		--
		-- first char is a letter
		local first_char = l:sub(1, 1)
		local letter = (first_char >= "A" and first_char <= "Z") or (first_char >= "a" and first_char <= "z")
		return letter
		-- return l:match("^[%aZ]")
	end)

	-- end of lines and no variables
	if not line or is_mu == false then
		return line, nil
	end

	local parts = line:gmatch("([^ ]+)")
	-- if #parts < 2 then
	-- 	error("expected two parts: method and url (e.g: 'GET http://foo'), got: " .. line, 0)
	-- end

	local method = vim.trim(parts())
	if not method:match("^[%aZ]+$") then
		error("invalid method name: '" .. method .. "'. Only letters are allowed", 0)
	end

	local url = vim.trim(parts())
	if url:sub(1, 4) == "http" == false then
		error("invalid url: '" .. url .. "'. Must staret with 'http'", 0)
	end

	return line, {
		method = method:upper(),
		url = url,
	}
end

function M.parse_headers_query(iter)
	local query = {}
	local headers = {}

	while true do
		Is_headers = false

		local line, is_hq = iter:next(function(l)
			if l:sub(1, 1) == "{" or vim.startswith(l, "--{%") then
				return false
			elseif l:match("^([%w%-]+):") then
				Is_headers = true
				return true
			elseif l:match("([%w%-_%.]+)=") then
				return true
			else
				return false
			end
		end)

		-- end of lines and no variables
		if not line or is_hq == false then
			return line, headers, query
		end

		print(line .. " | " .. tostring(Is_headers))
		-- return line, headers, query
	end
end

-- parse definition:
--	return not processed line and current selected json
--	line == nil -> no more lines left
--	json == nil -> no json found
M.parse_body = function(iter, body)
	local line, is_body = iter:next(body.start)
	if not line or is_body == false then
		return line, nil
	end

	local body_str = ""
	while true do
		body_str = body_str .. line

		line = iter.lines[iter.cursor]
		if not line then
			-- error("parsing body hast started, but not ended: " .. body_str, 0)
			return line, body_str
		elseif line.sub(1, #body.end_line) == body.end_line then
			return line, body_str .. line
		else
			iter.cursor = iter.cursor + 1
		end
	end
end

return M
