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
		request = {
			headers = {},
			query = {},
		},
		errors = {},
	}

	return setmetatable(p, M)
end

function M:parse_line(parser, line, set_result)
	local no_error, result = pcall(parser, line, self)

	if not no_error then
		self:add_error(result)
		return true
	elseif result then
		set_result(self, result)
		return true
	end
end

M.STATE_START = 0

M.STATE_VARIABLE = {
	id = 1,
	name = "variables",
	parser = kv.parse_variable,
	set_result = function(slf, r)
		slf.variables[r.k] = r.v
	end,
}

M.STATE_METHOD_URL = {
	id = 2,
	name = "method and url",
	parser = mu.parse_method_url,
	set_result = function(slf, r)
		slf.request.method = r.method
		slf.request.url = r.url
	end,
}

M.STATE_HEADERS_QUERY = {
	id = 3,
	name = "header or query",
	parser = kv.parse_headers_query,
	set_result = function(slf, r)
		if r.delimiter == "=" then
			slf.request.query[r.k] = r.v
		else
			slf.request.headers[r.k] = r.v
		end
	end,
}

M.STATE_BODY = {
	id = 4,
	name = "body",
	parser = by.parse_body,
	set_result = function() end,
}

local states = {
	M.STATE_VARIABLE,
	M.STATE_METHOD_URL,
	M.STATE_HEADERS_QUERY,
	M.STATE_BODY,
}

local transitions = {
	[M.STATE_START] = { M.STATE_VARIABLE.id, M.STATE_METHOD_URL.id },
	[M.STATE_VARIABLE.id] = { M.STATE_VARIABLE.id, M.STATE_METHOD_URL.id },
	[M.STATE_METHOD_URL.id] = { M.STATE_HEADERS_QUERY.id, M.STATE_BODY.id },
	[M.STATE_HEADERS_QUERY.id] = { M.STATE_HEADERS_QUERY.id, M.STATE_BODY.id },
	[M.STATE_BODY.id] = { M.STATE_BODY.id },
}

function M:do_transition(line)
	local ts = transitions[self.current_state]
	for _, t in ipairs(ts) do
		local s = states[t]
		if self:parse_line(s.parser, line, s.set_result) then
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
	if vim.startswith(line, "#") then
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
---@return string
function M:replace_variable(variables, line)
	if not variables then
		return line
	end

	local _, start_pos = string.find(line, "{{")
	local end_pos, _ = string.find(line, "}}")

	if not start_pos and not end_pos then
		-- no variable found
		return line
	elseif start_pos and not end_pos then
		-- error
		self:add_error("missing closing brackets: '}}'")
		return line
	elseif not start_pos and end_pos then
		-- error
		self:add_error("missing open brackets: '{{'")
		return line
	end

	local before = string.sub(line, 1, start_pos - 2)
	local name = string.sub(line, start_pos + 1, end_pos - 1)
	local after = string.sub(line, end_pos + 2)

	local value = variables[name]
	if not value then
		self:add_error("no variable found with name: '" .. name .. "'")
		return line
	end

	local new_line = before .. value .. after
	return self:replace_variable(variables, new_line)
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
		return false
	end

	if M.ignore_line(line) == true then
		return true
	end

	line = M.cut_comment(line)
	return parse(self, line)
end

---Entry point, the parser
---@param input string | { }
---@param selected number
function M:parse(input, selected)
	local lines = input_to_lines(input)

	-- find request
	local ok, req_start, req_end = pcall(d.find_request, lines, selected)
	if not ok then
		return self:add_error(req_start)
	end

	-- start == 1, no global variables exist
	if req_start > 1 then
		-- read global variables
		while
			self:read_line(lines[self.readed_lines], function(_, line)
				return self:parse_line(kv.parse_variable, line, M.STATE_VARIABLE.set_result)
			end)
		do
			self.readed_lines = self.readed_lines + 1
		end
	end

	-- read request
	self.readed_lines = req_start
	while true do
		local line = lines[self.readed_lines]
		line = self:replace_variable(self.variables, line)

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
