local kv = require("resty.parser.key_value")
local mu = require("resty.parser.method_url")
local b = require("resty.parser.body")
local d = require("resty.parser.delimiter")

local M = {}
M.__index = M

M.STATE_START = {
	id = 1,
	name = "start",
}

M.STATE_VARIABLE = {
	id = 2,
	name = "variables",
	parser = kv.parse_variable,
	set_result = function(slf, r)
		slf.variables[r.k] = r.v
	end,
}

M.STATE_METHOD_URL = {
	id = 3,
	name = "method and url",
	parser = mu.parse_method_url,
	set_result = function(slf, r)
		slf.request.method = r.method
		slf.request.url = r.url
	end,
}

M.STATE_HEADERS_QUERY = {
	id = 4,
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
	id = 5,
	name = "body",
	parser = b.parse_body,
	set_result = function() end,
}

local transitions = {
	-- [M.STATE_START.id] =
	{ M.STATE_VARIABLE, M.STATE_METHOD_URL },
	-- [M.STATE_VARIABLE.id] =
	{ M.STATE_VARIABLE, M.STATE_METHOD_URL },
	-- [M.STATE_METHOD_URL.id] =
	{ M.STATE_HEADERS_QUERY, M.STATE_BODY },
	-- [M.STATE_HEADERS_QUERY.id] =
	{ M.STATE_HEADERS_QUERY, M.STATE_BODY },
	-- [M.STATE_BODY.id] =
	{ M.STATE_BODY },
}

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

function M:do_transition(line)
	local ts = transitions[self.current_state.id]
	for _, s in ipairs(ts) do
		if self:parse_line(s.parser, line, s.set_result) then
			self.current_state = s
			return
		end
	end
	--
	-- no valid transition found
	local err = "from current state: '" .. self.current_state.name .. "' are only possible: "
	for _, s in ipairs(ts) do
		err = err .. s.name .. ", "
	end
	self:add_error(err:sub(1, #err - 2))
end

function M:has_errors()
	return self.errors ~= nil and #self.errors > 0
end

function M:add_error(message)
	table.insert(self.errors, {
		col = 0,
		lnum = self.readed_lines - 1, -- NOTE: lnum is 0 indexed, end readed_lines starts by 1
		severity = vim.diagnostic.severity.ERROR,
		message = message,
	})
	return self
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

function M:read_line(line, parse)
	if not line or line:sub(1, 3) == "###" then
		return false
	end

	-- ignore comment or empty line
	if vim.startswith(line, "#") or line == "" or vim.trim(line) == "" then
		return true
	end

	-- cut comment
	local pos = string.find(line, "#")
	if pos then
		line = line:sub(1, pos - 1)
	end

	return parse(self, line)
end

function M.new()
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

---Entry point, the parser
---@param input string | { }
---@param selected number
function M.parse(input, selected)
	local start_time = os.clock()

	local lines
	if type(input) == "table" then
		lines = input
	elseif type(input) == "string" then
		lines = vim.split(input, "\n")
	else
		error("only string or string array are supported as input. Got: " .. type(input), 0)
	end

	local p = M.new()
	--
	-- find request
	local ok, req_start, req_end = pcall(d.find_request, lines, selected)
	if not ok then
		return p:add_error(req_start)
	end

	-- start == 1, no global variables exist
	if req_start > 1 then
		-- read global variables
		while
			p:read_line(lines[p.readed_lines], function(_, line)
				local no_error, result = pcall(kv.parse_variable, line)
				if not no_error then
					p:add_error(result)
					return true
				elseif result then
					p.variables[result.k] = result.v
					return true
				end
			end)
		do
			p.readed_lines = p.readed_lines + 1
		end
	end

	-- read request
	p.readed_lines = req_start
	while true do
		local line = p:replace_variable(p.variables, lines[p.readed_lines])
		-- read the line and execute the state machine
		p:read_line(line, M.do_transition)

		if p.readed_lines == req_end then
			break
		end
		p.readed_lines = p.readed_lines + 1
	end

	if not p.request.method or not p.request.url then
		p:add_error("a valid request expect at least a url")
	end

	p.duration = os.clock() - start_time
	return p
end

return M
