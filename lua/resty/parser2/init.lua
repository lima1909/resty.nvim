local d = require("resty.parser2.delimiter")
local kv = require("resty.parser2.key_value")
local mu = require("resty.parser2.method_url")
local by = require("resty.parser2.body")

local M = {}
M.__index = M

M.STATE_START = 1
M.STATE_GLOBAL_VARIABLE = kv.STATE_GLOBAL_VARIABLE -- 2
M.STATE_LOCAL_VARIABLE = kv.STATE_LOCAL_VARIABLE -- 3
M.STATE_DELIMITER = d.STATE_DELIMITER -- 4
M.STATE_METHOD_URL = mu.STATE_METHOD_URL -- 5
M.STATE_HEADERS_QUERY = kv.STATE_HEADERS_QUERY -- 6
M.STATE_BODY = by.STATE_BODY -- 7

---token_end is optional, is it necessary if the buffer contains more rows
---otherwise is the end of the buffer the end of parsing
-- local token_END = "---"

local function ignore_line(line)
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

local state_machine = {
	[M.STATE_START] = {
		to = function(p, line)
			if kv.parse_global_variable(p, line) or d.parse_delimiter(p, line) or mu.parse_method_url(p, line) then
				return true
			end
		end,
	},
	[M.STATE_GLOBAL_VARIABLE] = {
		to = function(p, line)
			if kv.parse_global_variable(p, line) or d.parse_delimiter(p, line) then
				return true
			end
		end,
	},
	[M.STATE_DELIMITER] = {
		to = function(p, line)
			if kv.parse_local_variable(p, line) or mu.parse_method_url(p, line) then
				return true
			end
		end,
	},
	[M.STATE_LOCAL_VARIABLE] = {
		to = function(p, line)
			if kv.parse_local_variable(p, line) or mu.parse_method_url(p, line) then
				return true
			end
		end,
	},
	[M.STATE_METHOD_URL] = {
		to = function(p, line)
			if kv.parse_headers_query(p, line) or by.parse_body(p, line) then
				return true
			end
		end,
	},
	[M.STATE_HEADERS_QUERY] = {
		to = function(p, line)
			if kv.parse_headers_query(p, line) or by.parse_body(p, line) then
				return true
			end
		end,
	},
	[M.STATE_BODY] = {
		to = function(p, line)
			if by.parse_body(p, line) then
				return true
			end
		end,
	},
}

local function input_to_lines(input)
	if type(input) == "table" then
		return input
	elseif type(input) == "string" then
		return vim.split(input, "\n")
	else
		error("only string or string array are supported as input. Got: " .. type(input))
	end
end

M.new = function()
	local p = {
		current_state = M.STATE_START,
		readed_lines = 0,
		duration = 0,
		body_is_ready = false,
		global_variables = {},
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

		local current_state_before = self.current_state
		if not ignore_line(line) and not state_machine[self.current_state].to(self, line) then
			error(
				"unspupported transition from state: "
					.. current_state_before
					.. " -> "
					.. self.current_state
					.. " in line: "
					.. line
					.. " (row: "
					.. self.readed_lines
					.. ")"
			)
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
