local d = require("resty.parser2.delimiter")
local kv = require("resty.parser2.key_value")
local mu = require("resty.parser2.method_url")
local by = require("resty.parser2.body")

local M = {}
M.__index = M

M.new = function()
	local p = {
		current_state = M.STATE_START,
		readed_lines = 1,
		duration = 0,
		body_is_ready = false,
		variables = {},
		request = {},
		errors = {},
	}
	return setmetatable(p, M)
end

function M:parse_variable(line)
	local ok, result = pcall(kv.parse_variable, line)

	if not ok then
		self:add_error(result)
		return true
	elseif result then
		self.variables[result.k] = result.v
		return true
	end
end

function M:parse_headers_query(line)
	local ok, result = pcall(kv.parse_headers_query, line)

	if not ok then
		self:add_error(result)
		return true
	elseif result then
		self.request.headers = self.request.headers or {}
		self.request.query = self.request.query or {}

		if result.delimiter == "=" then
			self.request.query[result.k] = result.v
		else
			self.request.headers[result.k] = result.v
		end

		return true
	end
end

function M:parse_method_url(line)
	local ok, result = pcall(mu.parse_method_url, line)

	if not ok then
		self:add_error(result)
		return true
	elseif result then
		self.request = result
		return true
	end
end

--[[ 

* comment and empty line: ignore
* states: start, method_url, local_variable, headers_query, body, end_req_def
* grammar:

start -> local_variable			*
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

M.STATE_START = 0
M.STATE_LOCAL_VARIABLE = 1
M.STATE_METHOD_URL = 2
M.STATE_HEADERS_QUERY = 3
M.STATE_BODY = 4

local states = {
	{
		id = M.STATE_LOCAL_VARIABLE,
		name = "local variables",
		parse = M.parse_variable,
	},
	{
		id = M.STATE_METHOD_URL,
		name = "method and url",
		parse = M.parse_method_url,
	},
	{
		id = M.STATE_HEADERS_QUERY,
		name = "header or query",
		parse = M.parse_headers_query,
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
	[M.STATE_START] = { M.STATE_LOCAL_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_LOCAL_VARIABLE] = { M.STATE_LOCAL_VARIABLE, M.STATE_METHOD_URL },
	[M.STATE_METHOD_URL] = { M.STATE_HEADERS_QUERY, M.STATE_BODY },
	[M.STATE_HEADERS_QUERY] = { M.STATE_HEADERS_QUERY, M.STATE_BODY },
	[M.STATE_BODY] = { M.STATE_BODY },
}

function M:do_transition(line)
	local ts = transitions[self.current_state]
	for _, t in ipairs(ts) do
		local s = states[t]
		if s.parse(self, line) then
			self.current_state = s.id
			return
		end
	end
	--
	-- no valid transition found
	local err = "from current state: '" .. states[self.current_state].name .. "' are only possible: "
	for _, t in ipairs(ts) do
		err = err .. states[t].name .. ", "
	end
	self:add_error(err:sub(1, #err - 2))
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

function M:read_line(line, parse)
	if not line then
		return true
	end

	if M.ignore_line(line) == true then
		return false
	end

	line = M.cut_comment(line)
	return not parse(self, line)
end

---Entry point, the parser
---@param input string | { }
---@param selected number
function M:parse(input, selected)
	local lines = input_to_lines(input)

	local ok, req_start, req_end = pcall(d.find_request, lines, selected)
	if not ok then
		return self:add_error(req_start)
	end

	-- start == 1, no global variables exist
	if req_start > 1 then
		-- read global variables
		while not self:read_line(lines[self.readed_lines], M.parse_variable) do
			self.readed_lines = self.readed_lines + 1
		end
	end

	self.readed_lines = req_start
	while true do
		local line = lines[self.readed_lines]

		local l, err = M.replace_variable(self.variables, line)
		if l then
			line = l
		else
			self:add_error(err)
		end

		-- read the line and execute the state machine
		self:read_line(line, M.do_transition)

		if self.readed_lines == req_end then
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
