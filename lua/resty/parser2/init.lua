local d = require("resty.parser2.delimiter")
local kv = require("resty.parser2.key_value")
local mu = require("resty.parser2.method_url")
local by = require("resty.parser2.body")

local M = {}
M.__index = M

---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
-- local token_END = "---"

--[[ 

* comment and empty line: ignore
* states: start, global_variable, delimiter, method_url, local_variable, headers_query, body, end_req_def
* grammar:

start -> global_variable		* 
	| delimiter			*
	| method_url			*

global_variable -> global_variable	*	
	| delimiter			*

delimiter -> local_variable		*	
	| method_url			*

local_variable -> local_variable	*	
	| method_url			*

method_url-> headers_query		*	
	| body				*
	| end_req_def

headers_query -> headers_query		*	
	| body				*
	| end_req_def

body -> body				*
	| end_req_def

]]

M.STATE_START = 1
M.STATE_GLOBAL_VARIABLE = kv.STATE_GLOBAL_VARIABLE -- 2
M.STATE_LOCAL_VARIABLE = kv.STATE_LOCAL_VARIABLE -- 3
M.STATE_DELIMITER = d.STATE_DELIMITER -- 4
M.STATE_METHOD_URL = mu.STATE_METHOD_URL -- 5
M.STATE_HEADERS_QUERY = kv.STATE_HEADERS_QUERY -- 6
M.STATE_BODY = by.STATE_BODY -- 7

local states = {
	{
		id = M.STATE_START,
		name = "start",
		parse = function(_, _) end,
	},
	{
		id = M.STATE_GLOBAL_VARIABLE,
		name = "global variables",
		parse = function(p, line)
			return kv.parse_global_variable(p, line)
		end,
	},
	{
		id = M.STATE_LOCAL_VARIABLE,
		name = "local variables",
		parse = function(p, line)
			return kv.parse_local_variable(p, line)
		end,
	},
	{
		id = M.STATE_DELIMITER,
		name = "delimiter",
		parse = function(p, line)
			return d.parse_delimiter(p, line)
		end,
	},
	{
		id = M.STATE_METHOD_URL,
		name = "method and url",
		parse = function(p, line)
			return mu.parse_method_url(p, line)
		end,
	},
	{
		id = M.STATE_HEADERS_QUERY,
		name = "header or query",
		parse = function(p, line)
			return kv.parse_headers_query(p, line)
		end,
	},
	{
		id = M.STATE_BODY,
		name = "body",
		parse = function(p, line)
			return by.parse_body(p, line)
		end,
	},
}

local transitions = {
	[M.STATE_START] = { M.STATE_GLOBAL_VARIABLE, M.STATE_DELIMITER, M.STATE_METHOD_URL },
	[M.STATE_GLOBAL_VARIABLE] = { M.STATE_GLOBAL_VARIABLE, M.STATE_DELIMITER, M.STATE_METHOD_URL },
	[M.STATE_DELIMITER] = { M.STATE_LOCAL_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_LOCAL_VARIABLE] = { M.STATE_LOCAL_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_METHOD_URL] = { M.STATE_HEADERS_QUERY, M.STATE_BODY },
	[M.STATE_HEADERS_QUERY] = { M.STATE_HEADERS_QUERY, M.STATE_BODY },
	[M.STATE_BODY] = { M.STATE_BODY },
}

function M:do_transition(line)
	local ts = transitions[self.current_state]
	-- if ts then
	for _, t in ipairs(ts) do
		local s = states[t]
		-- if s then
		if s.parse(self, line) then
			-- self.current_state = t
			return s.id
		end
		-- else
		-- error("no state found for transition" .. t, 0)
		-- end
	end
	--
	-- no valid transition found
	local err = "from current state: '" .. states[self.current_state].name .. "' are only possible: "
	for _, t in ipairs(ts) do
		err = err .. states[t].name .. ", "
	end
	print(err:sub(1, #err - 2))
	-- else
	-- error("for current state: " .. current_state .. "is no transition defiened", 0)
	-- end
end

M.new = function()
	local p = {
		current_state = M.STATE_START,
		readed_lines = 0,
		duration = 0,
		body_is_ready = false,
		variables = {},
		request = {},
		errors = {},
	}
	return setmetatable(p, M)
end

function M:has_errors()
	return self.errors ~= nil and #self.errors > 0
end

function M:add_error(message)
	table.insert(self.errors, {
		col = 0,
		lnum = self.readed_lines,
		severity = vim.diagnostic.severity.ERROR,
		message = message,
	})
	return self
end

function M.ignore_line(line)
	-- comment
	if vim.startswith(line, "#") and not vim.startswith(line, "###") then
		return true
	-- empty line
	elseif line == "" or vim.trim(line) == "" then
		return true
	else
		return false
	end
end

---@param line string
---@return string
function M.cut_comment(line)
	if line:sub(1, 3) == "###" then
		return line
	end

	local pos = string.find(line, "#")
	if not pos then
		return line
	end

	return line:sub(1, pos - 1)
end

---@param variables { }
---@param line string
---@return string | nil, string | nil
function M.replace_variable(variables, line)
	if not variables then
		return line, nil
	end

	local _, start_pos = string.find(line, "{{")
	local end_pos, _ = string.find(line, "}}")

	if not start_pos and not end_pos then
		-- no variable found
		return line, nil
	elseif start_pos and not end_pos then
		-- error
		return nil, "missing closing brackets: '}}'"
	elseif not start_pos and end_pos then
		-- error
		return nil, "missing open brackets: '{{'"
	end

	local before = string.sub(line, 1, start_pos - 2)
	local name = string.sub(line, start_pos + 1, end_pos - 1)
	local after = string.sub(line, end_pos + 2)

	local value = variables[name]
	if not value then
		return nil, "no variable found with name: '" .. name .. "'"
	end

	local new_line = before .. value .. after
	return M.replace_variable(variables, new_line)
end

local function input_to_lines(input)
	if type(input) == "table" then
		return input
	elseif type(input) == "string" then
		return vim.split(input, "\n")
	else
		error("only string or string array are supported as input. Got: " .. type(input))
	end
end

---Entry point, the parser
---@param input string | { }
---@param selected number
function M:parse(input, selected)
	local lines = input_to_lines(input)
	if selected > #lines then
		return self:add_error("the selected row: " .. selected .. " is greater then the given rows: " .. #lines)
	end

	self.selected = selected
	self.lines = lines
	self.readed_lines = 1
	self.end_line = #lines

	while true do
		local line = lines[self.readed_lines]
		line = M.cut_comment(line)

		if self.current_state ~= M.STATE_GLOBAL_VARIABLE or self.current_state ~= M.STATE_LOCAL_VARIABLE then
			local l, err = M.replace_variable(self.variables, line)

			if l then
				line = l
			else
				self:add_error(err)
			end
		end

		if not M.ignore_line(line) then
			self.current_state = self:do_transition(line)
		end

		if self.readed_lines == self.end_line then
			break
		end

		self.readed_lines = self.readed_lines + 1
	end

	if not self.request.method or not self.request.url then
		self:add_error("a valid request expect at least a url")
	end

	return self
end

return M
